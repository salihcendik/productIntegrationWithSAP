global with sharing class ProductIntegrationJob implements Schedulable, Database.Batchable<sObject> {
    public String originalTransactionId;
    
    global Database.QueryLocator start(Database.BatchableContext BC){
        this.originalTransactionId = Logger.getTransactionId();
        Logger.info('Starting Product Integration JOB with S4HANA...');
        Logger.saveLog();
        return Database.getQueryLocator('SELECT Id, Parent.Id FROM Product2DataTranslation WHERE Parent.RecordType.Name =\'TR Product\'');
    }
    
    global void execute(Database.BatchableContext BC, List<sObject> scope){
        delete scope;
    }
    global void execute(SchedulableContext SC) {
        database.executebatch(new ProductIntegrationJob(), 1000);
    }
    
    global void finish(Database.BatchableContext BC){
        Logger.info('Finishing the execution of Product Integration JOB with S4HANA.');
        Logger.saveLog();
        Database.executeBatch(new ProductIntegrationBatch(), 1);
    }
}