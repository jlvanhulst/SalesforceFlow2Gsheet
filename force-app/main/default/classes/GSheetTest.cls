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
        element.inputObjects = obj;
        element.googleSheetId ='testid123';
        aList.add(element);
        
        List<GSheet.Response> testResponseList = GSheet.row(aList);
        element.googleFileUrl='https://docs.google.com/spreadsheets/d/testid123/edit#gid=1229423180';    
        element.fieldList ='Website,Name,AnnualRevenue';
        List<GSheet.Response> testResponseList2 = GSheet.row(aList);
        
        element.createNew = true;
        element.googleFileUrl=null;
        element.googleSheetId = null;
        List<GSheet.Response> testResponseList3 = GSheet.row(aList);

    }
    
}