@IsTest
private class IntegrationLogServiceTest {
  private static Travel_Activity__c insertActivity() {
    Travel_Activity__c act = new Travel_Activity__c(
      Name = 'Log Test Activity',
      Street__c = '1 Main St',
      City__c = 'Berlin',
      Country__c = 'Germany',
      Zip__c = '10115',
      Is_Geo_Tagged__c = true
    );
    insert act;
    return act;
  }

  private static List<Travel_Activity__c> insertActivities(Integer count) {
    List<Travel_Activity__c> acts = new List<Travel_Activity__c>();
    for (Integer i = 0; i < count; i++) {
      acts.add(
        new Travel_Activity__c(
          Name = 'Log Test Activity ' + i,
          Street__c = i + ' Main St',
          City__c = 'Berlin',
          Country__c = 'Germany',
          Zip__c = '1000' + i,
          Is_Geo_Tagged__c = true
        )
      );
    }
    insert acts;
    return acts;
  }

  private static Integration_Log__c getLatestLog(Id activityId) {
    List<Integration_Log__c> logs = [
      SELECT
        Id,
        Status__c,
        Retry_Count__c,
        Next_Retry__c,
        Error_Message__c,
        HTTP_Status__c,
        Operation__c
      FROM Integration_Log__c
      WHERE Record_Id__c = :activityId
      ORDER BY CreatedDate DESC
      LIMIT 1
    ];
    return logs.isEmpty() ? null : logs[0];
  }

  private static Integration_Log__c getNewLog(Id activityId, Id excludeLogId) {
    List<Integration_Log__c> logs = [
      SELECT
        Id,
        Status__c,
        Retry_Count__c,
        Next_Retry__c,
        Error_Message__c,
        HTTP_Status__c,
        Operation__c
      FROM Integration_Log__c
      WHERE Record_Id__c = :activityId AND Id != :excludeLogId
      ORDER BY CreatedDate DESC
      LIMIT 1
    ];
    return logs.isEmpty() ? null : logs[0];
  }

  @IsTest
  static void geocode_success_insertsSuccessLog() {
    Travel_Activity__c act = insertActivity();

    Test.startTest();
    new IntegrationLogService()
      .logResults(
        new List<GeocodeDTO.GeocodeResult>{
          TestDataFactory.buildGeocodeSuccess(act.Id)
        }
      );
    Test.stopTest();

    Integration_Log__c log = getLatestLog(act.Id);
    Assert.areEqual('Success', log.Status__c);
    Assert.areEqual(IntegrationLogService.GEOCODE, log.Operation__c);
    Assert.areEqual(0, (Integer) log.Retry_Count__c);
    Assert.areEqual(200, (Integer) log.HTTP_Status__c);
    Assert.isNull(log.Next_Retry__c);
    Assert.isNull(log.Error_Message__c);
  }

  @IsTest
  static void geocode_failure_400_insertsFailedNoRetry() {
    Travel_Activity__c act = insertActivity();

    Test.startTest();
    new IntegrationLogService()
      .logResults(
        new List<GeocodeDTO.GeocodeResult>{
          TestDataFactory.buildGeocodeFailure(act.Id, 400, 'Bad request')
        }
      );
    Test.stopTest();

    Integration_Log__c log = getLatestLog(act.Id);
    Assert.areEqual('Failed No Retry', log.Status__c);
    Assert.areEqual('Bad request', log.Error_Message__c);
    Assert.areEqual(0, (Integer) log.Retry_Count__c);
    Assert.isNull(log.Next_Retry__c);
  }

  @IsTest
  static void geocode_failure_401_insertsFailedNoRetry() {
    Travel_Activity__c act = insertActivity();

    Test.startTest();
    new IntegrationLogService()
      .logResults(
        new List<GeocodeDTO.GeocodeResult>{
          TestDataFactory.buildGeocodeFailure(act.Id, 401, 'Unauthorized')
        }
      );
    Test.stopTest();

    Assert.areEqual('Failed No Retry', getLatestLog(act.Id).Status__c);
  }

  @IsTest
  static void geocode_failure_403_insertsFailedNoRetry() {
    Travel_Activity__c act = insertActivity();

    Test.startTest();
    new IntegrationLogService()
      .logResults(
        new List<GeocodeDTO.GeocodeResult>{
          TestDataFactory.buildGeocodeFailure(act.Id, 403, 'Forbidden')
        }
      );
    Test.stopTest();

    Assert.areEqual('Failed No Retry', getLatestLog(act.Id).Status__c);
  }

  @IsTest
  static void geocode_failure_422_insertsFailedNoRetry() {
    Travel_Activity__c act = insertActivity();

    Test.startTest();
    new IntegrationLogService()
      .logResults(
        new List<GeocodeDTO.GeocodeResult>{
          TestDataFactory.buildGeocodeFailure(act.Id, 422, 'Unprocessable')
        }
      );
    Test.stopTest();

    Assert.areEqual('Failed No Retry', getLatestLog(act.Id).Status__c);
  }

