public with sharing class GeocodingConfigSelector {
  private static final String GEOCODE_ERROR_MESSAGE = 'Geocoding_Config__mdt record "OpenCage" missing or has no key or has no url.';
  public static Geocoding_Config__mdt getGeocodingConfig() {
    List<Geocoding_Config__mdt> result = [
      SELECT Api_Key__c, Open_Cage_URL__c
      FROM Geocoding_Config__mdt
      WHERE DeveloperName = 'OpenCage'
      LIMIT 1
    ];
    if (
      result.isEmpty() ||
      String.isBlank(result[0].Api_Key__c) ||
      String.isBlank(result[0].Open_Cage_URL__c)
    ) {
      throw new MDTCustomException(GEOCODE_ERROR_MESSAGE);
    }
    return result[0];
  }
}
