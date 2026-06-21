@IsTest
private class ActivityDiscoveryMapSelectorTest {
  private static Travel_Activity__c insertGeoTaggedActivity(
    String name,
    String city,
    String country,
    String category,
    String goodFor,
    Decimal lat,
    Decimal lng
  ) {
    Travel_Activity__c act = new Travel_Activity__c(
      Name = name,
      City__c = city,
      Country__c = country,
      Category__c = category,
      Good_For__c = goodFor,
      Is_Geo_Tagged__c = true,
      Is_AI_Enhanced__c = false,
      Location__Latitude__s = lat,
      Location__Longitude__s = lng
    );
    insert act;
    return act;
  }

  private static Travel_Activity__c insertUngeotaggedActivity(
    String name,
    String city
  ) {
    Travel_Activity__c act = new Travel_Activity__c(
      Name = name,
      City__c = city,
      Country__c = 'Germany',
      Is_Geo_Tagged__c = false
    );
    insert act;
    return act;
  }

  @IsTest
  static void selectByCity_returnsGeoTaggedActivitiesInCity() {
    insertGeoTaggedActivity(
      'Berlin Tour',
      'Berlin',
      'Germany',
      'Sightseeing',
      'Families',
      52.52,
      13.40
    );
    insertGeoTaggedActivity(
      'Berlin Food',
      'Berlin',
      'Germany',
      'Food & Drink',
      'Couples',
      52.51,
      13.39
    );
    insertGeoTaggedActivity(
      'Munich Tour',
      'Munich',
      'Germany',
      'Sightseeing',
      'Families',
      48.13,
      11.58
    );

    Test.startTest();
    ActivityDiscoveryMapSelector.MapQueryResult result = new ActivityDiscoveryMapSelector()
      .selectByCity('Berlin', null, null);
    Test.stopTest();

    Assert.areEqual(
      2,
      result.activities.size(),
      'Should return only Berlin activities'
    );
    Assert.isFalse(result.capped);
    for (Travel_Activity__c act : result.activities) {
      Assert.areEqual('Berlin', act.City__c);
    }
  }

  @IsTest
  static void selectByCity_excludesUngeotaggedActivities() {
    insertGeoTaggedActivity(
      'Berlin Tour',
      'Berlin',
      'Germany',
      'Sightseeing',
      'Families',
      52.52,
      13.40
    );
    Id ungeotaggedId = insertUngeotaggedActivity('Berlin Walk', 'Berlin').Id;

    Test.startTest();
    ActivityDiscoveryMapSelector.MapQueryResult result = new ActivityDiscoveryMapSelector()
      .selectByCity('Berlin', null, null);
    Test.stopTest();

    Set<Id> resultIds = new Map<Id, Travel_Activity__c>(result.activities)
      .keySet();
    Assert.isFalse(
      resultIds.contains(ungeotaggedId),
      'Ungeocoded activity must be excluded'
    );
    Assert.areEqual(1, result.activities.size());
  }

  @IsTest
  static void selectByCity_filtersOnCategory() {
    insertGeoTaggedActivity(
      'Berlin Tour',
      'Berlin',
      'Germany',
      'Sightseeing',
      'Families',
      52.52,
      13.40
    );
    insertGeoTaggedActivity(
      'Berlin Food',
      'Berlin',
      'Germany',
      'Food & Drink',
      'Couples',
      52.51,
      13.39
    );

    Test.startTest();
    ActivityDiscoveryMapSelector.MapQueryResult result = new ActivityDiscoveryMapSelector()
      .selectByCity('Berlin', 'Sightseeing', null);
    Test.stopTest();

    Assert.areEqual(1, result.activities.size());
    Assert.areEqual('Sightseeing', result.activities[0].Category__c);
  }

