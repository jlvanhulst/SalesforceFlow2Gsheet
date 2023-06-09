public with sharing class GDrive {
    private static string callOut;                // named credential to use
    private static string lastError;              // the last API call error description

    @invocableMethod(label='upload the latest version of specific salesforce ContentVersion ID file to Google Drive ' description='Upload to Google Drive')
    public static List<Response> paragraph(List<Request> request) {
        HttpResponse responseHttp;
        lastError =''; 
        List<Response> responseList = new List<Response>();
        Response response = new Response();    
        
        callOut       = Request[0].callout;
     
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
            for (SObject so : request[0].inputObjects) {
                if (so instanceof ContentVersion) {
                    createNew((ContentVersion)so);
                }
            }
        }
        response.errorMessage = lastError;
        responseList.add(response);
        return responseList;     
    } 

   
    public static boolean createNew(ContentVersion cv ) {
        //  create a new document
        string gDocs;
        JSONParse parserBody;
        string fileName;
        if (cv.VersionData!=null) {
            if (cv.IsLatest) {
                if (cv.PathOnClient!=null) {
                    fileName = cv.PathOnClient;
                } else {
                    fileName = cv.Title;
                }
                
            }
        }

        HttpResponse responseHttp = executeCallout('POST','callout:'+callOut+'/upload/drive/v3/files?uploadType=media&supportsAllDrives=true&addParents=0ADBpcWHI2CmlUk9PVA','{"name":"'+fileName+'"}',null,cv.VersionData );
        boolean ret = (responseHttp.getStatusCode()==200);
        system.debug('##RS responseHttp.getBody()'+responseHttp.getBody());

        if (ret) {
            parserBody = new JSONParse(responseHttp.getBody());      
            gDocs = parserBody.get('id').getStringValue();
            
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
        return executeCallout(method, resourceName, null, null,null);
    }
    
    public static HttpResponse executeCallout (String method, String resourceName, String requestBody) {
        return executeCallout(method, resourceName, requestBody, null,null);
    }
    
    public static HttpResponse executeCallout (String method, String resourceName, String requestBody, Map<String, String> headers, Blob blobBody) {
        
        resourceName = EncodingUtil.urlDecode(resourceName, 'UTF-8');
        // Instantiate a new request
        HttpRequest request = new HttpRequest();
        
        request.setMethod(method);
        request.setEndpoint(resourceName);
        
        // Accept a JSON response from the call
        request.setHeader('Accept', 'application/json');
        
        // Set max timeout
        request.setTimeout(120000);
       
        if (blobBody != null) {
            request.setBodyAsBlob(blobBody);
            system.debug('##BLOB '+blobBody);
        } else if (String.isNotBlank(requestBody)) {
            request.setBody(requestBody);
            request.setHeader('Content-Type', 'application/json');
            system.debug('##H '+requestBody);
        }
        
        if (headers != null && !headers.isEmpty()) {
            for (String headerKey :headers.keySet()) {
                request.setHeader(headerKey, headers.get(headerKey));
                system.debug('##He '+headerKey+':'+ headers.get(headerKey));

            }
        }
        HttpResponse response = new Http().send(request);
        return response;
    }  
    
    public class Response {
        @invocableVariable
        public String jsonstring;
        
        @invocableVariable
        public string errorMessage;
        
        @invocableVariable
        public Integer responseCode;

        @invocableVariable(label ='URL of the file')
        public string url;

        @invocableVariable(label ='Boolean TRUE = new file created')
        public boolean newDoc;
    }
    
    public class Request {
        
        @invocableVariable(label ='Callout - needs to connect to an openid connection to https://googleapis.com' required=true)
        public String callout ;

        
        @invocableVariable(label ='Parent ID where to store the files' )
        public String parentId ; 

        @invocableVariable(label ='Collection of ContentVersion each record will a file in google drive. If not supplied an SOQL expression needs to be provided.' )
        public List<Sobject> inputObjects;
        
        @invocableVariable(label ='SOQL query to use (more efficent)')
        public String soqlQuery;
 
    }
}