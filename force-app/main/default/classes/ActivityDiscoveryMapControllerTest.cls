@IsTest
private class ActivityDiscoveryMapControllerTest {
  private static Travel_Activity__c insertGeoTaggedActivity(
    String name,
    String city,
    String category,
    String goodFor,
    Decimal lat,
    Decimal lng
  ) {
    Travel_Activity__c act = new Travel_Activity__c(
      Name = name,
      City__c = city,
      Country__c = 'Germany',
      Category__c = category,
      Good_For__c = goodFor,
      Listing_Summary__c = 'A great activity.',
      Is_Geo_Tagged__c = true,
      Is_AI_Enhanced__c = false,
      Location__Latitude__s = lat,
      Location__Longitude__s = lng
    );
    insert act;
    return act;
  }

  @IsTest
  static void searchByCity_validCity_returnsActivitiesAndMetadata() {
    insertGeoTaggedActivity(
      'Berlin Tour',
      'Berlin',
      'Sightseeing',
      'Families',
      52.52,
      13.40
    );
    insertGeoTaggedActivity(
      'Berlin Food',
      'Berlin',
      'Food & Drink',
      'Couples',
      52.51,
      13.39
    );

    Test.startTest();
    Map<String, Object> response = ActivityDiscoveryMapController.searchByCity(
      'Berlin',
      null,
      null
    );
    Test.stopTest();

    Assert.isNotNull(response);
    Assert.isTrue(response.containsKey('activities'));
    Assert.isTrue(response.containsKey('capped'));
    Assert.isTrue(response.containsKey('total'));
    Assert.areEqual(2, (Integer) response.get('total'));
    Assert.isFalse((Boolean) response.get('capped'));

    List<ActivityDiscoveryMapDTO> dtos = (List<ActivityDiscoveryMapDTO>) response.get(
      'activities'
    );
    Assert.areEqual(2, dtos.size());
  }

  @IsTest
  static void searchByCity_withCategoryFilter_returnsFilteredResults() {
    insertGeoTaggedActivity(
      'Berlin Tour',
      'Berlin',
      'Sightseeing',
      'Families',
      52.52,
      13.40
    );
    insertGeoTaggedActivity(
      'Berlin Food',
      'Berlin',
      'Food & Drink',
      'Couples',
      52.51,
      13.39
    );

    Test.startTest();
    Map<String, Object> response = ActivityDiscoveryMapController.searchByCity(
      'Berlin',
      'Sightseeing',
      null
    );
    Test.stopTest();

    Assert.areEqual(1, (Integer) response.get('total'));
    List<ActivityDiscoveryMapDTO> dtos = (List<ActivityDiscoveryMapDTO>) response.get(
      'activities'
    );
    Assert.areEqual('Sightseeing', dtos[0].category);
  }

  @IsTest
  static void searchByCity_withGoodForFilter_returnsFilteredResults() {
    insertGeoTaggedActivity(
      'Berlin Tour',
      'Berlin',
      'Sightseeing',
      'Families',
      52.52,
      13.40
    );
    insertGeoTaggedActivity(
      'Berlin Bar',
      'Berlin',
      'Nightlife',
      'Couples',
      52.51,
      13.39
    );

    Test.startTest();
    Map<String, Object> response = ActivityDiscoveryMapController.searchByCity(
      'Berlin',
      null,
      'Families'
    );
    Test.stopTest();

    Assert.areEqual(1, (Integer) response.get('total'));
  }

  @IsTest
  static void searchByCity_blankCity_throwsAuraHandledException() {
    Boolean threw = false;

    Test.startTest();
    try {
      ActivityDiscoveryMapController.searchByCity('', null, null);
    } catch (AuraHandledException e) {
      threw = true;
    }
    Test.stopTest();

    Assert.isTrue(threw, 'Should throw AuraHandledException for blank city');
  }

  @IsTest
  static void searchByCity_nullCity_throwsAuraHandledException() {
    Boolean threw = false;

    Test.startTest();
    try {
      ActivityDiscoveryMapController.searchByCity(null, null, null);
    } catch (AuraHandledException e) {
      threw = true;
    }
    Test.stopTest();

    Assert.isTrue(threw, 'Should throw AuraHandledException for null city');
  }

  @IsTest
  static void searchByCity_cityWithWhitespace_isTrimmed() {
    insertGeoTaggedActivity(
      'Berlin Tour',
      'Berlin',
      'Sightseeing',
      'Families',
      52.52,
      13.40
    );

    Test.startTest();
    Map<String, Object> response = ActivityDiscoveryMapController.searchByCity(
      '  Berlin  ',
      null,
      null
    );
    Test.stopTest();

    Assert.areEqual(
      1,
      (Integer) response.get('total'),
      'City should be trimmed before querying'
    );
  }

  @IsTest
  static void searchByCity_noResults_returnsEmptyActivities() {
    Test.startTest();
    Map<String, Object> response = ActivityDiscoveryMapController.searchByCity(
      'Nonexistent City',
      null,
      null
    );
    Test.stopTest();

    Assert.areEqual(0, (Integer) response.get('total'));
    Assert.isFalse((Boolean) response.get('capped'));
  }

