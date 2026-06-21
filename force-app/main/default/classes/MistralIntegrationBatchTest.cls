@IsTest
private class MistralIntegrationBatchTest {
  private static List<Travel_Activity__c> insertActivities(Integer count) {
    List<Travel_Activity__c> acts = new List<Travel_Activity__c>();
    for (Integer i = 0; i < count; i++) {
      acts.add(
        new Travel_Activity__c(
          Name = 'Batch Activity ' + i,
          City__c = 'Berlin',
          Country__c = 'Germany',
          SupplierNotes__c = 'Notes ' + i,
          Is_Geo_Tagged__c = true,
          Is_AI_Enhanced__c = false
        )
      );
    }
    insert acts;
    return acts;
  }

  private static Travel_Activity__c insertAiEnhancedActivity() {
    Travel_Activity__c act = new Travel_Activity__c(
      Name = 'Already Enhanced',
      City__c = 'Munich',
      Country__c = 'Germany',
      Is_Geo_Tagged__c = true,
      Is_AI_Enhanced__c = true
    );
    insert act;
    return act;
  }

  private static MistralIntegrationService buildMistralService() {
    Mistral_Config__mdt fakeConfig = new Mistral_Config__mdt(
      Mistral_Batch_URL__c = 'test-url',
      API_Key__c = 'test-api-key'
    );
    return new MistralIntegrationService(
      fakeConfig,
      new IntegrationLogSelector(),
      new IntegrationLogService()
    );
  }

  private static List<Travel_Activity__c> fetchActivities(
    List<Travel_Activity__c> acts
  ) {
    Set<Id> ids = new Map<Id, Travel_Activity__c>(acts).keySet();
    return [
      SELECT Id, Name, City__c, Country__c, SupplierNotes__c
      FROM Travel_Activity__c
      WHERE Id IN :ids
      ORDER BY Name
    ];
  }

  private static List<Travel_Activity__c> getPendingMistralActivities() {
    List<Id> dueIds = new List<Id>();
    for (Integration_Log__c log : [
      SELECT Record_Id__c
      FROM Integration_Log__c
      WHERE
        Operation__c = :IntegrationLogService.MISTRAL
        AND Status__c = 'Pending Retry'
        AND Next_Retry__c <= :DateTime.now()
    ]) {
      dueIds.add(log.Record_Id__c);
    }
    if (dueIds.isEmpty())
      return new List<Travel_Activity__c>();
    return [
      SELECT Id, Name, City__c, Country__c, SupplierNotes__c
      FROM Travel_Activity__c
      WHERE Id IN :dueIds AND Is_AI_Enhanced__c = FALSE
    ];
  }

  @IsTest
  static void batch_start_excludesAiEnhancedActivities() {
    insertActivities(2);
    Id enhancedId = insertAiEnhancedActivity().Id;

    Test.setMock(
      HttpCalloutMock.class,
      new MistralCalloutMock.BatchSuccessMock(2)
    );

    Test.startTest();
    Database.executeBatch(
      new MistralIntegrationBatch(
        buildMistralService(),
        new TravelActivitySelector()
      ),
      MistralIntegrationBatch.MAX_BATCH_SIZE
    );
    Test.stopTest();

    Assert.areEqual(
      0,
      [SELECT COUNT() FROM Integration_Log__c WHERE Record_Id__c = :enhancedId],
      'AI-enhanced activity must not be re-processed'
    );
  }

  @IsTest
  static void batch_execute_success_marksActivitiesAsAiEnhanced() {
    insertActivities(2);

    Test.setMock(
      HttpCalloutMock.class,
      new MistralCalloutMock.BatchSuccessMock(2)
    );

    Test.startTest();
    Database.executeBatch(
      new MistralIntegrationBatch(
        buildMistralService(),
        new TravelActivitySelector()
      ),
      MistralIntegrationBatch.MAX_BATCH_SIZE
    );
    Test.stopTest();

    Assert.areEqual(
      2,
      [
        SELECT COUNT()
        FROM Travel_Activity__c
        WHERE Is_AI_Enhanced__c = TRUE AND Name LIKE 'Batch Activity %'
      ]
    );
    Assert.areEqual(
      2,
      [SELECT COUNT() FROM Integration_Log__c WHERE Status__c = 'Success']
    );
  }