  @IsTest
  static void selectByCity_filtersOnGoodFor() {
    insertGeoTaggedActivity(
      'Berlin Tour',
      'Berlin',
      'Germany',
      'Sightseeing',
      'Families',
      52.50,
      13.40
    );
    insertGeoTaggedActivity(
      'Berlin Bar',
      'Berlin',
      'Germany',
      'Nightlife',
      'Couples',
      52.51,
      13.39
    );

    Test.startTest();
    ActivityDiscoveryMapSelector.MapQueryResult result = new ActivityDiscoveryMapSelector()
      .selectByCity('Berlin', null, 'Families');
    Test.stopTest();

    Assert.areEqual(1, result.activities.size());
    Assert.isTrue(result.activities[0].Good_For__c.contains('Families'));
  }

  @IsTest
  static void selectByCity_filtersOnCategoryAndGoodFor() {
    insertGeoTaggedActivity(
      'Berlin Tour',
      'Berlin',
      'Germany',
      'Sightseeing',
      'Families',
      52.52,
      13.40
    );
    insertGeoTaggedActivity(
      'Berlin Food',
      'Berlin',
      'Germany',
      'Food & Drink',
      'Families',
      52.51,
      13.39
    );
    insertGeoTaggedActivity(
      'Berlin Bar',
      'Berlin',
      'Germany',
      'Sightseeing',
      'Couples',
      52.50,
      13.38
    );

    Test.startTest();
    ActivityDiscoveryMapSelector.MapQueryResult result = new ActivityDiscoveryMapSelector()
      .selectByCity('Berlin', 'Sightseeing', 'Families');
    Test.stopTest();

    Assert.areEqual(1, result.activities.size());
    Assert.areEqual('Sightseeing', result.activities[0].Category__c);
    Assert.isTrue(result.activities[0].Good_For__c.contains('Families'));
  }

  @IsTest
  static void selectByCity_noMatchingCity_returnsEmpty() {
    insertGeoTaggedActivity(
      'Berlin Tour',
      'Berlin',
      'Germany',
      'Sightseeing',
      'Families',
      52.52,
      13.40
    );

    Test.startTest();
    ActivityDiscoveryMapSelector.MapQueryResult result = new ActivityDiscoveryMapSelector()
      .selectByCity('Hamburg', null, null);
    Test.stopTest();

    Assert.isTrue(result.activities.isEmpty());
    Assert.isFalse(result.capped);
  }

  @IsTest
  static void selectByCity_cappedWhenOverMaxResults() {
    // Insert MAX_RESULTS + 1 activities to trigger the cap
    List<Travel_Activity__c> acts = new List<Travel_Activity__c>();
    for (Integer i = 0; i <= ActivityDiscoveryMapSelector.MAX_RESULTS; i++) {
      acts.add(
        new Travel_Activity__c(
          Name = 'Activity ' + i,
          City__c = 'Berlin',
          Country__c = 'Germany',
          Is_Geo_Tagged__c = true,
          Location__Latitude__s = 52.52 + (i * 0.001),
          Location__Longitude__s = 13.40
        )
      );
    }
    insert acts;

    Test.startTest();
    ActivityDiscoveryMapSelector.MapQueryResult result = new ActivityDiscoveryMapSelector()
      .selectByCity('Berlin', null, null);
    Test.stopTest();

    Assert.isTrue(
      result.capped,
      'Result should be capped when over MAX_RESULTS'
    );
    Assert.areEqual(
      ActivityDiscoveryMapSelector.MAX_RESULTS,
      result.activities.size(),
      'Capped result should contain exactly MAX_RESULTS activities'
    );
  }

  @IsTest
  static void selectByRadius_returnsActivitiesWithinRadius() {
    insertGeoTaggedActivity(
      'Close Activity',
      'Berlin',
      'Germany',
      'Sightseeing',
      'Families',
      52.52,
      13.40
    );
    insertGeoTaggedActivity(
      'Far Activity',
      'Hamburg',
      'Germany',
      'Sightseeing',
      'Families',
      53.55,
      10.00
    );

    Test.startTest();
    ActivityDiscoveryMapSelector.MapQueryResult result = new ActivityDiscoveryMapSelector()
      .selectByRadius(52.52, 13.40, 10, null, null);
    Test.stopTest();

    Assert.areEqual(
      1,
      result.activities.size(),
      'Only activity within radius should be returned'
    );
    Assert.areEqual('Close Activity', result.activities[0].Name);
  }

