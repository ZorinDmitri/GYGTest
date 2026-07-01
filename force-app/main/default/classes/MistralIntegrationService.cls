public with sharing class MistralIntegrationService {
  private static final Integer TIMEOUT_MS = 120000;
  private static final String MODEL = 'mistral-small';
  private static final Integer MAX_TOKENS = 512;
  private static final Double TEMPERATURE = 0.7;

  private final TravelActivitySelector activitySelector;
  private final IntegrationLogSelector logSelector;
  private final IntegrationLogService logSvc;
  private final Mistral_Config__mdt config;

  // Production constructor
  public MistralIntegrationService() {
    this.config = MistralConfigSelector.getMistralConfig();
    this.logSelector = new IntegrationLogSelector();
    this.logSvc = new IntegrationLogService();
  }

  // Test-injectable constructor
  @TestVisible
  private MistralIntegrationService(
    Mistral_Config__mdt config,
    IntegrationLogSelector logSelector,
    IntegrationLogService logSvc
  ) {
    this.config = config;
    this.logSelector = logSelector;
    this.logSvc = logSvc;
  }

  public List<MistralDTO.MistralResult> processActivities(
    List<Travel_Activity__c> activities
  ) {
    if (activities.isEmpty()) {
      return new List<MistralDTO.MistralResult>();
    }

    MistralDTO.ChatCompletionRequest request = buildChatCompletionRequest(
      activities
    );
    HttpResponse response = callout(request);

    List<MistralDTO.MistralResult> results = new List<MistralDTO.MistralResult>();

    if (response.getStatusCode() == 200) {
      results = parseChatCompletionResponse(response.getBody(), activities);
    } else {
      for (Travel_Activity__c activity : activities) {
        results.add(
          new MistralDTO.MistralResult(
            activity.Id,
            'API call failed: ' +
              response.getStatusCode() +
              ' - ' +
              response.getStatus(),
            response.getStatusCode()
          )
        );
      }
    }
    return results;
  }

  public void updateActivities(List<MistralDTO.MistralResult> results) {
    if (results.isEmpty()) {
      return;
    }

    Set<Id> activityIds = new Set<Id>();
    for (MistralDTO.MistralResult result : results) {
      activityIds.add(result.recordId);
    }

    Map<Id, Integration_Log__c> existingLogs = logSelector.selectLatestByOperationAndRecordIds(
      activityIds,
      IntegrationLogService.MISTRAL
    );

    List<Travel_Activity__c> activitiesToUpdate = new List<Travel_Activity__c>();
    List<MistralDTO.MistralResult> loggableResults = new List<MistralDTO.MistralResult>();

    for (MistralDTO.MistralResult result : results) {
      loggableResults.add(result);
      if (result.statusCode == 200 && result.data != null) {
        Travel_Activity__c activity = new Travel_Activity__c(
          Id = result.recordId
        );
        activity.Category__c = result.data.Category;
        activity.Duration__c = result.data.Duration;
        activity.Languages__c = result.data.Languages;
        activity.Accessibility__c = result.data.Accessibility;
        activity.Good_For__c = result.data.Good_For?.replace(',', ';');
        activity.Listing_Summary__c = result.data.Listing_Summary;
        activity.Is_AI_Enhanced__c = true;
        activitiesToUpdate.add(activity);
      }
    }

    if (!activitiesToUpdate.isEmpty()) {
      update activitiesToUpdate;
    }

    logSvc.logResults(loggableResults, existingLogs);
  }

  private MistralDTO.ChatCompletionRequest buildChatCompletionRequest(
    List<Travel_Activity__c> activities
  ) {
    MistralDTO.ChatCompletionRequest request = new MistralDTO.ChatCompletionRequest();
    request.model = MODEL;
    request.max_tokens = MAX_TOKENS;
    request.temperature = TEMPERATURE;
    request.response_format = new Map<String, String>{
      'type' => 'json_object'
    };

    String activitiesPrompt = buildActivitiesPrompt(activities);

    MistralDTO.Message message = new MistralDTO.Message();
    message.role = 'user';
    message.content = activitiesPrompt;
    request.messages = new List<MistralDTO.Message>{ message };

    return request;
  }

  private String buildActivitiesPrompt(List<Travel_Activity__c> activities) {
    String activitiesList = '';

    for (Integer i = 0; i < activities.size(); i++) {
      Travel_Activity__c activity = activities[i];
      if (i > 0) {
        activitiesList += '; ';
      }
      activitiesList +=
        'Id: ' +
        (i + 1) +
        ' Activity Name: ' +
        escapeForJson(activity.Name) +
        ' City: ' +
        escapeForJson(activity.City__c) +
        ' Country: ' +
        escapeForJson(activity.Country__c) +
        ' Supplier Notes: ' +
        escapeForJson(activity.SupplierNotes__c);
    }

    return 'You are a travel expert. Extract structured data from the following travel activities separated by ";". ' +
      'Return ONLY a valid JSON object with an "activities" array containing objects with these fields: ' +
      'Id - reference id, given in "Id" field, ' +
      'Category (picklist: Sightseeing, History & Culture, Food & Drink, Outdoor & Adventure, Family, Nightlife), ' +
      'Duration (in minutes, e.g., "120 minutes"), ' +
      'Languages (if you cannot decide, assume by the Country, comma-separated, e.g., "English,Spanish"), ' +
      'Accessibility (Yes/No/Partial), ' +
      'Good_For (Families/Couples/Solo/Group), ' +
      'Listing_Summary (2-3 sentence summary). ' +
      'If a field cannot be determined, set it to null. ' +
      'When you create the summary, think and write like a travel agent. ' +
      'Activities: ' +
      activitiesList;
  }

  private String escapeForJson(String input) {
    if (input == null)
      return '';
    return input
      .replace('\\', '\\\\')
      .replace('"', '\\"')
      .replace('\n', '\\n')
      .replace('\r', '\\r')
      .replace('\t', '\\t');
  }

  private HttpResponse callout(MistralDTO.ChatCompletionRequest request) {
    String requestBody = JSON.serialize(request);

    HttpRequest httpRequest = new HttpRequest();
    httpRequest.setEndpoint(config.Mistral_Batch_URL__c);
    httpRequest.setMethod('POST');
    httpRequest.setHeader('Content-Type', 'application/json');
    httpRequest.setHeader('Authorization', 'Bearer ' + config.API_Key__c);
    httpRequest.setBody(requestBody);
    httpRequest.setTimeout(TIMEOUT_MS);

    HttpResponse response = new Http().send(httpRequest);

    return response;
  }

  private List<MistralDTO.MistralResult> parseChatCompletionResponse(
    String responseBody,
    List<Travel_Activity__c> activities
  ) {
    List<MistralDTO.MistralResult> results = new List<MistralDTO.MistralResult>();

    try {
      Map<String, Object> outerResponse = (Map<String, Object>) JSON.deserializeUntyped(
        responseBody
      );

      List<Object> choices = (List<Object>) outerResponse.get('choices');
      if (choices == null || choices.isEmpty()) {
        for (Travel_Activity__c activity : activities) {
          results.add(
            new MistralDTO.MistralResult(
              activity.Id,
              'No choices returned in response',
              400
            )
          );
        }
        return results;
      }

      Map<String, Object> firstChoice = (Map<String, Object>) choices[0];
      Map<String, Object> message = (Map<String, Object>) firstChoice.get(
        'message'
      );
      String content = (String) message.get('content');

      System.debug('Mistral Response Content: ' + content);

      MistralDTO.ActivitiesWrapper wrapper;
      try {
        wrapper = (MistralDTO.ActivitiesWrapper) JSON.deserialize(
          content,
          MistralDTO.ActivitiesWrapper.class
        );
      } catch (Exception e) {
        // If deserialization fails, try extracting JSON from the string
        content = extractJsonFromString(content);
        if (content != null) {
          wrapper = (MistralDTO.ActivitiesWrapper) JSON.deserialize(
            content,
            MistralDTO.ActivitiesWrapper.class
          );
        } else {
          for (Travel_Activity__c activity : activities) {
            results.add(
              new MistralDTO.MistralResult(
                activity.Id,
                'Failed to parse JSON: ' + e.getMessage(),
                400
              )
            );
          }
          return results;
        }
      }

      // Map the responses back to the activities
      if (
        wrapper != null &&
        wrapper.activities != null &&
        wrapper.activities.size() == activities.size()
      ) {
        for (Integer i = 0; i < activities.size(); i++) {
          results.add(
            new MistralDTO.MistralResult(
              activities[i].Id,
              wrapper.activities[i]
            )
          );
        }
      } else {
        for (Travel_Activity__c activity : activities) {
          results.add(
            new MistralDTO.MistralResult(
              activity.Id,
              'Failed to parse response: Expected ' +
                activities.size() +
                ' responses, got ' +
                (wrapper?.activities?.size() ?? 0),
              400
            )
          );
        }
      }
    } catch (Exception e) {
      for (Travel_Activity__c activity : activities) {
        results.add(
          new MistralDTO.MistralResult(
            activity.Id,
            'Failed to parse response: ' + e.getMessage(),
            500
          )
        );
      }
    }
    return results;
  }

  private String extractJsonFromString(String input) {
    Integer startIndex = input.indexOf('{');
    Integer endIndex = input.lastIndexOf('}');
    if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
      return input.substring(startIndex, endIndex + 1);
    }
    return null;
  }
}
