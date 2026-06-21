public with sharing class IntegrationLogService {
  public static final String GEOCODE = 'Geocode';
  public static final String MISTRAL = 'Mistral';
  public static final Integer MAX_RETRIES = 3;

  private static final Set<Integer> NO_RETRY_STATUSES = new Set<Integer>{
    400,
    401,
    403,
    422
  };

  private static final List<Integer> BACKOFF_MINUTES = new List<Integer>{
    5,
    15,
    45
  };

  public void logResults(
    List<GeocodeDTO.GeocodeResult> results,
    Map<Id, Integration_Log__c> existingLogs
  ) {
    List<Integration_Log__c> toInsert = new List<Integration_Log__c>();

    for (GeocodeDTO.GeocodeResult result : results) {
      Integration_Log__c existing = existingLogs != null
        ? existingLogs.get(result.activityId)
        : null;

      toInsert.add(buildLog(result, existing));
    }

    if (!toInsert.isEmpty()) {
      insert toInsert;
    }
  }

  public void logResults(
    List<MistralDTO.MistralResult> results,
    Map<Id, Integration_Log__c> existingLogs
  ) {
    List<Integration_Log__c> toInsert = new List<Integration_Log__c>();

    for (MistralDTO.MistralResult result : results) {
      Integration_Log__c existing = existingLogs != null
        ? existingLogs.get(result.recordId)
        : null;

      toInsert.add(buildLog(result, existing));
    }

    if (!toInsert.isEmpty()) {
      insert toInsert;
    }
  }

  public void logResults(List<GeocodeDTO.GeocodeResult> results) {
    logResults(results, null);
  }

  public void logResults(List<MistralDTO.MistralResult> results) {
    logResults(results, null);
  }

  private Integration_Log__c buildLog(
    GeocodeDTO.GeocodeResult result,
    Integration_Log__c existing
  ) {
    Integration_Log__c log = new Integration_Log__c(
      Record_Id__c = result.activityId,
      Operation__c = GEOCODE,
      HTTP_Status__c = result.httpStatus
    );

    if (result.success) {
      log.Status__c = 'Success';
      log.Error_Message__c = null;
      log.Retry_Count__c = 0;
      log.Next_Retry__c = null;
      return log;
    }

    // --- Failure path ---
    Integer currentRetries = existing != null
      ? (Integer) (existing.Retry_Count__c ?? 0)
      : 0;

    log.Error_Message__c = result.errorMessage;

    if (isNonRetryable(result.httpStatus)) {
      // Bad payload, auth failure, etc. — human intervention needed.
      log.Status__c = 'Failed No Retry';
      log.Retry_Count__c = currentRetries;
      log.Next_Retry__c = null;
    } else if (currentRetries >= MAX_RETRIES) {
      // Exhausted retries — alert needed.
      log.Status__c = 'Failed Max Retries';
      log.Retry_Count__c = currentRetries;
      log.Next_Retry__c = null;
    } else {
      // Transient failure — schedule retry with exponential backoff.
      Integer nextCount = currentRetries + 1;
      Integer backoffMinutes = BACKOFF_MINUTES[
        Math.min(nextCount - 1, BACKOFF_MINUTES.size() - 1)
      ];

      log.Status__c = 'Pending Retry';
      log.Retry_Count__c = nextCount;
      log.Next_Retry__c = DateTime.now().addMinutes(backoffMinutes);
    }

    return log;
  }

  private Integration_Log__c buildLog(
    MistralDTO.MistralResult result,
    Integration_Log__c existing
  ) {
    Integration_Log__c log = new Integration_Log__c(
      Record_Id__c = result.recordId,
      Operation__c = MISTRAL,
      HTTP_Status__c = result.statusCode
    );

    if (result.success) {
      log.Status__c = 'Success';
      log.Error_Message__c = null;
      log.Retry_Count__c = 0;
      log.Next_Retry__c = null;
      return log;
    }

    // --- Failure path ---
    Integer currentRetries = existing != null
      ? (Integer) (existing.Retry_Count__c ?? 0)
      : 0;

    log.Error_Message__c = result.errorMessage;

    if (isNonRetryable(result.statusCode)) {
      // Bad payload, auth failure, etc. — human intervention needed.
      log.Status__c = 'Failed No Retry';
      log.Retry_Count__c = currentRetries;
      log.Next_Retry__c = null;
    } else if (currentRetries >= MAX_RETRIES) {
      // Exhausted retries — alert needed.
      log.Status__c = 'Failed Max Retries';
      log.Retry_Count__c = currentRetries;
      log.Next_Retry__c = null;
    } else {
      // Transient failure — schedule retry with exponential backoff.
      Integer nextCount = currentRetries + 1;
      Integer backoffMinutes = BACKOFF_MINUTES[
        Math.min(nextCount - 1, BACKOFF_MINUTES.size() - 1)
      ];

      log.Status__c = 'Pending Retry';
      log.Retry_Count__c = nextCount;
      log.Next_Retry__c = DateTime.now().addMinutes(backoffMinutes);
    }

    return log;
  }

  private Boolean isNonRetryable(Integer httpStatus) {
    return httpStatus != null && NO_RETRY_STATUSES.contains(httpStatus);
  }
}
