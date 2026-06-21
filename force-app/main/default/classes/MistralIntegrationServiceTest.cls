@IsTest
private class MistralIntegrationServiceTest {
  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  private static Travel_Activity__c insertActivity(String name) {
    Travel_Activity__c act = new Travel_Activity__c(
      Name = name,
      City__c = 'Berlin',
      Country__c = 'Germany',
      SupplierNotes__c = 'Great tour of the city centre.',
      Is_Geo_Tagged__c = true,
      Is_AI_Enhanced__c = false
    );
    insert act;
    return act;
  }

  private static List<Travel_Activity__c> insertActivities(Integer count) {
    List<Travel_Activity__c> acts = new List<Travel_Activity__c>();
    for (Integer i = 0; i < count; i++) {
      acts.add(
        new Travel_Activity__c(
          Name = 'Mistral Activity ' + i,
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

  private static Travel_Activity__c getActivity(Id actId) {
    return [
      SELECT
        Id,
        Is_AI_Enhanced__c,
        Category__c,
        Duration__c,
        Languages__c,
        Accessibility__c,
        Good_For__c,
        Listing_Summary__c
      FROM Travel_Activity__c
      WHERE Id = :actId
    ];
  }

  private static Integration_Log__c getLatestLog(Id activityId) {
    List<Integration_Log__c> logs = [
      SELECT
        Id,
        Status__c,
        HTTP_Status__c,
        Retry_Count__c,
        Next_Retry__c,
        Error_Message__c,
        Operation__c
      FROM Integration_Log__c
      WHERE Record_Id__c = :activityId
      ORDER BY CreatedDate DESC
      LIMIT 1
    ];
    return logs.isEmpty() ? null : logs[0];
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

  private static MistralDTO.MistralResult buildSuccessResult(Id recordId) {
    MistralDTO.ActivityResponse data = new MistralDTO.ActivityResponse();
    data.Id = 1;
    data.Category = 'Sightseeing';
    data.Duration = '120 minutes';
    data.Languages = 'English,German';
    data.Accessibility = 'Yes';
    data.Good_For = 'Families,Couples';
    data.Listing_Summary = 'A wonderful experience in the heart of the city.';
    return new MistralDTO.MistralResult(recordId, data);
  }

  private static MistralDTO.MistralResult buildFailureResult(
    Id recordId,
    Integer statusCode,
    String errorMsg
  ) {
    return new MistralDTO.MistralResult(recordId, errorMsg, statusCode);
  }

  @IsTest
  static void processActivities_200_returnsSuccessResults() {
    Test.setMock(
      HttpCalloutMock.class,
      new MistralCalloutMock.BatchSuccessMock(1)
    );
    List<Travel_Activity__c> acts = insertActivities(1);

    Test.startTest();
    List<MistralDTO.MistralResult> results = buildMistralService()
      .processActivities(acts);
    Test.stopTest();

    Assert.areEqual(1, results.size());
    Assert.isTrue(results[0].success);
    Assert.areEqual(200, results[0].statusCode);
    Assert.areEqual(acts[0].Id, results[0].recordId);
    Assert.isNotNull(results[0].data);
    Assert.areEqual('Sightseeing', results[0].data.Category);
  }

  @IsTest
  static void processActivities_emptyList_returnsEmpty() {
    Test.startTest();
    List<MistralDTO.MistralResult> results = buildMistralService()
      .processActivities(new List<Travel_Activity__c>());
    Test.stopTest();

    Assert.isTrue(results.isEmpty());
  }

  @IsTest
  static void processActivities_401_returnsFailurePerActivity() {
    Test.setMock(
      HttpCalloutMock.class,
      new MistralCalloutMock.UnauthorizedMock()
    );
    List<Travel_Activity__c> acts = insertActivities(2);

    Test.startTest();
    List<MistralDTO.MistralResult> results = buildMistralService()
      .processActivities(acts);
    Test.stopTest();

    Assert.areEqual(2, results.size());
    for (MistralDTO.MistralResult r : results) {
      Assert.isFalse(r.success);
      Assert.areEqual(401, r.statusCode);
      Assert.isTrue(r.errorMessage.contains('401'));
    }
  }

  @IsTest
  static void processActivities_500_returnsFailurePerActivity() {
    Test.setMock(
      HttpCalloutMock.class,
      new MistralCalloutMock.ServerErrorMock()
    );
    List<Travel_Activity__c> acts = insertActivities(2);

    Test.startTest();
    List<MistralDTO.MistralResult> results = buildMistralService()
      .processActivities(acts);
    Test.stopTest();

    Assert.areEqual(2, results.size());
    for (MistralDTO.MistralResult r : results) {
      Assert.isFalse(r.success);
      Assert.areEqual(500, r.statusCode);
    }
  }

  @IsTest
  static void processActivities_emptyChoices_returnsFailurePerActivity() {
    Test.setMock(
      HttpCalloutMock.class,
      new MistralCalloutMock.EmptyChoicesMock()
    );
    List<Travel_Activity__c> acts = insertActivities(1);

    Test.startTest();
    List<MistralDTO.MistralResult> results = buildMistralService()
      .processActivities(acts);
    Test.stopTest();

    Assert.areEqual(1, results.size());
    Assert.isFalse(results[0].success);
    Assert.isTrue(results[0].errorMessage.containsIgnoreCase('No choices'));
  }

  @IsTest
  static void processActivities_malformedContent_returnsFailurePerActivity() {
    Test.setMock(
      HttpCalloutMock.class,
      new MistralCalloutMock.MalformedContentMock()
    );
    List<Travel_Activity__c> acts = insertActivities(1);

    Test.startTest();
    List<MistralDTO.MistralResult> results = buildMistralService()
      .processActivities(acts);
    Test.stopTest();

    Assert.areEqual(1, results.size());
    Assert.isFalse(results[0].success);
  }

  @IsTest
  static void processActivities_countMismatch_returnsFailurePerActivity() {
    Test.setMock(
      HttpCalloutMock.class,
      new MistralCalloutMock.CountMismatchMock()
    );
    List<Travel_Activity__c> acts = insertActivities(2);

    Test.startTest();
    List<MistralDTO.MistralResult> results = buildMistralService()
      .processActivities(acts);
    Test.stopTest();

    Assert.areEqual(2, results.size());
    for (MistralDTO.MistralResult r : results) {
      Assert.isFalse(r.success);
      Assert.isTrue(r.errorMessage.containsIgnoreCase('Expected'));
    }
  }

  @IsTest
  static void processActivities_outboundRequest_isPostWithAuthHeader() {
    List<Travel_Activity__c> acts = insertActivities(1);
    MistralCalloutMock.RequestCaptureMock captureMock = new MistralCalloutMock.RequestCaptureMock(
      1
    );

    Test.setMock(HttpCalloutMock.class, captureMock);

    Test.startTest();
    buildMistralService().processActivities(acts);
    Test.stopTest();

    Assert.isNotNull(captureMock.capturedRequest);
    Assert.areEqual('POST', captureMock.capturedRequest.getMethod());
    Assert.isTrue(
      captureMock.capturedRequest.getHeader('Authorization')
        .startsWith('Bearer '),
      'Authorization header should be a Bearer token'
    );
    Assert.areEqual(
      'application/json',
      captureMock.capturedRequest.getHeader('Content-Type')
    );
  }

  @IsTest
  static void updateActivities_successResult_updatesRecordAndLogsSuccess() {
    Travel_Activity__c act = insertActivity('Update Test Activity');

    Test.startTest();
    buildMistralService()
      .updateActivities(
        new List<MistralDTO.MistralResult>{ buildSuccessResult(act.Id) }
      );
    Test.stopTest();

    Travel_Activity__c updated = getActivity(act.Id);
    Assert.isTrue(
      updated.Is_AI_Enhanced__c,
      'Is_AI_Enhanced__c should be true'
    );
    Assert.areEqual('Sightseeing', updated.Category__c);
    Assert.areEqual('120 minutes', updated.Duration__c);
    Assert.isNotNull(updated.Languages__c);
    Assert.isNotNull(updated.Listing_Summary__c);

    Integration_Log__c log = getLatestLog(act.Id);
    Assert.areEqual('Success', log.Status__c);
    Assert.areEqual(IntegrationLogService.MISTRAL, log.Operation__c);
  }

  @IsTest
  static void updateActivities_500Result_doesNotUpdateRecordAndLogsPendingRetry() {
    Travel_Activity__c act = insertActivity('Fail Update Activity');

    Test.startTest();
    buildMistralService()
      .updateActivities(
        new List<MistralDTO.MistralResult>{
          buildFailureResult(act.Id, 500, 'Server error')
        }
      );
    Test.stopTest();

    Assert.isFalse(
      getActivity(act.Id).Is_AI_Enhanced__c,
      'Record must not be updated on failure'
    );

    Integration_Log__c log = getLatestLog(act.Id);
    Assert.areEqual('Pending Retry', log.Status__c);
    Assert.areEqual(500, (Integer) log.HTTP_Status__c);
  }

  @IsTest
  static void updateActivities_401Result_logsFailedNoRetry() {
    Travel_Activity__c act = insertActivity('Auth Fail Activity');

    Test.startTest();
    buildMistralService()
      .updateActivities(
        new List<MistralDTO.MistralResult>{
          buildFailureResult(act.Id, 401, 'Unauthorized')
        }
      );
    Test.stopTest();

    Integration_Log__c log = getLatestLog(act.Id);
    Assert.areEqual('Failed No Retry', log.Status__c);
    Assert.areEqual(401, (Integer) log.HTTP_Status__c);
  }

  @IsTest
  static void updateActivities_emptyList_isNoOp() {
    Test.startTest();
    buildMistralService()
      .updateActivities(new List<MistralDTO.MistralResult>());
    Test.stopTest();

    Assert.areEqual(0, [SELECT COUNT() FROM Integration_Log__c]);
  }

  @IsTest
  static void updateActivities_goodFor_commaReplacedWithSemicolon() {
    Travel_Activity__c act = insertActivity('GoodFor Test Activity');

    Test.startTest();
    buildMistralService()
      .updateActivities(
        new List<MistralDTO.MistralResult>{ buildSuccessResult(act.Id) }
      );
    Test.stopTest();

    Travel_Activity__c updated = getActivity(act.Id);
    if (updated.Good_For__c != null) {
      Assert.isFalse(
        updated.Good_For__c.contains(','),
        'Good_For__c should use semicolons not commas'
      );
      Assert.isTrue(
        updated.Good_For__c.contains(';'),
        'Good_For__c should contain semicolons as separator'
      );
    }
  }

  @IsTest
  static void processActivities_429_returnsRetryableFailurePerActivity() {
    Test.setMock(
      HttpCalloutMock.class,
      new MistralCalloutMock.RateLimitedMock()
    );
    List<Travel_Activity__c> acts = insertActivities(2);

    Test.startTest();
    List<MistralDTO.MistralResult> results = buildMistralService()
      .processActivities(acts);
    Test.stopTest();

    Assert.areEqual(2, results.size());
    for (MistralDTO.MistralResult r : results) {
      Assert.isFalse(r.success);
      Assert.areEqual(429, r.statusCode);
      Assert.isTrue(r.errorMessage.contains('429'));
    }
  }

  @IsTest
  static void processActivities_calloutException() {
    Test.setMock(
      HttpCalloutMock.class,
      new MistralCalloutMock.CalloutExceptionMock()
    );
    List<Travel_Activity__c> acts = insertActivities(2);

    Boolean threw = false;
    Test.startTest();
    try {
      buildMistralService().processActivities(acts);
    } catch (CalloutException e) {
      threw = true;
      Assert.isTrue(e.getMessage().containsIgnoreCase('Read timed out'));
    }
    Test.stopTest();

    Assert.isTrue(
      threw,
      'CalloutException should propagate from processActivities'
    );
  }

  @IsTest
  static void updateActivities_429Result_logsPendingRetry() {
    Travel_Activity__c act = insertActivity('Rate Limited Activity');

    Test.startTest();
    buildMistralService()
      .updateActivities(
        new List<MistralDTO.MistralResult>{
          buildFailureResult(act.Id, 429, 'Rate limit exceeded')
        }
      );
    Test.stopTest();

    Integration_Log__c log = getLatestLog(act.Id);
    Assert.areEqual('Pending Retry', log.Status__c);
    Assert.areEqual(429, (Integer) log.HTTP_Status__c);
    Assert.areEqual(1, (Integer) log.Retry_Count__c);
  }

  @IsTest
  static void updateActivities_status0Result_logsPendingRetry() {
    Travel_Activity__c act = insertActivity('Timeout Activity');

    Test.startTest();
    buildMistralService()
      .updateActivities(
        new List<MistralDTO.MistralResult>{
          buildFailureResult(act.Id, 0, 'Callout exception: Read timed out')
        }
      );
    Test.stopTest();

    Integration_Log__c log = getLatestLog(act.Id);
    Assert.areEqual('Pending Retry', log.Status__c);
    Assert.areEqual(0, (Integer) log.HTTP_Status__c);
    Assert.isFalse(getActivity(act.Id).Is_AI_Enhanced__c);
  }
}
