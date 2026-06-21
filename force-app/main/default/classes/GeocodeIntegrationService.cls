public with sharing class GeocodeIntegrationService {
  private static final Integer TIMEOUT_MS = 120000;

  public List<GeocodeDTO.GeocodeResult> geocode(
    List<Travel_Activity__C> activities
  ) {
    //API key is read from Geocoding_Config__mdt at runtime.
    Geocoding_Config__mdt config = GeocodingConfigSelector.getGeocodingConfig();

    List<GeocodeDTO.GeocodeResult> results = new List<GeocodeDTO.GeocodeResult>();

    for (Travel_Activity__C activity : activities) {
      String address = buildAddress(activity);
      if (String.isBlank(address)) {
        results.add(
          new GeocodeDTO.GeocodeResult(
            activity.Id,
            'Address fields insufficient for geocoding',
            400
          )
        );
        continue;
      }
      results.add(callout(activity.Id, address, config));
    }

    return results;
  }

  private GeocodeDTO.GeocodeResult callout(
    String activityId,
    String address,
    Geocoding_Config__mdt config
  ) {
    String encodedAddress = EncodingUtil.urlEncode(address, 'UTF-8');
    String url = String.format(
      config.Open_Cage_URL__c,
      new List<String>{ encodedAddress, config.Api_Key__c }
    );

    HttpRequest req = new HttpRequest();
    req.setEndpoint(url);
    req.setMethod('GET');
    req.setTimeout(TIMEOUT_MS);

    HttpResponse res;
    try {
      res = new Http().send(req);
    } catch (System.CalloutException e) {
      return new GeocodeDTO.GeocodeResult(
        activityId,
        'Callout exception: ' + e.getMessage(),
        0
      );
    }

    Integer statusCode = res.getStatusCode();

    if (statusCode == 200) {
      return parseResponse(activityId, res.getBody(), statusCode);
    }

    // 429 = rate-limited, 5xx = server error → retryable.
    // 400/401/403/422 → non-retryable (IntegrationLogService classifies from statusCode).
    return new GeocodeDTO.GeocodeResult(
      activityId,
      'HTTP ' + statusCode + ': ' + res.getStatus(),
      statusCode
    );
  }

  private GeocodeDTO.GeocodeResult parseResponse(
    String activityId,
    String body,
    Integer statusCode
  ) {
    try {
      GeocodeDTO.OpenCageResponse parsed = (GeocodeDTO.OpenCageResponse) JSON.deserialize(
        body,
        GeocodeDTO.OpenCageResponse.class
      );

      if (
        parsed == null ||
        parsed.results == null ||
        parsed.results.isEmpty() ||
        parsed.results[0].geometry == null
      ) {
        // Valid response but address not found — not a retryable error.
        return new GeocodeDTO.GeocodeResult(
          activityId,
          'No geocoding results returned',
          422
        );
      }

      GeocodeDTO.OcGeometry geo = parsed.results[0].geometry;
      return new GeocodeDTO.GeocodeResult(
        activityId,
        geo.lat,
        geo.lng,
        statusCode
      );
    } catch (JSONException e) {
      // Malformed JSON — treat as non-retryable (provider issue, not transient).
      return new GeocodeDTO.GeocodeResult(
        activityId,
        'JSON parse error: ' + e.getMessage(),
        422
      );
    }
  }

  private String buildAddress(Travel_Activity__C activity) {
    String result = '';
    if (String.isNotBlank(activity.Street__c))
      result += activity.Street__c.trim();
    if (String.isNotBlank(activity.Zip__c))
      result += ', ' + activity.Zip__c.trim();
    if (String.isNotBlank(activity.City__c))
      result += ' ' + activity.City__c.trim();
    if (String.isNotBlank(activity.Country__c))
      result += ', ' + activity.Country__c.trim();
    return result;
  }
}
