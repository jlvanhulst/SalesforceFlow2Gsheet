@isTest
public with sharing class GSheetTest {
    
    @isTest
    public static void testaccountrow (){
        
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        
        Account acc = new Account(Name='jean-luc',Website	='https://valor.vc',AnnualRevenue =1000001,NumberOfEmployees=7);
        List<GSheet.Request> alist = new List<GSheet.Request>();
        GSheet.Request element = new GSheet.Request();
        List<sObject> obj = new List<sObject>();
        obj.add((sObject)Acc);
        element.createNew = false;
        element.soqlQuery = 'SELECT Name,Website,AnnualRevenue FROM Account';
        aList.add(element);

        List<GSheet.Response> testResponseList = GSheet.row(aList);
        
        element.soqlQuery = null;
        element.createNew = true;
        element.inputObjects = obj;
        element.googleSheetId ='run2testid123';
        alist = new List<GSheet.Request>();
        aList.add(element);
        List<GSheet.Response> testResponseList2 = GSheet.row(aList);

        element.googleFileUrl='https://docs.google.com/spreadsheets/d/testirun3/edit#gid=1229423180';    
        alist = new List<GSheet.Request>();
        aList.add(element);
        List<GSheet.Response> testResponseList3 = GSheet.row(aList);

        element.fieldList ='Website,Name,AnnualRevenue';
        element.createNew = true;
        element.googleFileUrl=null;
        element.googleSheetId = null;
        element.newSpreadsheetTitle = 'testrun4';
        alist = new List<GSheet.Request>();
        aList.add(element);
        List<GSheet.Response> testResponseList4 = GSheet.row(aList);
        System.assert(testresponseList4[0].newSpreadsheet,true);
    }
    
}