  @IsTest
  static void geocode_transientFailure_firstAttempt_insertsPendingRetry() {
    Travel_Activity__c act = insertActivity();

    Test.startTest();
    new IntegrationLogService()
      .logResults(
        new List<GeocodeDTO.GeocodeResult>{
          TestDataFactory.buildGeocodeFailure(act.Id, 500, 'Server error')
        }
      );
    Test.stopTest();

    Integration_Log__c log = getLatestLog(act.Id);
    Assert.areEqual('Pending Retry', log.Status__c);
    Assert.areEqual(1, (Integer) log.Retry_Count__c);
    Assert.isNotNull(log.Next_Retry__c);
    Assert.isTrue(log.Next_Retry__c > DateTime.now());
  }

  @IsTest
  static void geocode_nullHttpStatus_treatedAsRetryable() {
    Travel_Activity__c act = insertActivity();

    Test.startTest();
    new IntegrationLogService()
      .logResults(
        new List<GeocodeDTO.GeocodeResult>{
          TestDataFactory.buildGeocodeFailure(act.Id, null, 'Unknown error')
        }
      );
    Test.stopTest();

    Assert.areEqual('Pending Retry', getLatestLog(act.Id).Status__c);
  }

  @IsTest
  static void geocode_maxRetriesExhausted_insertsFailedMaxRetries() {
    Travel_Activity__c act = insertActivity();

    Integration_Log__c existing = TestDataFactory.createIntegrationLog(
      act.Id,
      IntegrationLogService.GEOCODE,
      'Pending Retry',
      IntegrationLogService.MAX_RETRIES,
      DateTime.now().addMinutes(-5),
      true
    );

    Test.startTest();
    new IntegrationLogService()
      .logResults(
        new List<GeocodeDTO.GeocodeResult>{
          TestDataFactory.buildGeocodeFailure(act.Id, 500, 'Still failing')
        },
        new Map<Id, Integration_Log__c>{ act.Id => existing }
      );
    Test.stopTest();

    Integration_Log__c log = getNewLog(act.Id, existing.Id);
    Assert.areEqual('Failed Max Retries', log.Status__c);
    Assert.areEqual(
      IntegrationLogService.MAX_RETRIES,
      (Integer) log.Retry_Count__c
    );
    Assert.isNull(log.Next_Retry__c);
  }

  @IsTest
  static void geocode_backoff_increasesWithRetryCount() {
    List<Travel_Activity__c> acts = insertActivities(2);

    Integration_Log__c log0 = TestDataFactory.createIntegrationLog(
      acts[0].Id,
      IntegrationLogService.GEOCODE,
      'Pending Retry',
      0,
      DateTime.now().addMinutes(-5),
      true
    );
    Integration_Log__c log1 = TestDataFactory.createIntegrationLog(
      acts[1].Id,
      IntegrationLogService.GEOCODE,
      'Pending Retry',
      1,
      DateTime.now().addMinutes(-15),
      true
    );

    DateTime before = DateTime.now();

    Test.startTest();
    new IntegrationLogService()
      .logResults(
        new List<GeocodeDTO.GeocodeResult>{
          TestDataFactory.buildGeocodeFailure(acts[0].Id, 500, 'Err'),
          TestDataFactory.buildGeocodeFailure(acts[1].Id, 500, 'Err')
        },
        new Map<Id, Integration_Log__c>{
          acts[0].Id => log0,
          acts[1].Id => log1
        }
      );
    Test.stopTest();

    Integration_Log__c newest0 = getNewLog(acts[0].Id, log0.Id);
    Integration_Log__c newest1 = getNewLog(acts[1].Id, log1.Id);

    Assert.isTrue(
      newest0.Next_Retry__c >= before.addMinutes(4),
      'Retry 1 should be ~5 min out'
    );
    Assert.isTrue(
      newest1.Next_Retry__c >= before.addMinutes(14),
      'Retry 2 should be ~15 min out'
    );
    Assert.isTrue(
      newest1.Next_Retry__c > newest0.Next_Retry__c,
      'Later retry has longer backoff'
    );
  }

  @IsTest
  static void geocode_bulkResults_allLogged() {
    List<Travel_Activity__c> acts = insertActivities(3);

    Test.startTest();
    new IntegrationLogService()
      .logResults(
        new List<GeocodeDTO.GeocodeResult>{
          TestDataFactory.buildGeocodeSuccess(acts[0].Id),
          TestDataFactory.buildGeocodeFailure(acts[1].Id, 503, 'Timeout'),
          TestDataFactory.buildGeocodeFailure(acts[2].Id, 400, 'Bad request')
        }
      );
    Test.stopTest();

    Assert.areEqual('Success', getLatestLog(acts[0].Id).Status__c);
    Assert.areEqual('Pending Retry', getLatestLog(acts[1].Id).Status__c);
    Assert.areEqual('Failed No Retry', getLatestLog(acts[2].Id).Status__c);
  }

  @IsTest
  static void geocode_emptyList_noLogsInserted() {
    Test.startTest();
    new IntegrationLogService()
      .logResults(new List<GeocodeDTO.GeocodeResult>());
    Test.stopTest();

    Assert.areEqual(0, [SELECT COUNT() FROM Integration_Log__c]);
  }

