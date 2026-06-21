@IsTest
private class GeocodeActivityQueueableTest {
  // No @TestSetup — all data created inside test methods after mock is registered
  // to prevent the trigger from enqueuing GeocodeActivityQueueable before

  private static Travel_Activity__c insertEligibleActivity() {
    Travel_Activity__c act = new Travel_Activity__c(
      Name = 'Queueable Test Activity',
      Street__c = '1 Main St',
      City__c = 'Berlin',
      Country__c = 'Germany',
      Zip__c = '10115',
      Is_Geo_Tagged__c = false
    );
    insert act;
    return act;
  }

  private static Integration_Log__c getLatestLog(Id activityId) {
    List<Integration_Log__c> logs = [
      SELECT Id, Status__c, HTTP_Status__c, Retry_Count__c, Error_Message__c
      FROM Integration_Log__c
      WHERE Record_Id__c = :activityId
      ORDER BY CreatedDate DESC
      LIMIT 1
    ];
    return logs.isEmpty() ? null : logs[0];
  }

  @IsTest
  static void execute_200Success_tagsActivityAndLogsSuccess() {
    Test.setMock(
      HttpCalloutMock.class,
      new GeocodeCalloutMock.SuccessMock(48.13, 11.58)
    );

    Travel_Activity__c act = insertEligibleActivity();

    Test.startTest();
    System.enqueueJob(new GeocodeActivityQueueable(new Set<Id>{ act.Id }));
    Test.stopTest();

    Travel_Activity__c updated = [
      SELECT Is_Geo_Tagged__c, Location__Latitude__s, Location__Longitude__s
      FROM Travel_Activity__c
      WHERE Id = :act.Id
    ];
    Assert.isTrue(updated.Is_Geo_Tagged__c, 'Activity should be geo-tagged');
    Assert.areEqual(
      48.13,
      updated.Location__Latitude__s,
      'Latitude should match mock'
    );
    Assert.areEqual(
      11.58,
      updated.Location__Longitude__s,
      'Longitude should match mock'
    );

    Integration_Log__c log = getLatestLog(act.Id);
    Assert.areEqual('Success', log.Status__c);
    Assert.areEqual(200, (Integer) log.HTTP_Status__c);
    Assert.areEqual(0, (Integer) log.Retry_Count__c);
  }

  @IsTest
  static void execute_500Response_leavesRecordUntaggedAndLogsPendingRetry() {
    Test.setMock(
      HttpCalloutMock.class,
      new GeocodeCalloutMock.ServerErrorMock()
    );

    Travel_Activity__c act = insertEligibleActivity();

    Test.startTest();
    System.enqueueJob(new GeocodeActivityQueueable(new Set<Id>{ act.Id }));
    Test.stopTest();

    Assert.isFalse(
      [SELECT Is_Geo_Tagged__c FROM Travel_Activity__c WHERE Id = :act.Id]
      .Is_Geo_Tagged__c,
      'Record must not be tagged on 500'
    );

    Integration_Log__c log = getLatestLog(act.Id);
    Assert.areEqual('Pending Retry', log.Status__c);
    Assert.areEqual(500, (Integer) log.HTTP_Status__c);
    Assert.areEqual(1, (Integer) log.Retry_Count__c);
  }

  @IsTest
  static void execute_401Response_logsFailedNoRetry() {
    Test.setMock(
      HttpCalloutMock.class,
      new GeocodeCalloutMock.UnauthorizedMock()
    );

    Travel_Activity__c act = insertEligibleActivity();

    Test.startTest();
    System.enqueueJob(new GeocodeActivityQueueable(new Set<Id>{ act.Id }));
    Test.stopTest();

    Integration_Log__c log = getLatestLog(act.Id);
    Assert.areEqual('Failed No Retry', log.Status__c);
    Assert.areEqual(401, (Integer) log.HTTP_Status__c);
  }

