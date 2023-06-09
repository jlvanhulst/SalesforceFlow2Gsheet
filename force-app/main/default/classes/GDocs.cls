public with sharing class GDocs {
    private static string gDocs;          // google Docs id
    private static string docTitle;               // Title of the doc
    private static string callOut;                // named credential to use
    private static String[] fieldList;            // list of display names of fields (columns)
    private static string fileName;               // the full url of the google spreadsheet
    private static string lastError;              // the last API call error description
    private static JSONParse parserBody;           // the json version of the full doc as retrieved from Get or Create
    private static List<String> columnTypes;      // Keep track of the object type per column
    private static boolean removeBorder = false;  // remove the border of the table
    private static string requests = '';          // the list of requests to be sent to the batchUpdate callout
    private static list<integer> columnWidths = new List<integer>();           // list of column widths
    private static integer indexPointer = 1;       // 0 start at the beginning of the document

    @invocableMethod(label='Add a paragraph of text to a Google Doc ' description='Update a Google Doc')
    public static List<Response> paragraph(List<Request> request) {
        HttpResponse responseHttp;
        lastError =''; 
        List<Response> responseList = new List<Response>();
        Response response = new Response();    
        columnTypes = new List<String>();

        callOut       = Request[0].callout;
  
        if (request[0].createNew==null) {
            request[0].createNew =False;
        }

        /* The google doc ID can be provided directly as a parameter or through the full doc url. 
         If both are provided, the ID in the request will be used.
        
         If none is provided, a new spreadsheet will be created if the createNew parameter is set to true.
        */
        if (request[0].googleFileUrl==null||request[0].googleFileUrl=='') {
            gDocs = request[0].googleDocId;
        } else {
            fileName = request[0].googleFileUrl;
            Pattern p = Pattern.compile('/document/d/([a-zA-Z0-9-_]+)' );
            Matcher pm = p.matcher( fileName );
            pm.find();
            gDocs = pm.group(1);
          
        }
        // We should have a spreadsheetId by now. If not, we need to create a new one.
        if (gDocs==null||gDocs=='') {
            
            if (!(request[0].createNew)) {
                // No doc ID provided and createNew = false
                response.errorMessage = 'No google Docs ID provided and createNew = false';
                responseList.add(response);
                return responseList;      
            } else {
                // No Doc ID provided and createNew = true, let's create a new spreadsheet
                response.newDoc = createNew(request[0].newDocTitle);
                if ( !response.newDoc ) {
                    // something went wrong creating a new document
                    responseList.add(response);
                    return responseList;
                } else {
                    // set the URL of the new Document in the response
                    response.url = fileName;
                }
            }    
        }
  
            
        if (checkDoc()) {
            if (request[0].paragraphText!=null) {
                addText(request[0].paragraphText, request[0].paragraphStyle);
            }
            if (request[0].soqlQuery!=null) {
                try {
                    request[0].inputObjects = Database.query(request[0].soqlQuery);
                } catch (Exception e) {
                    response.errorMessage = 'Error in SOQL query: '+e.getMessage();
                    responseList.add(response);
                    return responseList;      
                }
            } 
            if (request[0].inputObjects!=null) {
                if (request[0].removeBorder!=null) {
                    removeBorder = request[0].removeBorder;
                }
                String commaFields = request[0].fieldList;
                if (commaFields == null||commaFields=='') {
                    fieldList = fields(request[0].inputObjects[0]);
                } else {
                    // if a field list is provided, we will use those
                    fieldList =  request[0].fieldList.split('[,; ]{1}[\\s]?');
                }
                getColumTypes(request[0].inputObjects[0]);
                if (request[0].columnWidths!=null) {
                    for ( String num : request[0].columnWidths.split( ',' ) ) {
                        columnWidths.add( Integer.valueOf( num ) );
                    }
                }
                addTable(request[0].inputObjects);    
            }
            if (requests.length()>0) {
                // we have some requests to send to the batchUpdate callout
                system.debug('##requests: '+requests);
                responseHttp = executeCallout('POST','callout:'+callOut+'/v1/documents/'+gDocs+':batchUpdate','{"requests":['+requests+']}');
                boolean ret = (responseHttp.getStatusCode()==200);
                system.debug('##ret: '+responseHttp.getStatusCode());
                if (!ret) {
                    response.errorMessage = responseHttp.getStatus();
                    response.responseCode = responseHttp.getStatusCode();
                }
            }
        } else {
            // could not open the document
            response.errorMessage ='Document not found or accesible. - '+lastError;
        }
        responseList.add(response);
        return responseList;     
    } 
    
    public static void styleRequest(string style, integer startPos, integer endPos) {
        style = style.toLowercase();
        List<string> styles = style.split(',');
        string textStyles ='';
        string fields ='';
        if (style!=null) {
            for (string s : styles) {
                if (s=='bold'||s=='italic'||s=='underline'||s=='smallcaps') {
                    textStyles += '"'+s+'": true,';
                    if (fields.length()>0) {
                        fields += ',';
                    }
                    fields += s;
                }
            }
            requests += '{"updateTextStyle": { "range": {"segmentId": "", "startIndex": '+String.valueOf(startPos)+', "endIndex": '+String.valueOf(endPos)+'}, "fields": "'+fields+'", "textStyle": { '+textStyles+' } }},';
        }
    }
    public static Boolean addText(String text) {
        return addText( text, null,  1); 
    }

    public static Boolean addText(String text, String style) {
        return addText( text, style, 1); 
    }

    public static Boolean addText(String text, String style, Integer location) {
        // Add a paragraph of text to the document - automatically adds a new line (paragraph end)
        requests += '{"insertText": {"text":"'+text+'\n", "location": {"index": '+String.valueOf(location)+'}}},';
        if (style!=null) {
            styleRequest(style, 1, text.length()-1);
        }
        return true;
    }

    public static Boolean addTable(List<SObject> allObjects) {
        // Add a table to the document
        SObject firstObject = allObjects[0];        // first object of the collection 
        Integer rows = allObjects.size();
        Integer cols = fieldList.size();
        Integer row = 0;
        SObject obj;
        string json = '';
        // first we create the table, then we need to remove formatting if need and then we add the data, in that particular order!!!
        requests +='{"insertTable": { "rows": '+String.valueOf(rows)+', "columns": '+String.valueOf(cols)+', "location": {"index":1} }},';
        if (removeBorder) {
            // we need to make sure to update the style of the table FIRST before adding the data rows!
            requests +='{"updateTableCellStyle":{"tableCellStyle":{"borderTop":{"dashStyle":"SOLID","width":{"unit":"PT","magnitude":0},"color":{"color":{"rgbColor":{"blue":0}}}},"borderBottom":{"dashStyle":"SOLID","width":{"magnitude":0,"unit":"PT"},"color":{"color":{"rgbColor":{"blue":0}}}},"borderLeft":{"dashStyle":"SOLID","width":{"unit":"PT","magnitude":0},"color":{"color":{"rgbColor":{"blue":0}}}},"borderRight":{"dashStyle":"SOLID","width":{"unit":"PT","magnitude":0},"color":{"color":{"rgbColor":{"blue":0}}}}},"fields":"borderTop, borderBottom, borderLeft, borderRight","tableStartLocation":{"index":2}}},';
        }
        if (columnWidths.size()>0) {
            for (Integer i = 0; i < columnWidths.size(); i++ ) {
                requests += '{"updateTableColumnProperties":{"tableColumnProperties":{"width":{"unit":"PT","magnitude":'+String.valueOf(columnWidths[i])+'},"widthType": "FIXED_WIDTH"},"columnIndices":['+String.valueOf(i)+'],"fields": "width, widthType","tableStartLocation":{"index":2}}},';
            }
        }
   
        for (row=rows-1; row > -1; row-- ) {
            obj =allObjects[row];
            // for each record in the input list, add a row in the table
            String field;
            Map<String, Object> fieldsAndValues = obj.getPopulatedFieldsAsMap();            
            sObject child;
            Object value ;
            String stringValue;
            For (Integer i = cols-1; i > -1; i-- ){
                field =fieldList[i];   
                try {    
                    if (field.contains('__r')){
                        child = (sobject) fieldsAndValues.get(field.substringBefore('.'));
                        value = child.get(field.substringAfter('.'));
                    } else {
                        value = fieldsAndValues.get(field);
                    }
                    stringValue = stringify(value,columnTypes[i],field);  
                } catch (Exception e) {
                    stringValue = field+'- not found!';      
                }          
                json += '{ "insertText": { "text": "'+stringValue+'", "location": { "index": '+String.valueOf( row*((2*cols)+1)+5+2*i   )+' }}},';    
            }          
        }
        // adding the data rows need to be last in the table request sequence
        requests += json;
        return true;

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

    public static void getColumTypes(SObject firstObject) {
        Schema.SObjectType leadSchema =  firstObject.getSObjectType();
        Map<String, Schema.SObjectField> fieldMap = leadSchema.getDescribe().fields.getMap();
        String fieldName;
        Integer i = 0;
        sobject child;
        Map<String, Schema.SObjectField> childFields;
        Object childField;
        For (String field : fieldList ){
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
            i++;
        }
    } 


    public static boolean checkDoc() {
        // Verify the document exist and is accesible -
        HttpResponse responseHttp = executeCallout('GET','callout:'+callOut+'/v1/documents/'+gDocs);
        boolean ret = (responseHttp.getStatusCode()==200);

        if (ret) {
            parserBody = new JSONParse(responseHttp.getBody());
            docTitle = parserBody.get('title').getStringValue() ;
        } else {
            lastError = responseHttp.getStatus();
        }
        return ret;
    }

    public static boolean createNew(String title) {
        //  create a new spreadsheet and set the spreadsheet id and gid
        HttpResponse responseHttp = executeCallout('POST','callout:'+callOut+'/v1/documents','{"title": "'+title+'"}');
        boolean ret = (responseHttp.getStatusCode()==200);
        if (ret) {
            parserBody = new JSONParse(responseHttp.getBody());      
            gDocs = parserBody.get('documentId').getStringValue();
            docTitle = parserBody.get('title').getStringValue();
            fileName = 'https://docs.google.com/document/d/'+gDocs;
        } else {
            lastError = responseHttp.getStatus();
        }
        return ret;
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
            system.debug('##H '+requestBody);
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
        public Integer columns;
        
        @invocableVariable
        public string errorMessage;
        
        @invocableVariable
        public Integer responseCode;

        @invocableVariable(label ='URL of the spreadsheet')
        public string url;

        @invocableVariable(label ='Boolean TRUE = new doc created')
        public boolean newDoc;
    }
    
    public class Request {
        
        @invocableVariable(label ='Callout - needs to connect to an openid connection to https://sheets.googleapis.com' required=true)
        public String callout ;
        
        @invocableVariable(label ='Spreadsheet full url - will use id and tab(gid)')
        public String googleFileUrl ;   
        
        @invocableVariable(label ='Spreadsheet ID - alternative if no URL provided' )
        public String googleDocId ;
        
        @invocableVariable(label ='Collection of Sobjects each record will become one row in table. If not supplied an SOQL expression needs to be provided.' )
        public List<Sobject> inputObjects;
        
        @invocableVariable(label ='SOQL query to use')
        public String soqlQuery;

        @invocableVariable(label ='Fieldnames comma separated, if empty/not provided all fields from the sObject will be exported, without the ID fields')
        public String fieldList;

        @invocableVariable(label ='Column widths, comma separated')
        public String columnWidths;

        @invocableVariable(label ='Remove table border')
        public Boolean removeBorder;

        @invocableVariable(label ='Create new document if no URL or ID specified')
        public Boolean createNew;

        @invocableVariable(label ='Title to use for new document')
        public String newDocTitle;

        @invocableVariable(label ='Text to add to the end of the document.')
        public String paragraphText;

        @invocableVariable(label ='Text formatting, comma separated list of values: BOLD,ITALIC,UNDERLINE,STRIKETHROUGH,SUPERSCRIPT,SUBSCRIPT,SMALLCAPS')
        public String paragraphStyle;
            
 
    }
}