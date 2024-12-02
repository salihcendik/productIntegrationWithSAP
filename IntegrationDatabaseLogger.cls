/**
 * @author: salih.cendik
**/
public with sharing class IntegrationDatabaseLogger {
    private String originClassName;
    private String additionalMessage;

    public IntegrationDatabaseLogger(String originClassName, String additionalMessage){
        this.originClassName = originClassName;
        this.additionalMessage = additionalMessage ?? '';
    }

    public void logSaveResults(List<sObject> objectList, List<Database.SaveResult> results){
        List<String> errorMessages = new List<String>();
        Integer resultSize = results.size();
        for (Integer i = 0; i < resultSize; i++) {
            if (!results.get(i).isSuccess()){
                generateErrorMsgs(objectList.get(i), results.get(i).getErrors(), errorMessages);
            }
        }
        generateLogs(errorMessages, resultSize);
    }

    public void logUpsertResults(List<sObject> objectList, List<Database.UpsertResult> results){
        List<String> errorMessages = new List<String>();
        Integer resultSize = results.size();
        for (Integer i = 0; i < resultSize; i++) {
            if (!results.get(i).isSuccess()){
                generateErrorMsgs(objectList.get(i), results.get(i).getErrors(), errorMessages);
            }
        }
        generateLogs(errorMessages, resultSize);
    }

    public void generateErrorMsgs(sObject affectedObject, List<Database.Error> databaseErrors, List<String> errorMsgs){
        errorMsgs.add('Record which got error : ' + affectedObject);
        for(Database.Error err : databaseErrors) {
            errorMsgs.add(err.getStatusCode() + ': ' + err.getMessage() + ' Fields that affected this error: ' + err.getFields());
        }
        errorMsgs.add('-------------------------------');
    }

    public void generateLogs(List<String> errorMsgs, Integer resultSize){
        if(!errorMsgs.isEmpty()) {
            Logger.error(this.additionalMessage + 'Error count : ' + errorMsgs.size() / 3).getLogEntryEvent().OriginLocation__c = this.originClassName;
            Logger.error(String.join(errorMsgs, '\n')).getLogEntryEvent().OriginLocation__c = this.originClassName;
        }else{
            Logger.info(this.additionalMessage + 'Number of records successfully saved : ' + resultSize).getLogEntryEvent().OriginLocation__c = this.originClassName;
        }
    }
}