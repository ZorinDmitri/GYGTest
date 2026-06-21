@IsTest
public class TestDataFactory {
  public static List<Travel_Activity__c> createActivities(
    Integer count,
    Boolean doInsert
  ) {
    List<Travel_Activity__c> activities = new List<Travel_Activity__c>();
    for (Integer i = 0; i < count; i++) {
      activities.add(
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
    if (doInsert)
      insert activities;
    return activities;
  }

  public static Travel_Activity__c createActivity(Boolean doInsert) {
    return createActivities(1, doInsert)[0];
  }

  public static Travel_Activity__c createGeoTaggedActivity(Boolean doInsert) {
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
    if (doInsert)
      insert act;
    return act;
  }

  public static Travel_Activity__c createActivityWithoutAddress(
    Boolean doInsert
  ) {
    Travel_Activity__c act = new Travel_Activity__c(
      Name = 'No Address Activity',
      Is_Geo_Tagged__c = false,
      Is_AI_Enhanced__c = false
    );
    if (doInsert)
      insert act;
    return act;
  }

  public static Travel_Activity__c createAiEnhancedActivity(Boolean doInsert) {
    Travel_Activity__c act = new Travel_Activity__c(
      Name = 'AI Enhanced Activity',
      Street__c = '5 Smart St',
      City__c = 'Hamburg',
      Country__c = 'Germany',
      Zip__c = '20095',
      Is_Geo_Tagged__c = false,
      Is_AI_Enhanced__c = true,
      SupplierNotes__c = 'Some notes'
    );
    if (doInsert)
      insert act;
    return act;
  }

  public static Integration_Log__c createIntegrationLog(
    Id recordId,
    String operation,
    String status,
    Integer retryCount,
    DateTime nextRetry,
    Boolean doInsert
  ) {
    Integration_Log__c log = new Integration_Log__c(
      Record_Id__c = recordId,
      Operation__c = operation,
      Status__c = status,
      Retry_Count__c = retryCount,
      Next_Retry__c = nextRetry,
      HTTP_Status__c = 500
    );
    if (doInsert)
      insert log;
    return log;
  }

  public static Integration_Log__c createPendingRetryLog(
    Id recordId,
    String operation,
    Boolean doInsert
  ) {
    return createIntegrationLog(
      recordId,
      operation,
      'Pending Retry',
      1,
      DateTime.now().addMinutes(-1),
      doInsert
    );
  }

  public static GeocodeDTO.GeocodeResult buildGeocodeSuccess(Id activityId) {
    return new GeocodeDTO.GeocodeResult(activityId, 52.52, 13.40, 200);
  }

  public static GeocodeDTO.GeocodeResult buildGeocodeFailure(
    Id activityId,
    Integer httpStatus,
    String error
  ) {
    return new GeocodeDTO.GeocodeResult(activityId, error, httpStatus);
  }

  public static MistralDTO.MistralResult buildMistralSuccess(Id recordId) {
    MistralDTO.MistralResult r = new MistralDTO.MistralResult(
      recordId,
      new MistralDTO.ActivityResponse()
    );
    r.statusCode = 200;
    r.success = true;
    return r;
  }

  public static MistralDTO.MistralResult buildMistralFailure(
    Id recordId,
    Integer statusCode,
    String errorMsg
  ) {
    return new MistralDTO.MistralResult(recordId, errorMsg, statusCode);
  }
}
