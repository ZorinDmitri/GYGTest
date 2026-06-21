@IsTest
private class TravelActivitySelectorTest {
  private static Travel_Activity__c insertEligibleActivity(String name) {
    Travel_Activity__c act = new Travel_Activity__c(
      Name = name,
      Street__c = '1 Main St',
      City__c = 'Berlin',
      Country__c = 'Germany',
      Zip__c = '10115',
      Is_Geo_Tagged__c = false,
      Is_AI_Enhanced__c = false
    );
    insert act;
    return act;
  }

  private static List<Travel_Activity__c> insertEligibleActivities(
    Integer count
  ) {
    List<Travel_Activity__c> acts = new List<Travel_Activity__c>();
    for (Integer i = 0; i < count; i++) {
      acts.add(
        new Travel_Activity__c(
          Name = 'Activity ' + i,
          Street__c = i + ' Main St',
          City__c = 'Berlin',
          Country__c = 'Germany',
          Zip__c = '1000' + i,
          Is_Geo_Tagged__c = false,
          Is_AI_Enhanced__c = false
        )
      );
    }
    insert acts;
    return acts;
  }

  private static Travel_Activity__c insertGeoTaggedActivity() {
    Travel_Activity__c act = new Travel_Activity__c(
      Name = 'GeoTagged Activity',
      Street__c = '1 Tagged St',
      City__c = 'Munich',
      Country__c = 'Germany',
      Zip__c = '80331',
      Is_Geo_Tagged__c = true,
      Is_AI_Enhanced__c = false,
      Location__Latitude__s = 48.1351,
      Location__Longitude__s = 11.5820
    );
    insert act;
    return act;
  }

  private static Travel_Activity__c insertActivityWithoutAddress() {
    Travel_Activity__c act = new Travel_Activity__c(
      Name = 'No Address Activity',
      Is_Geo_Tagged__c = false,
      Is_AI_Enhanced__c = false
    );
    insert act;
    return act;
  }

  private static Travel_Activity__c insertAiEnhancedActivity() {
    Travel_Activity__c act = new Travel_Activity__c(
      Name = 'AI Enhanced Activity',
      Street__c = '5 Smart St',
      City__c = 'Hamburg',
      Country__c = 'Germany',
      Zip__c = '20095',
      Is_Geo_Tagged__c = true, // tagged to suppress trigger
      Is_AI_Enhanced__c = true
    );
    insert act;
    return act;
  }

  @IsTest
  static void selectUngeocodedLimited_returnsActivitiesWithFullAddress() {
    Test.setMock(HttpCalloutMock.class, new GeocodeCalloutMock.SuccessMock());
    insertEligibleActivities(3);

    Test.startTest();
    List<Travel_Activity__c> result = new TravelActivitySelector()
      .selectUngeocodedLimited(200);
    Test.stopTest();

    Assert.areEqual(3, result.size());
    for (Travel_Activity__c act : result) {
      Assert.isFalse(act.Is_Geo_Tagged__c);
      Assert.isNotNull(act.Street__c);
      Assert.isNotNull(act.City__c);
    }
  }

  @IsTest
  static void selectUngeocodedLimited_excludesGeoTaggedActivities() {
    Test.setMock(HttpCalloutMock.class, new GeocodeCalloutMock.SuccessMock());
    insertEligibleActivities(2);
    Id geoTaggedId = insertGeoTaggedActivity().Id;

    Test.startTest();
    List<Travel_Activity__c> result = new TravelActivitySelector()
      .selectUngeocodedLimited(200);
    Test.stopTest();

    Set<Id> resultIds = new Map<Id, Travel_Activity__c>(result).keySet();
    Assert.isFalse(
      resultIds.contains(geoTaggedId),
      'GeoTagged activity must be excluded'
    );
    Assert.areEqual(2, result.size());
  }

  @IsTest
  static void selectUngeocodedLimited_respectsLimit() {
    Test.setMock(HttpCalloutMock.class, new GeocodeCalloutMock.SuccessMock());
    insertEligibleActivities(3);

    Test.startTest();
    List<Travel_Activity__c> result = new TravelActivitySelector()
      .selectUngeocodedLimited(1);
    Test.stopTest();

    Assert.areEqual(1, result.size(), 'Should respect the limit parameter');
  }

