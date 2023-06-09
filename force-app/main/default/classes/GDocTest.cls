@isTest
public with sharing class GDocTest {
    
    @isTest
    public static void testdoc (){
        
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        
        Account acc = new Account(Name='jean-luc',Website	='https://valor.vc',AnnualRevenue =1000001,NumberOfEmployees=7);
        List<Gdocs.Request> alist = new List<GDocs.Request>();
        GDocs.Request element = new GDocs.Request();
        List<sObject> obj = new List<sObject>();
        obj.add((sObject)Acc);
        element.inputObjects = obj;
        element.googleDocId ='testid123';
        element.paragraphText ='some random text';
        element.callout ='GTest';
        aList.add(element);
        
        List<GDocs.Response> testResponseList = GDocs.paragraph(aList);
        element.googleFileUrl='https://docs.google.com/document/d/testid123/edit';    
        element.fieldList ='Website,Name,AnnualRevenue';
        List<GDocs.Response> testResponseList2 = GDocs.paragraph(aList);
        
        element.createNew = true;
        element.googleFileUrl=null;
        element.googleDocId = null;
        List<GDocs.Response> testResponseList3 = GDocs.paragraph(aList);

    }
    
}