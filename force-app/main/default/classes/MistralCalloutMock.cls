public class MistralCalloutMock {
  private static String buildSuccessBody(Integer activityCount) {
    List<Map<String, Object>> activities = new List<Map<String, Object>>();
    for (Integer i = 0; i < activityCount; i++) {
      activities.add(
        new Map<String, Object>{
          'Id' => i + 1,
          'Category' => 'Sightseeing',
          'Duration' => '120 minutes',
          'Languages' => 'English,German',
          'Accessibility' => 'Yes',
          'Good_For' => 'Families,Couples',
          'Listing_Summary' => 'A wonderful experience in the heart of the city.'
        }
      );
    }

    // Inner content is the JSON string that parseChatCompletionResponse
    // will JSON.deserialize into ActivitiesWrapper
    String innerContent = JSON.serialize(
      new Map<String, Object>{ 'activities' => activities }
    );

    // Outer envelope: choices[0].message.content = innerContent (as a string)
    Map<String, Object> outerObject = new Map<String, Object>{
      'choices' => new List<Object>{
        new Map<String, Object>{
          'message' => new Map<String, Object>{
            'role' => 'assistant',
            'content' => innerContent
          }
        }
      }
    };

    return JSON.serialize(outerObject);
  }

  // -------------------------------------------------------------------------
  // 200 — valid response for N activities
  // -------------------------------------------------------------------------
  public class BatchSuccessMock implements HttpCalloutMock {
    private final Integer count;

    public BatchSuccessMock(Integer count) {
      this.count = count;
    }

    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setBody(buildSuccessBody(count));
      return res;
    }
  }

  // -------------------------------------------------------------------------
  // 200 — empty choices array
  // -------------------------------------------------------------------------
  public class EmptyChoicesMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setBody('{"choices":[]}');
      return res;
    }
  }

  // -------------------------------------------------------------------------
  // 200 — malformed JSON in content field
  // -------------------------------------------------------------------------
  public class MalformedContentMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setBody(
        JSON.serialize(
          new Map<String, Object>{
            'choices' => new List<Object>{
              new Map<String, Object>{
                'message' => new Map<String, Object>{
                  'role' => 'assistant',
                  'content' => 'NOT_JSON{{{'
                }
              }
            }
          }
        )
      );
      return res;
    }
  }

  // -------------------------------------------------------------------------
  // 200 — activity count mismatch (always returns 1 regardless of input)
  // -------------------------------------------------------------------------
  public class CountMismatchMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setBody(buildSuccessBody(1));
      return res;
    }
  }

  // -------------------------------------------------------------------------
  // 401 — unauthorized (non-retryable)
  // -------------------------------------------------------------------------
  public class UnauthorizedMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(401);
      res.setStatus('Unauthorized');
      res.setBody('{"message":"Unauthorized"}');
      return res;
    }
  }

  // -------------------------------------------------------------------------
  // 429 — rate limited (retryable)
  // -------------------------------------------------------------------------
  public class RateLimitedMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(429);
      res.setStatus('Too Many Requests');
      res.setBody('{"message":"Rate limit exceeded"}');
      return res;
    }
  }

  // -------------------------------------------------------------------------
  // 500 — server error (retryable)
  // -------------------------------------------------------------------------
  public class ServerErrorMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(500);
      res.setStatus('Internal Server Error');
      res.setBody('{"message":"Internal Server Error"}');
      return res;
    }
  }

  // -------------------------------------------------------------------------
  // CalloutException — network-level failure
  // -------------------------------------------------------------------------
  public class CalloutExceptionMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      CalloutException e = (CalloutException) CalloutException.class
        .newInstance();
      e.setMessage('Read timed out');
      throw e;
    }
  }

  // -------------------------------------------------------------------------
  // Request inspector — captures outbound request for assertion
  // -------------------------------------------------------------------------
  public class RequestCaptureMock implements HttpCalloutMock {
    public HttpRequest capturedRequest;
    private final Integer activityCount;

    public RequestCaptureMock(Integer activityCount) {
      this.activityCount = activityCount;
    }

    public HttpResponse respond(HttpRequest req) {
      this.capturedRequest = req;
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setBody(buildSuccessBody(activityCount));
      return res;
    }
  }
}
