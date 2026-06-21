public with sharing class TravelActivitySelector {
  public List<Travel_Activity__c> selectUngeocodedLimited(Integer batchLimit) {
    return [
      SELECT
        Id,
        Street__c,
        City__c,
        Country__c,
        Is_Geo_Tagged__c,
        Zip__c,
        Location__c
      FROM Travel_Activity__c
      WHERE
        Is_Geo_Tagged__c = FALSE
        AND Country__c != NULL
        AND Street__c != NULL
        AND City__c != NULL
      WITH USER_MODE
      LIMIT :batchLimit
    ];
  }

  public List<Travel_Activity__c> selectUnsummarizedActivitiesToProcess() {
    return [
      SELECT Id, Name, Is_AI_Enhanced__c, City__c, SupplierNotes__c
      FROM Travel_Activity__c
      WHERE Is_AI_Enhanced__c = FALSE
      ORDER BY CreatedDate ASC
    ];
  }

  public List<Travel_Activity__c> selectByIds(Set<Id> ids) {
    return [
      SELECT
        Id,
        Street__c,
        City__c,
        Country__c,
        Zip__c,
        Location__c,
        Is_Geo_Tagged__c
      FROM Travel_Activity__c
      WHERE Id IN :ids
      WITH USER_MODE
    ];
  }

  public List<Travel_Activity__c> selectGeoTagRetryable() {
    List<Id> pendingLogRecordIds = new IntegrationLogSelector()
      .selectPendingRetryLogs(IntegrationLogService.GEOCODE);
    return [
      SELECT Id, Street__c, City__c, Country__c, Zip__c, Location__c
      FROM Travel_Activity__c
      WHERE Id IN :pendingLogRecordIds AND Is_Geo_Tagged__c = FALSE
      WITH USER_MODE
    ];
  }

  public List<Travel_Activity__c> selectSummaryRetryableActivities() {
    List<Id> pendingLogRecordIds = new IntegrationLogSelector()
      .selectPendingRetryLogs(IntegrationLogService.MISTRAL);
    if (pendingLogRecordIds.isEmpty())
      return new List<Travel_Activity__c>();

    return [
      SELECT Id, Name, City__c, SupplierNotes__c
      FROM Travel_Activity__c
      WHERE Id IN :pendingLogRecordIds AND Is_AI_Enhanced__c = FALSE
      WITH USER_MODE
    ];
  }
}