  @IsTest
  static void selectByRadius_nullCoordinates_returnsEmpty() {
    Test.startTest();
    ActivityDiscoveryMapSelector.MapQueryResult result = new ActivityDiscoveryMapSelector()
      .selectByRadius(null, null, 10, null, null);
    Test.stopTest();

    Assert.isTrue(result.activities.isEmpty());
    Assert.isFalse(result.capped);
  }

  @IsTest
  static void selectByRadius_nullLat_returnsEmpty() {
    Test.startTest();
    ActivityDiscoveryMapSelector.MapQueryResult result = new ActivityDiscoveryMapSelector()
      .selectByRadius(null, 13.40, 10, null, null);
    Test.stopTest();

    Assert.isTrue(result.activities.isEmpty());
  }

  @IsTest
  static void selectByRadius_nullLng_returnsEmpty() {
    Test.startTest();
    ActivityDiscoveryMapSelector.MapQueryResult result = new ActivityDiscoveryMapSelector()
      .selectByRadius(52.52, null, 10, null, null);
    Test.stopTest();

    Assert.isTrue(result.activities.isEmpty());
  }

  @IsTest
  static void selectByRadius_nullRadius_returnsEmpty() {
    Test.startTest();
    ActivityDiscoveryMapSelector.MapQueryResult result = new ActivityDiscoveryMapSelector()
      .selectByRadius(52.52, 13.40, null, null, null);
    Test.stopTest();

    Assert.isTrue(result.activities.isEmpty());
  }

  @IsTest
  static void selectByRadius_radiusCappedAt500km() {
    insertGeoTaggedActivity(
      'Berlin Activity',
      'Berlin',
      'Germany',
      'Sightseeing',
      'Families',
      52.52,
      13.40
    );

    Test.startTest();
    ActivityDiscoveryMapSelector.MapQueryResult result = new ActivityDiscoveryMapSelector()
      .selectByRadius(52.52, 13.40, 9999, null, null);
    Test.stopTest();

    Assert.isTrue(result.activities.size() >= 1);
  }

  @IsTest
  static void selectByRadius_filtersOnCategory() {
    insertGeoTaggedActivity(
      'Berlin Tour',
      'Berlin',
      'Germany',
      'Sightseeing',
      'Families',
      52.52,
      13.40
    );
    insertGeoTaggedActivity(
      'Berlin Food',
      'Berlin',
      'Germany',
      'Food & Drink',
      'Couples',
      52.51,
      13.39
    );

    Test.startTest();
    ActivityDiscoveryMapSelector.MapQueryResult result = new ActivityDiscoveryMapSelector()
      .selectByRadius(52.52, 13.40, 50, 'Sightseeing', null);
    Test.stopTest();

    Assert.areEqual(1, result.activities.size());
    Assert.areEqual('Sightseeing', result.activities[0].Category__c);
  }

  @IsTest
  static void selectByRadius_filtersOnGoodFor() {
    insertGeoTaggedActivity(
      'Berlin Tour',
      'Berlin',
      'Germany',
      'Sightseeing',
      'Families',
      52.52,
      13.40
    );
    insertGeoTaggedActivity(
      'Berlin Bar',
      'Berlin',
      'Germany',
      'Nightlife',
      'Couples',
      52.51,
      13.39
    );

    Test.startTest();
    ActivityDiscoveryMapSelector.MapQueryResult result = new ActivityDiscoveryMapSelector()
      .selectByRadius(52.52, 13.40, 50, null, 'Couples');
    Test.stopTest();

    Assert.areEqual(1, result.activities.size());
    Assert.isTrue(result.activities[0].Good_For__c.contains('Couples'));
  }
}
