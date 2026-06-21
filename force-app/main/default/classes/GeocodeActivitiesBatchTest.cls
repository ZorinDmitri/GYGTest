@IsTest
private class GeocodeActivitiesBatchTest {
  @TestSetup
  static void setup() {
    // Only the address-less and always-tagged records go here —
    // no eligible activities, so the trigger never enqueues the queueable.
    TestDataFactory.createGeoTaggedActivity(true);
    TestDataFactory.createActivityWithoutAddress(true);
  }

  private static List<Travel_Activity__c> insertEligibleActivities(
    Integer count
  ) {
    // Insert with Is_Geo_Tagged__c = false — these are the batch candidates.
    // Done inside individual tests so each test controls its own data set.
    List<Travel_Activity__c> activities = new List<Travel_Activity__c>();
    for (Integer i = 0; i < count; i++) {
      activities.add(
        new Travel_Activity__c(
          Name = 'Eligible ' + i,
          Street__c = i + ' Main St',
          City__c = 'Berlin',
          Country__c = 'Germany',
          Zip__c = '1000' + i,
          Is_Geo_Tagged__c = false
        )
      );
    }
    insert activities;
    return activities;
  }

  private static Id getGeoTaggedId() {
    return [
      SELECT Id
      FROM Travel_Activity__c
      WHERE Is_Geo_Tagged__c = TRUE
      LIMIT 1
    ]
    .Id;
  }

  private static Id getNoAddressId() {
    return [SELECT Id FROM Travel_Activity__c WHERE Street__c = NULL LIMIT 1]
    .Id;
  }

  @IsTest
  static void batch_execute_successMock_tagsAllEligibleActivities() {
    insertEligibleActivities(3);

    Test.setMock(HttpCalloutMock.class, new GeocodeCalloutMock.SuccessMock());

    Test.startTest();
    Database.executeBatch(
      new GeocodeActivitiesBatch(),
      GeocodeActivitiesBatch.MAX_BATCH_SIZE
    );
    Test.stopTest();

    Assert.areEqual(
      4, // 3 just tagged + 1 pre-tagged from setup
      [SELECT COUNT() FROM Travel_Activity__c WHERE Is_Geo_Tagged__c = TRUE]
    );
    Assert.areEqual(
      3,
      [SELECT COUNT() FROM Integration_Log__c WHERE Status__c = 'Success'],
      'One success log per eligible activity'
    );
  }

  @IsTest
  static void batch_execute_500Mock_leavesRecordsUntaggedAndCreatesPendingRetryLogs() {
    insertEligibleActivities(3);

    Test.setMock(
      HttpCalloutMock.class,
      new GeocodeCalloutMock.ServerErrorMock()
    );

    Test.startTest();
    Database.executeBatch(
      new GeocodeActivitiesBatch(),
      GeocodeActivitiesBatch.MAX_BATCH_SIZE
    );
    Test.stopTest();

    Assert.areEqual(
      0,
      [
        SELECT COUNT()
        FROM Travel_Activity__c
        WHERE
          Is_Geo_Tagged__c = TRUE
          AND Street__c != NULL
          AND Name LIKE 'Eligible %'
      ]
    );
    Assert.areEqual(
      3,
      [
        SELECT COUNT()
        FROM Integration_Log__c
        WHERE Status__c = 'Pending Retry'
      ],
      'One pending retry log per failed activity'
    );
  }

  @IsTest
  static void batch_execute_401Mock_createsFailedNoRetryLogs() {
    insertEligibleActivities(3);

    Test.setMock(
      HttpCalloutMock.class,
      new GeocodeCalloutMock.UnauthorizedMock()
    );

    Test.startTest();
    Database.executeBatch(
      new GeocodeActivitiesBatch(),
      GeocodeActivitiesBatch.MAX_BATCH_SIZE
    );
    Test.stopTest();

    Assert.areEqual(
      3,
      [
        SELECT COUNT()
        FROM Integration_Log__c
        WHERE Status__c = 'Failed No Retry'
      ],
      'Failed No Retry logs should be created for 401'
    );
  }

