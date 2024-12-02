@isTest
public with sharing class IntegrationDatabaseLoggerTest {
    @isTest
    public static void logSaveResultsTest() {
        List<Contact> contactsToInsert = new List<Contact>{new Contact(LastName = 'Test')};
        Database.SaveResult[] results = database.insert(contactsToInsert, false, AccessLevel.SYSTEM_MODE);
        new IntegrationDatabaseLogger(null, null).logSaveResults(contactsToInsert, results);
    }

    @isTest
    public static void logSaveResults_NegativeTest() {
        List<Contact> contactsToInsert = new List<Contact>{new Contact(FirstName = 'Test')};
        Database.SaveResult[] results = database.insert(contactsToInsert, false, AccessLevel.SYSTEM_MODE);
        new IntegrationDatabaseLogger(null, null).logSaveResults(contactsToInsert, results);
    }

    @isTest
    public static void logUpsertResultsTest() {
        List<Contact> contactsToUpsert = new List<Contact>{new Contact(LastName = 'Test')};
        Database.UpsertResult[] results = database.upsert(contactsToUpsert, false, AccessLevel.SYSTEM_MODE);
        new IntegrationDatabaseLogger(null, null).logUpsertResults(contactsToUpsert, results);
    }
}