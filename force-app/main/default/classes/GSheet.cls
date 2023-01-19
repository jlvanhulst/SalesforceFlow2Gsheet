public with sharing class GSheet {
    public static string spreadsheetId;          // google spreadsheet id
    public static integer gid;                   // tab id within the spreadsheet (gid=0 is default)
    public static string tabTitle;               // Title of the sheets, used for updating values. Retrieved from the spreadsheet properties based on gid
    public static string callOut;                // named credential to use
    public static boolean includeHeader;         // add a header row - default true
    public static integer colOffset;             // column offset - default is 0
    public static integer rowOffset;             // row offset - default is 0
    public static SObject firstObject;           // first object of the collection 
    public static List<Sobject> allObjects;      // collection of records to be exported
    public static String[] fieldList;            // list of display names of fields (columns)
    public static string fileName;               // the full url of the google spreadsheet
    public static string lastError;              // the last API call error description
    public static List<String> columnTypes;      // Keep track of the object type per column
    
    @invocableMethod(label='Export any collection of sOjects to a Google Spreadsheet' description='Provide a collection of records or an SOQL query and export them to a Google Spreadsheet')
    public static List<Response> row(List<Request> request) {
        HttpResponse responseHttp;
        lastError ='';
        
        List<Response> responseList = new List<Response>();
        Response response = new Response();   
        columnTypes = new List<String>();
 
        // Let's check if we have any records to export. Should we allow this now that we have the createNew option? The only allow 
        // creating a new empty spreadsheet, but not adding records to it?
        if (request[0].soqlQuery!=null) {
            try {
                request[0].inputObjects = Database.query(request[0].soqlQuery);
            } catch (Exception e) {
                response.ErrorMessage = 'Error in SOQL query: '+e.getMessage();
                responseList.add(response);
                return responseList;      
            }
        } 
        if (request[0].inputObjects==null) {
            response.ErrorMessage = 'No records provided!';
            responseList.add(response);
            return responseList;      
        }
        allObjects    = request[0].inputObjects;
        firstObject   = request[0].inputObjects[0];
        fieldList     = new List<String>();
        callOut       = Request[0].callout;

        // Set default values for optional parameters
        if (request[0].offset==null) {
            request[0].offset = 0;
        }   
        if (request[0].colOffset==null) {
            request[0].colOffset = 0;
        } 
        if (request[0].includeHeader==null) {
            request[0].includeHeader = true;
        }
        if (request[0].createNew==null) {
            request[0].createNew =False;
        }

        includeHeader = request[0].includeHeader;
        rowOffset     = request[0].offset;
        colOffset     = request[0].colOffset;
 
        /* The google spreadsheet ID can be provided directly as a parameter or through the full spreadsheet url. 
         If both are provided, the ID in the request will be used.
        
         If none is provided, a new spreadsheet will be created if the createNew parameter is set to true.
        */
        if (request[0].googleFileUrl==null||request[0].googleFileUrl=='') {
            spreadsheetId = request[0].googleSheetId;
        } else {
            fileName = request[0].googleFileUrl;
            Pattern p = Pattern.compile('/spreadsheets/d/([a-zA-Z0-9-_]+)' );
            Matcher pm = p.matcher( fileName );
            pm.find();
            spreadsheetId = pm.group(1);
            
            p = Pattern.compile('[#&]gid=([0-9]+)');
            pm = p.matcher( fileName );
            pm.find();
            gid = Integer.valueOf( pm.group(1) );

        }
        // We should have a spreadsheetId by now. If not, we need to create a new one.
        if (spreadsheetId==null||spreadsheetId=='') {
            
            if (!(request[0].createNew)) {
                // No spreadsheet ID provided and createNew = false
                response.ErrorMessage = 'No google spreadsheet ID provided and createNew = false';
                responseList.add(response);
                return responseList;      
            } else {
                // No spreadsheet ID provided and createNew = true, let's create a new spreadsheet
                response.newSpreadsheet = createNew(request[0].newSpreadsheetTitle);
                if ( !response.newSpreadsheet ) {
                    // something went wrong creating a new spreadsheet
                    responseList.add(response);
                    return responseList;
                } else {
                    // set the URL of the new spreadsheet in the response
                    response.url = fileName;
                }
            }    
        }
        if (request[0].tabId!=null) { // specifying a tab will overwrite a possible tab from the url 
            // this will make the target tab the specific tab, no matter if there was a gid=xxx in the URL provided!
            gid = request[0].tabId;
        }
            
        if (parsesheets()) {
            // We have a valid spreadsheet ID and a valid tab ID. 
            String commaFields = request[0].fieldList;
            // if no field list is provided, we will use all fields from the first record
            if (commaFields == null||commaFields=='') {
                fieldList = fields(firstObject);
            } else {
                // if a field list is provided, we will use those
                fieldList =  request[0].fieldList.split('[,; ]{1}[\\s]?');
            }
            
            string json = '[';  
            integer row = 0;
            
            response.header =  header(); // run allways to set column types
            if (includeHeader) {
                // create a nice header row in the spreadsheet with the field names
                json +=  response.header;
                row++;
            }
            // Loop all fields inside all records, for each add an entry in the Json String
            for (Sobject obj : allObjects ) {
                // for each record in the input list, add a row in the spreadsheet
                if (row>0) {
                    json+= ','; // json 'newline' for each record
                }
                json += ' [';
                Map<String, Object> fieldsAndValues = obj.getPopulatedFieldsAsMap();            
                Integer i = 0;
                sObject child;
                Object value ;
                For (String field : fieldList ){
                    if (i>0) {
                        json+=',';
                    }    
                    try {    
                        if (field.contains('__r')){
                            system.debug('### '+field);
                            child = (sobject) fieldsAndValues.get(field.substringBefore('.'));
                            value = child.get(field.substringAfter('.'));
                        } else {
                            value = fieldsAndValues.get(field);
                        }
                        json += '"'+stringify(value,columnTypes[i],field)+'"';  
                    } catch (Exception e) {
                        json += '"-'+field+'- not found!"';      
                    }          
                    i++;
                }          
                json += ' ]';
                row ++;          
            }
            json += ']';
            
            response.jsonstring = '{ "values": '+json+' }'; // this is the body request for the API call
            response.rows = row; // report back the number of rows 
            response.columns = fieldList.size(); // and columns
            
            // calculate the range of the spreadsheet to update and call the API 'Values:Update' method to transfer the unformatted data. 
            // We'll do an update for the formatting per column afterwards.
            response.range = range(response.rows, response.columns); //'A'+ String.valueOf(request[0].offset+1)+':'+onchar+String.valueOf(response.rows+request[0].offset);            
            responseHttp = executeCallout('PUT','callout:'+callOut+'/v4/spreadsheets/'+spreadsheetId+'/values/'+response.range+'?&valueInputOption=USER_ENTERED',response.jsonstring);
            response.ResponseCode = responseHttp.getStatusCode(); // should be 200
            if (responseHttp.getStatusCode()!=200) {
                // share the error back to the flow response
                response.ErrorMessage = responseHttp.getStatus()+' - '+response.jsonstring;
            } else {
                // now let's call the API to format the rows
                String formatRequest = format() ;
                if (formatRequest.length()>0){
                    responseHttp = executeCallout('POST','callout:'+callOut+'/v4/spreadsheets/'+spreadsheetId+':batchUpdate',formatRequest);
                    response.ResponseCode = responseHttp.getStatusCode();
                    if (responseHttp.getStatusCode()!=200) {
                        // something went wrong with the API call to format the rows. Let's make sure to share back the why
                        response.ErrorMessage = responseHttp.getStatus()+' - '+formatRequest;
                    } else {
                        response.ErrorMessage = responseHttp.getStatus();
                    }
                }
            }
        } else {
            // could not find a valid tab (sheet)
            response.ErrorMessage ='Spreadsheet or tab(gid) not found/accesible. - '+lastError;
        }
        responseList.add(response);
        return responseList;     
    } 

    public static list <string> fields(sObject obj) {
        // This method creates a list of all fields in the object, including nested fields
        // It will suppress ID fields by default
        list <string> fields = new list <string>();
        list <string> nested;
        Object fieldValue;
        Map<String, Object> fs = obj.getPopulatedFieldsAsMap();            
        for (String fieldName : fs.keySet() ){
            if (fieldName.contains('__r')) {
                nested = fields( (sobject) fs.get(fieldName) );
                for (String f : nested){
                    fields.add(fieldName+'.'+f);
                   // system.debug('##F'+fieldname+'.'+f);
                }
            } else  {
                fieldValue = fs.get(fieldName);
                if ( !(fieldValue instanceof Id)) {
                   fields.add(fieldName);
                }
            }
        }
        return fields;
    }

    public static boolean parsesheets() {
        // Verify the spreadsheet exist and is accesible - then verify the tab id (gid) and retrieve the title for the target GID
        HttpResponse responseHttp = executeCallout('GET','callout:'+callOut+'/v4/spreadsheets/'+spreadsheetId);
        boolean ret = (responseHttp.getStatusCode()==200);
        system.debug('##gid='+String.valueOf(gid));

        if (ret) {
            ret = false ;// spreadsheet exists but we must also find the gid!
            JSONParse parser = new JSONParse(responseHttp.getBody()).get('sheets');
            for(JSONParse sheet : parser.asList()) {
                if (sheet.get('properties.sheetId').getIntegerValue()==gid) {
                    tabTitle = sheet.get('properties.title').getStringValue() ;
                    return true;
                } 
            }
            if (!ret) {
                lastError = 'Tag/id '+String.valueOf(gid)+' not found in list of sheets for spreadsheet ';
            }
        } else {
            lastError = responseHttp.getStatus();
        }
        return ret;
    }

    public static boolean createNew(String title) {
        //  create a new spreadsheet and set the spreadsheet id and gid
        HttpResponse responseHttp = executeCallout('POST','callout:'+callOut+'/v4/spreadsheets','{ "properties": { "title": "'+title+'" } }');
        boolean ret = (responseHttp.getStatusCode()==200);
        if (ret) {
            JSONParse parser = new JSONParse(responseHttp.getBody());      
            spreadsheetId = parser.get('spreadsheetId').getStringValue();
            gid = parser.get('sheets.[0].properties.sheetId').getIntegerValue();
            tabTitle = parser.get('sheets.[0].properties.title').getStringValue();
            fileName =  parser.get('spreadsheetUrl').getStringValue();
        } else {
            lastError = responseHttp.getStatus();
        }
        return ret;
    }

    public static String range( Integer row, Integer col ) {
        // Calculate a string description of the range of cells. A 4 x 2 array becomes A1:D2
        // the optional row/col offsets change the starting row and/or column
        
        String range = String.fromCharArray( new List<integer> { 65+ colOffset } )+String.valueOf(rowOffset+1)+':'; 
        integer mod = Math.mod(col+colOffset, 26);
        if (mod==0) {
            mod=26;
        }
        integer fulltwentysix = ((col+colOffset-1)/26);
        if (fulltwentysix>0) {
            range+=String.fromCharArray( new List<integer> { 64+ fulltwentysix } );
        }
        range += String.fromCharArray( new List<integer> { 64+ mod } );
        range += String.valueOf(row+rowOffset);
        
        return '\''+tabTitle.replaceAll('[ ]','%20')+'\'!'+range ;
    }
    
    public static String header() {
        Schema.SObjectType leadSchema =  firstObject.getSObjectType();
        Map<String, Schema.SObjectField> fieldMap = leadSchema.getDescribe().fields.getMap();
        String header ='[';
        String fieldName;
        Integer i = 0;
        sobject child;
        Map<String, Schema.SObjectField> childFields;
        Object childField;
        For (String field : fieldList ){
            if (i>0) {
                header+=',';
            }
            if (field.contains('.')) {
                child = firstObject.getSObject(field.substringBefore('.'));
                childFields = child.getSObjectType().getDescribe().fields.getMap();
                try {
                    fieldName =  childFields.get(field.substringAfter('.')).getDescribe().getLabel();
                    columnTypes.add( childFields.get(field.substringAfter('.')).getDescribe().getType().name() );        
                } catch (Exception e) {
                    fieldName   = '\''+field+'\' not found!';   
                    columnTypes.add('STRING');     
                }
            } else {
                try {
                    fieldName = fieldMap.get(field).getDescribe().getLabel();
                    columnTypes.add( fieldMap.get(field).getDescribe().getType().name() );
                } catch (Exception e) {
                    fieldName   = '\''+field+'\' not found!';   
                    columnTypes.add('STRING');     
                }
            }
            header += '"'+fieldName+'"';
            i++;
        }
        header += ' ]';
        return header;
    }  
    
    public static String format(  ) {
        // Apply formatting to the header row and to the data rows.
        // For the header row we apply a bold font
        // For the data rows we apply a number format based on the type of the field - we use batch formatting to reduce the number of calls to the API
        // We batch per column.

        Schema.SObjectType leadSchema =  firstObject.getSObjectType();
        Map<String, Schema.SObjectField> fieldMap = leadSchema.getDescribe().fields.getMap();
        
        String requestStr ='[';
        Integer i = 0;
        Integer col = 0;
        String one;
        Integer headerCount = 0;
        Integer rows = allObjects.size();
        Integer digits;
        String formatPart;
        if (includeHeader) {
            headerCount ++;
            requestStr +=   '{"repeatCell": { "range":{"sheetId":'+String.valueOf(gid)+',"startColumnIndex":'+String.valueOf(colOffset)+',"startRowIndex": '+String.valueOf(rowOffset)+',"endColumnIndex": '+String.valueOf(colOffset+fieldList.size())+', "endRowIndex": '+String.valueOf(rowOffset+headerCount)+' },  "fields": "userEnteredFormat.textFormat.bold",  "cell": {"userEnteredFormat": { "textFormat": { "bold": true }}}}}';
            i++;
        }
        For (String field : fieldList ){
            try {
                field =  String.valueOf(fieldMap.get(field).getDescribe().getType());
            } catch (Exception e) {
                field   = 'UNKOWN FIELD';        
            }
            if (field=='CURRENCY'||field=='DOUBLE'||field=='PERCENT'||field=='INTEGER') {
                if (i>0) {
                    requestStr+=',';
                }
                switch on field {
                    when 'CURRENCY' {
                       formatPart = '{ "numberFormat": {"type": "CURRENCY" }}' ;
                    }
                    when 'INTEGER' {
                        formatPart = '{ "numberFormat": {"type": "NUMBER", "pattern": "#,##0" }}' ;
                    }
                    when 'DOUBLE' {
                        formatPart = '{ "numberFormat": {"type": "NUMBER", "pattern": "#,##0.00" }}' ;
                    }
                    when 'PERCENT' {
                        formatPart = '{ "numberFormat": {"type": "PERCENT" }}' ;
                    }
                }
                one =   '{"repeatCell": { "range":{"sheetId":'+String.valueOf(gid)+',"startColumnIndex":'+String.valueOf(col+colOffset)+',"startRowIndex": '+String.valueOf(rowOffset+headerCount)+',"endColumnIndex": '+String.valueOf(col+colOffset+1)+', "endRowIndex": '+String.valueOf(rows+rowOffset+headerCount)+' },  "fields": "userEnteredFormat.numberFormat",  "cell": {"userEnteredFormat": '+formatPart+'}}} ';
                requestStr += one;              
                i++;
            }
            col++;
        }
        if (i>0) {
            requestStr = '{ "requests":' +requestStr+ ' ] }';
        }
        else {
            requestStr = '';
        }
        return requestStr;
    }   
    
    public static String stringify( object o ,String fieldType,String field){ 
        if(o==null)                         return '';              // we can't say much about null
        String                              result  = 'Object';     // if we can't find out anything, we will return 'Object'
        if(o instanceof SObject)            {
             return ((SObject)o).getSObjectType().getDescribe().getName()+''; 
        }
        if(o instanceof Boolean)            return string.valueOf((Boolean)o);
        if(o instanceof Id)                 return (String)o;
        if(o instanceof String)             return (String)o;
        if(o instanceof Blob)               return 'Blob';
        if(o instanceof Date)               return ((DateTime)o).format('MM/dd/YYYY');
        if(o instanceof Datetime)           return ((DateTime)o).format('MM/dd/YYYY hh:mm:ss');
        if(o instanceof Time)               return 'Time';
        if(o instanceof Integer)            return String.valueOf((integer)o);
        if(o instanceof Long)               return String.valueOf((Long)o);
        if(o instanceof Decimal && fieldType=='PERCENT')     return String.valueOf(((Decimal)o)/100);
        if(o instanceof Decimal)            return String.valueOf((Decimal)o);
        if(o instanceof Double)             return String.valueOf((Double)o);
        if(o instanceof List<object>)       return 'List';
        try {                                                       // crazy but powerful workaround based on the answer of Arpi Jakab (20217-04-17) on SFSE ==> https://salesforce.stackexchange.com/questions/48019/how-to-get-the-runtime-type-of-an-object-dynamically-for-primitive-data-types-a 
            Name a = (Name) o;                                      // INTENTIONALLY force runtime exception like: "Invalid conversion from runtime type Map<Id,List<Account>> to Name"
        } catch (Exception e) {
            result                          = e.getMessage().substringAfter('from runtime type ').substringBefore(' ');        
        }
        return result;
    } 
    
    public static HttpResponse executeCallout (String method, String resourceName) {
        return executeCallout(method, resourceName, null, null);
    }
    
    public static HttpResponse executeCallout (String method, String resourceName, String requestBody) {
        return executeCallout(method, resourceName, requestBody, null);
    }
    
    public static HttpResponse executeCallout (String method, String resourceName, String requestBody, Map<String, String> headers) {
        
        resourceName = EncodingUtil.urlDecode(resourceName, 'UTF-8');
        // Instantiate a new request
        HttpRequest request = new HttpRequest();
        
        request.setMethod(method);
        request.setEndpoint(resourceName);
        
        // Accept a JSON response from the call
        request.setHeader('Accept', 'application/json');
        
        // Set max timeout
        request.setTimeout(120000);
        
        if (String.isNotBlank(requestBody)) {
            request.setBody(requestBody);
            request.setHeader('Content-Type', 'application/json');
        }
        
        if (headers != null && !headers.isEmpty()) {
            for (String headerKey :headers.keySet()) {
                request.setHeader(headerKey, headers.get(headerKey));
            }
        }
        HttpResponse response = new Http().send(request);
        return response;
    }  
    
    public class Response {
        @invocableVariable
        public String jsonstring;
        
        @invocableVariable
        public String header;
        
        @invocableVariable
        public Integer rows;
        
        @invocableVariable
        public Integer columns;
        
        @invocableVariable
        public string Range;   
        
        @invocableVariable
        public string ErrorMessage;
        
        @invocableVariable
        public Integer ResponseCode;

        @invocableVariable(label ='URL of the spreadsheet')
        public string url;

        @invocableVariable(label ='Boolean TRUE = new spreadsheet created')
        public boolean newSpreadsheet;
    }
    
    public class Request {
        
        @invocableVariable(label ='Callout - needs to connect to an openid connection to https://sheets.googleapis.com' required=true)
        public String callout ;
        
        @invocableVariable(label ='Spreadsheet full url - will use id and tab(gid)')
        public String googleFileUrl ;   
        
        @invocableVariable(label ='Spreadsheet ID - alternative if no URL provided' )
        public String googleSheetId ;
        
        @invocableVariable(label ='Tab ID (default is 0) - this will override url provided gid!')
        public integer tabId ;
        
        @invocableVariable(label ='Collection of Sobjects each record will become one row in the output. If not supplied an SOQL expression needs to be provided.' )
        public List<Sobject> inputObjects;
        
        @invocableVariable(label ='SOQL query to use')
        public String soqlQuery;

        @invocableVariable(label ='Fieldnames comma separated, if empty/not provided all fields from the sObject will be exported, without the ID fields')
        public String fieldList;

        @invocableVariable(label ='Create new spreadsheet if no URL or ID specified')
        public Boolean createNew;

        @invocableVariable(label ='Title to use for new spreadsheet')
        public String newSpreadsheetTitle;
        
        @invocableVariable(label ='Include a header row, default = TRUE')
        public Boolean includeHeader;
                
        @invocableVariable(label ='Row Offset (default=0, ie start writing row 1)')
        public integer offset;
        
        @invocableVariable(label ='Col Offset (default=0, ie start writing column A)')
        public integer colOffset;   
        

    }
}