  @IsTest
  static void selectUngeocodedLimited_excludesActivitiesWithoutAddress() {
    Test.setMock(HttpCalloutMock.class, new GeocodeCalloutMock.SuccessMock());
    insertEligibleActivities(2);
    Id noAddressId = insertActivityWithoutAddress().Id;

    Test.startTest();
    List<Travel_Activity__c> result = new TravelActivitySelector()
      .selectUngeocodedLimited(200);
    Test.stopTest();

    Set<Id> resultIds = new Map<Id, Travel_Activity__c>(result).keySet();
    Assert.isFalse(
      resultIds.contains(noAddressId),
      'Activity without address must be excluded'
    );
    Assert.areEqual(2, result.size());
  }

  @IsTest
  static void selectUnsummarized_returnsNonAiEnhancedActivities() {
    Test.setMock(HttpCalloutMock.class, new GeocodeCalloutMock.SuccessMock());
    List<Travel_Activity__c> eligible = insertEligibleActivities(3);

    Test.startTest();
    List<Travel_Activity__c> result = new TravelActivitySelector()
      .selectUnsummarizedActivitiesToProcess();
    Test.stopTest();

    Assert.areEqual(3, result.size());
    for (Travel_Activity__c act : result) {
      Assert.isFalse(act.Is_AI_Enhanced__c);
    }
  }

  @IsTest
  static void selectUnsummarized_excludesAiEnhancedActivities() {
    Test.setMock(HttpCalloutMock.class, new GeocodeCalloutMock.SuccessMock());
    insertEligibleActivities(2);
    Id aiEnhancedId = insertAiEnhancedActivity().Id;

    Test.startTest();
    List<Travel_Activity__c> result = new TravelActivitySelector()
      .selectUnsummarizedActivitiesToProcess();
    Test.stopTest();

    Set<Id> resultIds = new Map<Id, Travel_Activity__c>(result).keySet();
    Assert.isFalse(
      resultIds.contains(aiEnhancedId),
      'AI-enhanced activity must be excluded'
    );
    Assert.areEqual(2, result.size());
  }

  @IsTest
  static void selectByIds_returnsMatchingRecords() {
    Test.setMock(HttpCalloutMock.class, new GeocodeCalloutMock.SuccessMock());
    List<Travel_Activity__c> acts = insertEligibleActivities(3);
    Set<Id> requestedIds = new Set<Id>{ acts[0].Id, acts[1].Id };

    Test.startTest();
    List<Travel_Activity__c> result = new TravelActivitySelector()
      .selectByIds(requestedIds);
    Test.stopTest();

    Assert.areEqual(2, result.size());
    Assert.isTrue(
      new Map<Id, Travel_Activity__c>(result).keySet().containsAll(requestedIds)
    );
  }

  @IsTest
  static void selectByIds_emptySet_returnsEmpty() {
    Test.startTest();
    List<Travel_Activity__c> result = new TravelActivitySelector()
      .selectByIds(new Set<Id>());
    Test.stopTest();

    Assert.isTrue(result.isEmpty());
  }

  @IsTest
  static void selectByIds_unknownId_returnsEmpty() {
    Id fakeId = '001000000000001AAA';

    Test.startTest();
    List<Travel_Activity__c> result = new TravelActivitySelector()
      .selectByIds(new Set<Id>{ fakeId });
    Test.stopTest();

    Assert.isTrue(result.isEmpty());
  }

  @IsTest
  static void selectGeoTagRetryable_returnsDueAndUngeocodedActivities() {
    Test.setMock(HttpCalloutMock.class, new GeocodeCalloutMock.SuccessMock());
    Travel_Activity__c act = insertEligibleActivity('Retryable Activity');
    TestDataFactory.createPendingRetryLog(
      act.Id,
      IntegrationLogService.GEOCODE,
      true
    );

    Test.startTest();
    List<Travel_Activity__c> result = new TravelActivitySelector()
      .selectGeoTagRetryable();
    Test.stopTest();

    Assert.areEqual(1, result.size());
    Assert.areEqual(act.Id, result[0].Id);
  }

