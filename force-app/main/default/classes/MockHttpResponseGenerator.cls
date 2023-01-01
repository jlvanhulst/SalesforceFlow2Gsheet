@isTest
global class MockHttpResponseGenerator implements HttpCalloutMock {
    // Implement this interface method
    global HTTPResponse respond(HTTPRequest req) {
 
        // Create a fake response
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody('{"spreadsheetId": "testid123","properties": {  "title": "test "}, "sheets": [ { "properties": { "sheetId": 0, "title": "Sheet1", "index": 0,  "sheetType": "GRID",  "gridProperties": {  "rowCount": 999,   "columnCount": 43 }}},{ "properties": { "sheetId": 23861466,"title": "Sheet2", "index": 1,"sheetType": "GRID","gridProperties": {  "rowCount": 1000,  "columnCount": 26  }  } }  ]  }     ');
        res.setStatusCode(200);
        return res;
    }
}