  @IsTest
  static void searchByRadius_validParams_returnsActivitiesAndMetadata() {
    insertGeoTaggedActivity(
      'Berlin Tour',
      'Berlin',
      'Sightseeing',
      'Families',
      52.52,
      13.40
    );

    Test.startTest();
    Map<String, Object> response = ActivityDiscoveryMapController.searchByRadius(
      52.52,
      13.40,
      10,
      null,
      null
    );
    Test.stopTest();

    Assert.isNotNull(response);
    Assert.isTrue(response.containsKey('activities'));
    Assert.isTrue(response.containsKey('capped'));
    Assert.isTrue(response.containsKey('total'));
    Assert.isTrue((Integer) response.get('total') >= 1);
  }

  @IsTest
  static void searchByRadius_withFilters_returnsFilteredResults() {
    insertGeoTaggedActivity(
      'Berlin Tour',
      'Berlin',
      'Sightseeing',
      'Families',
      52.52,
      13.40
    );
    insertGeoTaggedActivity(
      'Berlin Food',
      'Berlin',
      'Food & Drink',
      'Couples',
      52.51,
      13.39
    );

    Test.startTest();
    Map<String, Object> response = ActivityDiscoveryMapController.searchByRadius(
      52.52,
      13.40,
      50,
      'Sightseeing',
      null
    );
    Test.stopTest();

    Assert.areEqual(1, (Integer) response.get('total'));
    List<ActivityDiscoveryMapDTO> dtos = (List<ActivityDiscoveryMapDTO>) response.get(
      'activities'
    );
    Assert.areEqual('Sightseeing', dtos[0].category);
  }

  @IsTest
  static void searchByRadius_nullLat_throwsAuraHandledException() {
    Boolean threw = false;

    Test.startTest();
    try {
      ActivityDiscoveryMapController.searchByRadius(
        null,
        13.40,
        10,
        null,
        null
      );
    } catch (AuraHandledException e) {
      threw = true;
    }
    Test.stopTest();

    Assert.isTrue(threw);
  }

  @IsTest
  static void searchByRadius_nullLng_throwsAuraHandledException() {
    Boolean threw = false;

    Test.startTest();
    try {
      ActivityDiscoveryMapController.searchByRadius(
        52.52,
        null,
        10,
        null,
        null
      );
    } catch (AuraHandledException e) {
      threw = true;
    }
    Test.stopTest();

    Assert.isTrue(threw);
  }

  @IsTest
  static void searchByRadius_nullRadius_throwsAuraHandledException() {
    Boolean threw = false;

    Test.startTest();
    try {
      ActivityDiscoveryMapController.searchByRadius(
        52.52,
        13.40,
        null,
        null,
        null
      );
    } catch (AuraHandledException e) {
      threw = true;
    }
    Test.stopTest();

    Assert.isTrue(threw);
  }

  @IsTest
  static void searchByRadius_zeroRadius_throwsAuraHandledException() {
    Boolean threw = false;

    Test.startTest();
    try {
      ActivityDiscoveryMapController.searchByRadius(
        52.52,
        13.40,
        0,
        null,
        null
      );
    } catch (AuraHandledException e) {
      threw = true;
    }
    Test.stopTest();

    Assert.isTrue(threw);
  }

  @IsTest
  static void searchByRadius_negativeRadius_throwsAuraHandledException() {
    Boolean threw = false;

    Test.startTest();
    try {
      ActivityDiscoveryMapController.searchByRadius(
        52.52,
        13.40,
        -5,
        null,
        null
      );
    } catch (AuraHandledException e) {
      threw = true;
    }
    Test.stopTest();

    Assert.isTrue(threw);
  }

  // =========================================================================
  // getFilterOptions
  // =========================================================================

  @IsTest
  static void getFilterOptions_returnsMapWithCategoriesAndGoodForOptions() {
    Test.startTest();
    Map<String, List<String>> options = ActivityDiscoveryMapController.getFilterOptions();
    Test.stopTest();

    Assert.isNotNull(options);
    Assert.isTrue(
      options.containsKey('categories'),
      'Should contain categories key'
    );
    Assert.isTrue(
      options.containsKey('goodForOptions'),
      'Should contain goodForOptions key'
    );
    Assert.isTrue(
      options.get('categories').size() > 0,
      'Categories should not be empty'
    );
    Assert.isTrue(
      options.get('goodForOptions').size() > 0,
      'GoodForOptions should not be empty'
    );
  }

  @IsTest
  static void searchByCity_dtoFieldsMappedCorrectly() {
    insertGeoTaggedActivity(
      'Berlin Tour',
      'Berlin',
      'Sightseeing',
      'Families',
      52.52,
      13.40
    );

    Test.startTest();
    Map<String, Object> response = ActivityDiscoveryMapController.searchByCity(
      'Berlin',
      null,
      null
    );
    Test.stopTest();

    List<ActivityDiscoveryMapDTO> dtos = (List<ActivityDiscoveryMapDTO>) response.get(
      'activities'
    );
    Assert.areEqual(1, dtos.size());

    ActivityDiscoveryMapDTO dto = dtos[0];
    Assert.isNotNull(dto.id);
    Assert.areEqual('Berlin Tour', dto.name);
    Assert.areEqual(52.52, dto.latitude);
    Assert.areEqual(13.40, dto.longitude);
    Assert.areEqual('Sightseeing', dto.category);
    Assert.areEqual('Families', dto.goodFor);
    Assert.areEqual('Berlin', dto.city);
    Assert.areEqual('Germany', dto.country);
    Assert.areEqual('A great activity.', dto.listingSummary);
  }
}