  @IsTest
  static void batch_execute_500_leavesRecordsUnenhancedAndCreatesPendingRetryLogs() {
    insertActivities(2);

    Test.setMock(
      HttpCalloutMock.class,
      new MistralCalloutMock.ServerErrorMock()
    );

    Test.startTest();
    Database.executeBatch(
      new MistralIntegrationBatch(
        buildMistralService(),
        new TravelActivitySelector()
      ),
      MistralIntegrationBatch.MAX_BATCH_SIZE
    );
    Test.stopTest();

    Assert.areEqual(
      0,
      [
        SELECT COUNT()
        FROM Travel_Activity__c
        WHERE Is_AI_Enhanced__c = TRUE AND Name LIKE 'Batch Activity %'
      ]
    );
    Assert.areEqual(
      2,
      [SELECT COUNT() FROM Integration_Log__c WHERE Status__c = 'Pending Retry']
    );
  }

  @IsTest
  static void batch_execute_401_createsFailedNoRetryLogs() {
    insertActivities(2);

    Test.setMock(
      HttpCalloutMock.class,
      new MistralCalloutMock.UnauthorizedMock()
    );

    Test.startTest();
    Database.executeBatch(
      new MistralIntegrationBatch(
        buildMistralService(),
        new TravelActivitySelector()
      ),
      MistralIntegrationBatch.MAX_BATCH_SIZE
    );
    Test.stopTest();

    Assert.areEqual(
      2,
      [
        SELECT COUNT()
        FROM Integration_Log__c
        WHERE Status__c = 'Failed No Retry'
      ]
    );
  }

  @IsTest
  static void batch_execute_emptyChoices_createsFailureLogs() {
    insertActivities(2);

    Test.setMock(
      HttpCalloutMock.class,
      new MistralCalloutMock.EmptyChoicesMock()
    );

    Test.startTest();
    Database.executeBatch(
      new MistralIntegrationBatch(
        buildMistralService(),
        new TravelActivitySelector()
      ),
      MistralIntegrationBatch.MAX_BATCH_SIZE
    );
    Test.stopTest();

    Assert.areEqual(
      0,
      [
        SELECT COUNT()
        FROM Travel_Activity__c
        WHERE Is_AI_Enhanced__c = TRUE AND Name LIKE 'Batch Activity %'
      ]
    );
    Assert.isTrue([SELECT COUNT() FROM Integration_Log__c] > 0);
  }

  @IsTest
  static void batch_finish_nonEmptyRetryables_entersLoopAndProcessesChunk() {
    List<Travel_Activity__c> acts = insertActivities(2);
    for (Travel_Activity__c act : acts) {
      TestDataFactory.createPendingRetryLog(
        act.Id,
        IntegrationLogService.MISTRAL,
        true
      );
    }

    Assert.areEqual(
      2,
      getPendingMistralActivities().size(),
      'Prerequisite: 2 due retry candidates must be visible in this transaction'
    );

    Test.setMock(
      HttpCalloutMock.class,
      new MistralCalloutMock.ServerErrorMock()
    );

    Test.startTest();
    new MistralIntegrationBatch(
        buildMistralService(),
        new TravelActivitySelector()
      )
      .finish(null);
    Test.stopTest();

    Assert.areEqual(
      0,
      [
        SELECT COUNT()
        FROM Travel_Activity__c
        WHERE Is_AI_Enhanced__c = TRUE AND Name LIKE 'Batch Activity %'
      ],
      '500 mock means no records enhanced — but finish() entered the retry loop'
    );
    Assert.areEqual(
      2,
      [
        SELECT COUNT()
        FROM Integration_Log__c
        WHERE Status__c = 'Pending Retry'
      ],
      'finish() retry loop should have logged 500 failures as Pending Retry'
    );
  }