  @IsTest
  static void selectGeoTagRetryable_excludesGeoTaggedActivities() {
    Id geoTaggedId = insertGeoTaggedActivity().Id;
    TestDataFactory.createPendingRetryLog(
      geoTaggedId,
      IntegrationLogService.GEOCODE,
      true
    );

    Test.startTest();
    List<Travel_Activity__c> result = new TravelActivitySelector()
      .selectGeoTagRetryable();
    Test.stopTest();

    Assert.isTrue(
      result.isEmpty(),
      'GeoTagged activity must be excluded even with a retry log'
    );
  }

  @IsTest
  static void selectGeoTagRetryable_noLogs_returnsEmpty() {
    Test.setMock(HttpCalloutMock.class, new GeocodeCalloutMock.SuccessMock());
    insertEligibleActivity('No Log Activity');

    Test.startTest();
    List<Travel_Activity__c> result = new TravelActivitySelector()
      .selectGeoTagRetryable();
    Test.stopTest();

    Assert.isTrue(result.isEmpty(), 'No logs means no retryable candidates');
  }

  @IsTest
  static void selectGeoTagRetryable_futureNextRetry_notReturned() {
    Test.setMock(HttpCalloutMock.class, new GeocodeCalloutMock.SuccessMock());
    Travel_Activity__c act = insertEligibleActivity('Future Retry Activity');
    TestDataFactory.createIntegrationLog(
      act.Id,
      IntegrationLogService.GEOCODE,
      'Pending Retry',
      1,
      DateTime.now().addMinutes(60),
      true
    );

    Test.startTest();
    List<Travel_Activity__c> result = new TravelActivitySelector()
      .selectGeoTagRetryable();
    Test.stopTest();

    Assert.isTrue(result.isEmpty(), 'Future retry should not be returned');
  }

  @IsTest
  static void selectSummaryRetryable_returnsDueAndNonAiEnhancedActivities() {
    Test.setMock(HttpCalloutMock.class, new GeocodeCalloutMock.SuccessMock());
    Travel_Activity__c act = insertEligibleActivity('Mistral Retryable');
    TestDataFactory.createPendingRetryLog(
      act.Id,
      IntegrationLogService.MISTRAL,
      true
    );

    Test.startTest();
    List<Travel_Activity__c> result = new TravelActivitySelector()
      .selectSummaryRetryableActivities();
    Test.stopTest();

    Assert.areEqual(1, result.size());
    Assert.areEqual(act.Id, result[0].Id);
  }

  @IsTest
  static void selectSummaryRetryable_excludesAiEnhancedActivities() {
    Id aiEnhancedId = insertAiEnhancedActivity().Id;
    TestDataFactory.createPendingRetryLog(
      aiEnhancedId,
      IntegrationLogService.MISTRAL,
      true
    );

    Test.startTest();
    List<Travel_Activity__c> result = new TravelActivitySelector()
      .selectSummaryRetryableActivities();
    Test.stopTest();

    Assert.isTrue(
      result.isEmpty(),
      'AI-enhanced activity must be excluded even with a retry log'
    );
  }

  @IsTest
  static void selectSummaryRetryable_noLogsExist_returnsEmpty() {
    Test.setMock(HttpCalloutMock.class, new GeocodeCalloutMock.SuccessMock());
    insertEligibleActivity('No Mistral Log Activity');

    Test.startTest();
    List<Travel_Activity__c> result = new TravelActivitySelector()
      .selectSummaryRetryableActivities();
    Test.stopTest();

    Assert.isTrue(result.isEmpty(), 'No mistral logs means empty result');
  }

  @IsTest
  static void selectSummaryRetryable_futureNextRetry_notReturned() {
    Test.setMock(HttpCalloutMock.class, new GeocodeCalloutMock.SuccessMock());
    Travel_Activity__c act = insertEligibleActivity('Future Mistral Retry');
    TestDataFactory.createIntegrationLog(
      act.Id,
      IntegrationLogService.MISTRAL,
      'Pending Retry',
      1,
      DateTime.now().addMinutes(60),
      true
    );

    Test.startTest();
    List<Travel_Activity__c> result = new TravelActivitySelector()
      .selectSummaryRetryableActivities();
    Test.stopTest();

    Assert.isTrue(result.isEmpty(), 'Future retry should not be returned');
  }
}
