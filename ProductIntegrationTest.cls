@IsTest
global class TR_ProductIntegrationBatch_Test {

    @TestSetup
    static void setupData(){
        Integration_Settings__c setting = new Integration_Settings__c(
            Name = 'TR_Settings',
            Product_Integration_Batch_Size__c = 100,
            Product_Integration_Running_Date__c = Date.today()
        );
        insert setting;
		
        Product2 product = new Product2(
            RecordTypeId = Schema.sObjectType.Product2.getRecordTypeInfosByDeveloperName().get('TR_Product').getRecordTypeId(),
            Name = 'Test',
            ProductCode = '2100_100',
            SAP_Number__c = '2100_100',
            BaseUnitOfMeasure__c = 'ST',
            IsActive = true,
            ProductHierarchy__c = '123',
            BoxType__c = 'VT'
        );
        insert product;
        
        Definition2__c productSerieDefinition = new Definition2__c(
            RecordTypeId = Schema.sObjectType.Definition2__c.getRecordTypeInfosByDeveloperName().get('Product_Serie').getRecordTypeId(),
            Name = 'TEST',
            SAPCode__c = '2100_100',
            Company__c = '2100');
        insert productSerieDefinition;

        //for ProductIntegrationJob()
        insert new Product2DataTranslation(ParentId = product.Id, Language = 'tr', Name = 'TR');
    }

    @IsTest
    static void productIntegrationBatch_Test() {
        Test.startTest();
        Test.setMock(WebServiceMock.class, new ProductIntegrationMock());
        Database.executeBatch(new ProductIntegrationBatch(), 1);
        Test.stopTest();
        Assert.isTrue([SELECT Id FROM Product_Sales_Org__c].size() > 0, 'Product integration is failed');
    }
    
    @IsTest
    static void productIntegrationJob_Test() {
        Test.startTest();
        Test.setMock(WebServiceMock.class, new ProductIntegrationMock());
        Database.executeBatch(new ProductIntegrationJob(), 1);
        new ProductIntegrationJob().execute(null);
        Test.stopTest();
        Assert.isTrue([SELECT Id FROM Product2DataTranslation].size() > 0, 'Product integration is failed');
    }

    @IsTest
    static void executeManualBatchUpdate_Test() {
        Product2 product = [SELECT SAP_Number__c FROM Product2 LIMIT 1];
        Test.startTest();
        Test.setMock(WebServiceMock.class, new ProductIntegrationMock());
        Database.executeBatch(new roductIntegrationBatch(null, '2201', new Set<String>{product.SAP_Number__c}), 1);
        Test.stopTest();
        String expectedUnit = 'ST';
        String actualUnit = [SELECT QuantityUnitOfMeasure FROM Product2 LIMIT 1].QuantityUnitOfMeasure;
        Assert.areEqual(expectedUnit, actualUnit, 'executeManualBatchUpdate_Test is failed');
    }
}