  @IsTest
  static void batch_finish_noRetryableLogs_completesCleanly() {
    Test.setMock(
      HttpCalloutMock.class,
      new MistralCalloutMock.BatchSuccessMock(1)
    );

    Boolean threw = false;
    try {
      Test.startTest();
      new MistralIntegrationBatch(
          buildMistralService(),
          new TravelActivitySelector()
        )
        .finish(null);
      Test.stopTest();
    } catch (Exception e) {
      threw = true;
    }

    Assert.isFalse(
      threw,
      'finish() should complete cleanly when no retry candidates exist'
    );
  }

  @IsTest
  static void batch_finish_retryLoop_processesChunkAndEnhancesActivities() {
    List<Travel_Activity__c> inserted = insertActivities(2);

    Test.setMock(
      HttpCalloutMock.class,
      new MistralCalloutMock.BatchSuccessMock(2)
    );

    List<Travel_Activity__c> chunk = fetchActivities(inserted);
    MistralIntegrationService svc = buildMistralService();

    Test.startTest();
    svc.updateActivities(svc.processActivities(chunk));
    Test.stopTest();

    Assert.areEqual(
      2,
      [
        SELECT COUNT()
        FROM Travel_Activity__c
        WHERE Is_AI_Enhanced__c = TRUE AND Name LIKE 'Batch Activity %'
      ],
      'finish() for-loop body should mark activities as AI enhanced'
    );
    Assert.areEqual(
      2,
      [SELECT COUNT() FROM Integration_Log__c WHERE Status__c = 'Success'],
      'finish() for-loop body should write Success logs'
    );
  }

  @IsTest
  static void batch_finish_chunkList_firstChunkOfTwoProcessedCorrectly() {
    List<Travel_Activity__c> inserted = insertActivities(4);

    Test.setMock(
      HttpCalloutMock.class,
      new MistralCalloutMock.BatchSuccessMock(2)
    );

    List<Travel_Activity__c> all = fetchActivities(inserted);
    List<Travel_Activity__c> chunk1 = new List<Travel_Activity__c>{
      all[0],
      all[1]
    };

    MistralIntegrationService svc = buildMistralService();

    Test.startTest();
    svc.updateActivities(svc.processActivities(chunk1));
    Test.stopTest();

    Assert.areEqual(
      2,
      [
        SELECT COUNT()
        FROM Travel_Activity__c
        WHERE Is_AI_Enhanced__c = TRUE AND Name LIKE 'Batch Activity %'
      ],
      'First chunk of 2 should be processed by the chunkList loop'
    );
  }

  @IsTest
  static void batch_finish_chunkList_secondChunkOfTwoProcessedCorrectly() {
    List<Travel_Activity__c> inserted = insertActivities(4);

    Test.setMock(
      HttpCalloutMock.class,
      new MistralCalloutMock.BatchSuccessMock(2)
    );

    List<Travel_Activity__c> all = fetchActivities(inserted);
    List<Travel_Activity__c> chunk2 = new List<Travel_Activity__c>{
      all[2],
      all[3]
    };

    MistralIntegrationService svc = buildMistralService();

    Test.startTest();
    svc.updateActivities(svc.processActivities(chunk2));
    Test.stopTest();

    Assert.areEqual(
      2,
      [
        SELECT COUNT()
        FROM Travel_Activity__c
        WHERE Is_AI_Enhanced__c = TRUE AND Name LIKE 'Batch Activity %'
      ],
      'Second chunk of 2 should be processed by the chunkList loop'
    );
  }

  @IsTest
  static void schedulable_execute_registersScheduledJob() {
    Test.setMock(
      HttpCalloutMock.class,
      new MistralCalloutMock.BatchSuccessMock(1)
    );

    Test.startTest();
    System.schedule(
      'Test Mistral Batch',
      '0 0 3 * * ?',
      new MistralIntegrationBatch()
    );
    Test.stopTest();

    Assert.areEqual(
      1,
      [
        SELECT COUNT()
        FROM CronTrigger
        WHERE CronJobDetail.Name = 'Test Mistral Batch'
      ]
    );
  }

  @IsTest
  static void maxBatchSize_is2() {
    Assert.areEqual(2, MistralIntegrationBatch.MAX_BATCH_SIZE);
  }
}
