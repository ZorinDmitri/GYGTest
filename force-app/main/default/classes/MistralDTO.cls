public with sharing class MistralDTO {
  // Request structure for Mistral
  public class ChatCompletionRequest {
    public String model;
    public Integer max_tokens;
    public Double temperature;
    public Map<String, String> response_format;
    public List<Message> messages;
  }

  public class Message {
    public String role;
    public String content;
  }

  // Response structure
  public class ChatCompletionResponse {
    public List<Choice> choices;
  }

  public class Choice {
    public Message message;
  }

  // Wrapper for the activities array in the response
  public class ActivitiesWrapper {
    public List<ActivityResponse> activities;
  }

  // Structured output for each activity
  public class ActivityResponse {
    public Integer Id;
    public String Category;
    public String Duration;
    public String Languages;
    public String Accessibility;
    public String Good_For;
    public String Listing_Summary;
  }

  // Result wrapper
  public class MistralResult {
    public Id recordId;
    public String errorMessage;
    public Integer statusCode;
    public ActivityResponse data;
    public Boolean success;

    public MistralResult(Id recordId, String errorMessage, Integer statusCode) {
      this.recordId = recordId;
      this.errorMessage = errorMessage;
      this.statusCode = statusCode;
      this.success = false;
    }

    public MistralResult(Id recordId, ActivityResponse data) {
      this.recordId = recordId;
      this.data = data;
      this.statusCode = 200;
      this.success = true;
    }
  }
}