  @IsTest
  static void batch_execute_calloutException_createsPendingRetryLogsWithStatus0() {
    insertEligibleActivities(3);

    Test.setMock(
      HttpCalloutMock.class,
      new GeocodeCalloutMock.CalloutExceptionMock()
    );

    Test.startTest();
    Database.executeBatch(
      new GeocodeActivitiesBatch(),
      GeocodeActivitiesBatch.MAX_BATCH_SIZE
    );
    Test.stopTest();

    Assert.areEqual(
      3,
      [
        SELECT COUNT()
        FROM Integration_Log__c
        WHERE Status__c = 'Pending Retry' AND HTTP_Status__c = 0
      ],
      'Callout exception should produce status-0 pending retry logs'
    );
  }

  @IsTest
  static void batch_start_excludesActivitiesWithoutAddress() {
    insertEligibleActivities(1);
    Id noAddressId = getNoAddressId();

    Test.setMock(HttpCalloutMock.class, new GeocodeCalloutMock.SuccessMock());

    Test.startTest();
    Database.executeBatch(
      new GeocodeActivitiesBatch(),
      GeocodeActivitiesBatch.MAX_BATCH_SIZE
    );
    Test.stopTest();

    Assert.areEqual(
      0,
      [
        SELECT COUNT()
        FROM Integration_Log__c
        WHERE Record_Id__c = :noAddressId
      ],
      'Address-less activity must never be processed'
    );
  }

  @IsTest
  static void batch_start_excludesAlreadyGeoTaggedActivities() {
    insertEligibleActivities(1);
    Id geoTaggedId = getGeoTaggedId();

    Test.setMock(HttpCalloutMock.class, new GeocodeCalloutMock.SuccessMock());

    Test.startTest();
    Database.executeBatch(
      new GeocodeActivitiesBatch(),
      GeocodeActivitiesBatch.MAX_BATCH_SIZE
    );
    Test.stopTest();

    Assert.areEqual(
      0,
      [
        SELECT COUNT()
        FROM Integration_Log__c
        WHERE Record_Id__c = :geoTaggedId
      ],
      'Already geo-tagged activity must not be re-processed'
    );
  }

  @IsTest
  static void batch_finish_retryLoop_processesRetryableCandidatesAndTagsThem() {
    List<Travel_Activity__c> eligible = insertEligibleActivities(3);

    for (Travel_Activity__c act : eligible) {
      TestDataFactory.createPendingRetryLog(
        act.Id,
        IntegrationLogService.GEOCODE,
        true
      );
    }

    Test.setMock(HttpCalloutMock.class, new GeocodeCalloutMock.SuccessMock());

    GeocodeActivitiesBatch batchInstance = new GeocodeActivitiesBatch(
      new ActivityGeocodeService(),
      new TravelActivitySelector()
    );

    Test.startTest();
    batchInstance.finish(null);
    Test.stopTest();

    Assert.areEqual(
      3,
      [
        SELECT COUNT()
        FROM Travel_Activity__c
        WHERE Is_Geo_Tagged__c = TRUE AND Name LIKE 'Eligible %'
      ],
      'finish() retry loop should geo-tag all retryable candidates'
    );
    Assert.areEqual(
      3,
      [SELECT COUNT() FROM Integration_Log__c WHERE Status__c = 'Success'],
      'finish() retry loop should write a Success log per candidate'
    );
  }

  @IsTest
  static void batch_finish_noRetryableLogs_completesCleanly() {
    Test.setMock(HttpCalloutMock.class, new GeocodeCalloutMock.SuccessMock());

    GeocodeActivitiesBatch batchInstance = new GeocodeActivitiesBatch(
      new ActivityGeocodeService(),
      new TravelActivitySelector()
    );

    Boolean threw = false;
    try {
      Test.startTest();
      batchInstance.finish(null);
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
  static void schedulable_execute_registersScheduledJob() {
    Test.setMock(HttpCalloutMock.class, new GeocodeCalloutMock.SuccessMock());

    Test.startTest();
    System.schedule(
      'Test Geocode Batch',
      '0 0 2 * * ?',
      new GeocodeActivitiesBatch()
    );
    Test.stopTest();

    Assert.areEqual(
      1,
      [
        SELECT COUNT()
        FROM CronTrigger
        WHERE CronJobDetail.Name = 'Test Geocode Batch'
      ]
    );
  }

  @IsTest
  static void maxBatchSize_is100() {
    Assert.areEqual(100, GeocodeActivitiesBatch.MAX_BATCH_SIZE);
  }
}
