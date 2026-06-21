public inherited sharing class ActivityDiscoveryMapSelector {
  public static final Integer MAX_RESULTS = 200;

  public class MapQueryResult {
    public List<Travel_Activity__c> activities;
    public Boolean capped;

    public MapQueryResult(List<Travel_Activity__c> activities, Boolean capped) {
      this.activities = activities;
      this.capped = capped;
    }
  }

  public MapQueryResult selectByCity(
    String city,
    String category,
    String goodFor
  ) {
    String baseCondition = 'Is_Geo_Tagged__c = true AND City__c = :city';
    return runQuery(
      baseCondition,
      category,
      goodFor,
      new Map<String, Object>{ 'city' => city }
    );
  }

  public MapQueryResult selectByRadius(
    Decimal centerLat,
    Decimal centerLng,
    Decimal radiusKm,
    String category,
    String goodFor
  ) {
    if (centerLat == null || centerLng == null || radiusKm == null) {
      return new MapQueryResult(new List<Travel_Activity__c>(), false);
    }

    Decimal clampedRadius = Math.min(radiusKm, 500);

    String geoFilter =
      'DISTANCE(Location__c, GEOLOCATION(' +
      centerLat +
      ', ' +
      centerLng +
      '), \'km\') < ' +
      clampedRadius;

    String baseCondition = 'Is_Geo_Tagged__c = true AND ' + geoFilter;

    return runQuery(
      baseCondition,
      category,
      goodFor,
      new Map<String, Object>()
    );
  }

  private MapQueryResult runQuery(
    String baseCondition,
    String category,
    String goodFor,
    Map<String, Object> bindVars
  ) {
    String whereClause = baseCondition;

    if (String.isNotBlank(category)) {
      String safeCategory = category.replaceAll('\'', '');
      whereClause += ' AND Category__c = \'' + safeCategory + '\'';
    }

    if (String.isNotBlank(goodFor)) {
      String safeGoodFor = goodFor.replaceAll('\'', '');
      whereClause += ' AND Good_For__c INCLUDES (\'' + safeGoodFor + '\')';
    }

    Integer fetchLimit = MAX_RESULTS + 1;

    String query =
      'SELECT Id, Name, Location__Latitude__s, Location__Longitude__s, ' +
      '       Category__c, Good_For__c, City__c, Country__c, ' +
      '       Listing_Summary__c, Supplier__r.Name ' +
      'FROM   Travel_Activity__c ' +
      'WHERE  ' +
      whereClause +
      ' ORDER BY Name ASC ' +
      ' LIMIT ' +
      fetchLimit;

    List<Travel_Activity__c> results = (List<Travel_Activity__c>) Database.queryWithBinds(
      query,
      bindVars,
      AccessLevel.USER_MODE
    );

    Boolean capped = results.size() > MAX_RESULTS;
    if (capped) {
      List<Travel_Activity__c> trimmed = new List<Travel_Activity__c>();
      for (Integer i = 0; i < MAX_RESULTS; i++) {
        trimmed.add(results[i]);
      }
      results = trimmed;
    }

    return new MapQueryResult(results, capped);
  }
}