  @IsTest
  static void mistral_success_insertsSuccessLog() {
    Travel_Activity__c act = insertActivity();

    Test.startTest();
    new IntegrationLogService()
      .logResults(
        new List<MistralDTO.MistralResult>{
          TestDataFactory.buildMistralSuccess(act.Id)
        }
      );
    Test.stopTest();

    Integration_Log__c log = getLatestLog(act.Id);
    Assert.areEqual('Success', log.Status__c);
    Assert.areEqual(IntegrationLogService.MISTRAL, log.Operation__c);
    Assert.areEqual(0, (Integer) log.Retry_Count__c);
    Assert.areEqual(200, (Integer) log.HTTP_Status__c);
    Assert.isNull(log.Next_Retry__c);
    Assert.isNull(log.Error_Message__c);
  }

  @IsTest
  static void mistral_failure_401_insertsFailedNoRetry() {
    Travel_Activity__c act = insertActivity();

    Test.startTest();
    new IntegrationLogService()
      .logResults(
        new List<MistralDTO.MistralResult>{
          TestDataFactory.buildMistralFailure(act.Id, 401, 'Unauthorized')
        }
      );
    Test.stopTest();

    Integration_Log__c log = getLatestLog(act.Id);
    Assert.areEqual('Failed No Retry', log.Status__c);
    Assert.areEqual('Unauthorized', log.Error_Message__c);
    Assert.areEqual(0, (Integer) log.Retry_Count__c);
    Assert.isNull(log.Next_Retry__c);
  }

  @IsTest
  static void mistral_failure_500_insertsPendingRetry() {
    Travel_Activity__c act = insertActivity();

    Test.startTest();
    new IntegrationLogService()
      .logResults(
        new List<MistralDTO.MistralResult>{
          TestDataFactory.buildMistralFailure(act.Id, 500, 'Server error')
        }
      );
    Test.stopTest();

    Integration_Log__c log = getLatestLog(act.Id);
    Assert.areEqual('Pending Retry', log.Status__c);
    Assert.areEqual(1, (Integer) log.Retry_Count__c);
    Assert.isNotNull(log.Next_Retry__c);
    Assert.isTrue(log.Next_Retry__c > DateTime.now());
  }

  @IsTest
  static void mistral_failure_maxRetriesExhausted_insertsFailedMaxRetries() {
    Travel_Activity__c act = insertActivity();

    Integration_Log__c existing = TestDataFactory.createIntegrationLog(
      act.Id,
      IntegrationLogService.MISTRAL,
      'Pending Retry',
      IntegrationLogService.MAX_RETRIES,
      DateTime.now().addMinutes(-5),
      true
    );

    Test.startTest();
    new IntegrationLogService()
      .logResults(
        new List<MistralDTO.MistralResult>{
          TestDataFactory.buildMistralFailure(act.Id, 500, 'Still failing')
        },
        new Map<Id, Integration_Log__c>{ act.Id => existing }
      );
    Test.stopTest();

    Integration_Log__c log = getNewLog(act.Id, existing.Id);
    Assert.areEqual('Failed Max Retries', log.Status__c);
    Assert.areEqual(
      IntegrationLogService.MAX_RETRIES,
      (Integer) log.Retry_Count__c
    );
    Assert.isNull(log.Next_Retry__c);
  }

  @IsTest
  static void mistral_failure_429_insertsPendingRetry() {
    Travel_Activity__c act = insertActivity();

    Test.startTest();
    new IntegrationLogService()
      .logResults(
        new List<MistralDTO.MistralResult>{
          TestDataFactory.buildMistralFailure(act.Id, 429, 'Rate limited')
        }
      );
    Test.stopTest();

    Assert.areEqual('Pending Retry', getLatestLog(act.Id).Status__c);
  }

  @IsTest
  static void mistral_bulkResults_allLogged() {
    List<Travel_Activity__c> acts = insertActivities(3);

    Test.startTest();
    new IntegrationLogService()
      .logResults(
        new List<MistralDTO.MistralResult>{
          TestDataFactory.buildMistralSuccess(acts[0].Id),
          TestDataFactory.buildMistralFailure(acts[1].Id, 500, 'Timeout'),
          TestDataFactory.buildMistralFailure(acts[2].Id, 401, 'Unauthorized')
        }
      );
    Test.stopTest();

    Assert.areEqual('Success', getLatestLog(acts[0].Id).Status__c);
    Assert.areEqual('Pending Retry', getLatestLog(acts[1].Id).Status__c);
    Assert.areEqual('Failed No Retry', getLatestLog(acts[2].Id).Status__c);
  }

  @IsTest
  static void mistral_emptyList_noLogsInserted() {
    Test.startTest();
    new IntegrationLogService()
      .logResults(new List<MistralDTO.MistralResult>());
    Test.stopTest();

    Assert.areEqual(0, [SELECT COUNT() FROM Integration_Log__c]);
  }
}
