public class GeocodeCalloutMock {
  // -------------------------------------------------------------------------
  // 200 — single result with coordinates
  // -------------------------------------------------------------------------
  public class SuccessMock implements HttpCalloutMock {
    public final Decimal lat;
    public final Decimal lng;

    public SuccessMock() {
      this.lat = 52.52;
      this.lng = 13.40;
    }

    public SuccessMock(Decimal lat, Decimal lng) {
      this.lat = lat;
      this.lng = lng;
    }

    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setBody(
        '{"total_results":1,"results":[{"geometry":{"lat":' +
          lat +
          ',"lng":' +
          lng +
          '}}]}'
      );
      return res;
    }
  }

  // -------------------------------------------------------------------------
  // 200 — empty results array (address not found)
  // -------------------------------------------------------------------------
  public class ZeroResultsMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setBody('{"total_results":0,"results":[]}');
      return res;
    }
  }

  // -------------------------------------------------------------------------
  // 400 — bad request (non-retryable)
  // -------------------------------------------------------------------------
  public class BadRequestMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(400);
      res.setStatus('Bad Request');
      res.setBody('{"message":"Bad Request"}');
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
  // 403 — forbidden (non-retryable)
  // -------------------------------------------------------------------------
  public class ForbiddenMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(403);
      res.setStatus('Forbidden');
      res.setBody('{"message":"Forbidden"}');
      return res;
    }
  }

  // -------------------------------------------------------------------------
  // 422 — unprocessable entity (non-retryable)
  // -------------------------------------------------------------------------
  public class UnprocessableMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(422);
      res.setStatus('Unprocessable Entity');
      res.setBody('{"message":"Unprocessable Entity"}');
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
}