  @IsTest
  static void execute_calloutException_logsPendingRetryWithStatus0() {
    Test.setMock(
      HttpCalloutMock.class,
      new GeocodeCalloutMock.CalloutExceptionMock()
    );

    Travel_Activity__c act = insertEligibleActivity();

    Test.startTest();
    System.enqueueJob(new GeocodeActivityQueueable(new Set<Id>{ act.Id }));
    Test.stopTest();

    Assert.isFalse(
      [SELECT Is_Geo_Tagged__c FROM Travel_Activity__c WHERE Id = :act.Id]
      .Is_Geo_Tagged__c
    );

    Integration_Log__c log = getLatestLog(act.Id);
    Assert.areEqual('Pending Retry', log.Status__c);
    Assert.areEqual(0, (Integer) log.HTTP_Status__c);
    Assert.isTrue(log.Error_Message__c.containsIgnoreCase('Callout exception'));
  }

  @IsTest
  static void execute_zeroResults_logsFailedNoRetry422() {
    Test.setMock(
      HttpCalloutMock.class,
      new GeocodeCalloutMock.ZeroResultsMock()
    );

    Travel_Activity__c act = insertEligibleActivity();

    Test.startTest();
    System.enqueueJob(new GeocodeActivityQueueable(new Set<Id>{ act.Id }));
    Test.stopTest();

    Integration_Log__c log = getLatestLog(act.Id);
    Assert.areEqual('Failed No Retry', log.Status__c);
    Assert.areEqual(422, (Integer) log.HTTP_Status__c);
  }

  @IsTest
  static void singleRecordThreshold_isOne() {
    Assert.areEqual(1, GeocodeActivityQueueable.SINGLE_RECORD_THRESHOLD);
  }

  @IsTest
  static void execute_400Response_logsFailedNoRetry() {
    Test.setMock(
      HttpCalloutMock.class,
      new GeocodeCalloutMock.BadRequestMock()
    );

    Travel_Activity__c act = insertEligibleActivity();

    Test.startTest();
    System.enqueueJob(new GeocodeActivityQueueable(new Set<Id>{ act.Id }));
    Test.stopTest();

    Integration_Log__c log = getLatestLog(act.Id);
    Assert.areEqual('Failed No Retry', log.Status__c);
    Assert.areEqual(400, (Integer) log.HTTP_Status__c);
  }

  @IsTest
  static void execute_403Response_logsFailedNoRetry() {
    Test.setMock(HttpCalloutMock.class, new GeocodeCalloutMock.ForbiddenMock());

    Travel_Activity__c act = insertEligibleActivity();

    Test.startTest();
    System.enqueueJob(new GeocodeActivityQueueable(new Set<Id>{ act.Id }));
    Test.stopTest();

    Integration_Log__c log = getLatestLog(act.Id);
    Assert.areEqual('Failed No Retry', log.Status__c);
    Assert.areEqual(403, (Integer) log.HTTP_Status__c);
  }

  @IsTest
  static void execute_422Response_logsFailedNoRetry() {
    Test.setMock(
      HttpCalloutMock.class,
      new GeocodeCalloutMock.UnprocessableMock()
    );

    Travel_Activity__c act = insertEligibleActivity();

    Test.startTest();
    System.enqueueJob(new GeocodeActivityQueueable(new Set<Id>{ act.Id }));
    Test.stopTest();

    Integration_Log__c log = getLatestLog(act.Id);
    Assert.areEqual('Failed No Retry', log.Status__c);
    Assert.areEqual(422, (Integer) log.HTTP_Status__c);
  }

  @IsTest
  static void execute_429Response_logsPendingRetry() {
    Test.setMock(
      HttpCalloutMock.class,
      new GeocodeCalloutMock.RateLimitedMock()
    );

    Travel_Activity__c act = insertEligibleActivity();

    Test.startTest();
    System.enqueueJob(new GeocodeActivityQueueable(new Set<Id>{ act.Id }));
    Test.stopTest();

    Integration_Log__c log = getLatestLog(act.Id);
    Assert.areEqual('Pending Retry', log.Status__c);
    Assert.areEqual(429, (Integer) log.HTTP_Status__c);
    Assert.areEqual(1, (Integer) log.Retry_Count__c);
  }
}
