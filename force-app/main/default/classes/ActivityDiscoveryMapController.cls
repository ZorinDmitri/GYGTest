public with sharing class ActivityDiscoveryMapController {
  private static final ActivityDiscoveryMapSelector selector = new ActivityDiscoveryMapSelector();

  @AuraEnabled
  public static Map<String, Object> searchByCity(
    String city,
    String category,
    String goodFor
  ) {
    if (String.isBlank(city)) {
      throw new AuraHandledException('City is required for city search.');
    }
    try {
      ActivityDiscoveryMapSelector.MapQueryResult result = selector.selectByCity(
        city.trim(),
        category,
        goodFor
      );
      return buildResponse(result);
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  @AuraEnabled
  public static Map<String, Object> searchByRadius(
    Decimal centerLat,
    Decimal centerLng,
    Decimal radiusKm,
    String category,
    String goodFor
  ) {
    if (centerLat == null || centerLng == null) {
      throw new AuraHandledException(
        'Coordinates are required for radius search.'
      );
    }
    if (radiusKm == null || radiusKm <= 0) {
      throw new AuraHandledException('Radius must be a positive number.');
    }
    try {
      ActivityDiscoveryMapSelector.MapQueryResult result = selector.selectByRadius(
        centerLat,
        centerLng,
        radiusKm,
        category,
        goodFor
      );
      return buildResponse(result);
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  @AuraEnabled(cacheable=true)
  public static Map<String, List<String>> getFilterOptions() {
    Map<String, List<String>> options = new Map<String, List<String>>{
      'categories' => getPicklistValues(Travel_Activity__c.Category__c),
      'goodForOptions' => getPicklistValues(Travel_Activity__c.Good_For__c)
    };
    return options;
  }

  private static Map<String, Object> buildResponse(
    ActivityDiscoveryMapSelector.MapQueryResult result
  ) {
    return new Map<String, Object>{
      'activities' => ActivityDiscoveryMapDTO.fromList(result.activities),
      'capped' => result.capped,
      'total' => result.activities.size()
    };
  }

  private static List<String> getPicklistValues(Schema.SObjectField field) {
    List<String> values = new List<String>();
    for (Schema.PicklistEntry entry : field.getDescribe().getPicklistValues()) {
      if (entry.isActive()) {
        values.add(entry.getValue());
      }
    }
    return values;
  }
}
