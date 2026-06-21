public with sharing class MistralIntegrationBatch implements Database.Batchable<SObject>, Database.AllowsCallouts, Schedulable {
  @TestVisible
  private static final Integer MAX_BATCH_SIZE = 2;

  private final MistralIntegrationService mistralService;
  private final TravelActivitySelector activitySelector;

  // Production constructor
  public MistralIntegrationBatch() {
    this(new MistralIntegrationService(), new TravelActivitySelector());
  }

  // Test-injectable constructor
  @TestVisible
  private MistralIntegrationBatch(
    MistralIntegrationService mistralService,
    TravelActivitySelector activitySelector
  ) {
    this.mistralService = mistralService;
    this.activitySelector = activitySelector;
  }

  public void execute(SchedulableContext ctx) {
    Database.executeBatch(new MistralIntegrationBatch(), MAX_BATCH_SIZE);
  }

  public Database.QueryLocator start(Database.BatchableContext ctx) {
    return Database.getQueryLocator(
      [
        SELECT Id, Name, City__c, Country__c, SupplierNotes__c
        FROM Travel_Activity__c
        WHERE Is_AI_Enhanced__c = FALSE
        ORDER BY CreatedDate ASC
      ]
    );
  }

  public void execute(
    Database.BatchableContext ctx,
    List<Travel_Activity__c> scope
  ) {
    try {
      List<MistralDTO.MistralResult> results = mistralService.processActivities(
        scope
      );
      mistralService.updateActivities(results);
    } catch (Exception e) {
      System.debug('Error processing batch chunk: ' + e.getMessage());
    }
  }

  public void finish(Database.BatchableContext ctx) {
    List<Travel_Activity__c> retryableActivities = activitySelector.selectSummaryRetryableActivities();
    if (!retryableActivities.isEmpty()) {
      List<List<Travel_Activity__c>> retryChunks = chunkList(
        retryableActivities,
        MAX_BATCH_SIZE
      );
      for (List<Travel_Activity__c> chunk : retryChunks) {
        try {
          List<MistralDTO.MistralResult> results = mistralService.processActivities(
            chunk
          );
          mistralService.updateActivities(results);
        } catch (Exception e) {
          System.debug('Error processing retry chunk: ' + e.getMessage());
        }
      }
    }
  }

  private List<List<Travel_Activity__c>> chunkList(
    List<Travel_Activity__c> inputList,
    Integer chunkSize
  ) {
    List<List<Travel_Activity__c>> chunks = new List<List<Travel_Activity__c>>();
    for (Integer i = 0; i < inputList.size(); i += chunkSize) {
      List<Travel_Activity__c> chunk = new List<Travel_Activity__c>();
      for (Integer j = i; j < Math.min(i + chunkSize, inputList.size()); j++) {
        chunk.add(inputList[j]);
      }
      chunks.add(chunk);
    }
    return chunks;
  }
}
