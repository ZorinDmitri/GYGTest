public with sharing class IntegrationLogSelector {
  public Map<Id, Integration_Log__c> selectLatestByOperationAndRecordIds(
    Set<Id> recordIds,
    String operation
  ) {
    List<Integration_Log__c> logs = [
      SELECT
        Id,
        Record_Id__c,
        Status__c,
        Retry_Count__c,
        Next_Retry__c,
        Operation__c
      FROM Integration_Log__c
      WHERE Record_Id__c IN :recordIds AND Operation__c = :operation
      WITH USER_MODE
      ORDER BY CreatedDate DESC
    ];

    Map<Id, Integration_Log__c> latestByRecord = new Map<Id, Integration_Log__c>();
    for (Integration_Log__c log : logs) {
      Id recId = log.Record_Id__c;
      if (!latestByRecord.containsKey(recId)) {
        latestByRecord.put(recId, log);
      }
    }
    return latestByRecord;
  }

  public List<Id> selectPendingRetryLogs(String operation) {
    List<Integration_Log__c> logs = [
      SELECT Record_Id__c
      FROM Integration_Log__c
      WHERE
        Status__c = 'Pending Retry'
        AND Next_Retry__c <= :DateTime.now()
        AND Operation__c = :operation
    ];

    List<Id> result = new List<Id>();
    for (Integration_Log__c log : logs) {
      result.add(log.Record_Id__c);
    }

    return result;
  }
}
