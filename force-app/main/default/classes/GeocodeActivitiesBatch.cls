/**
 * GeocodeActivitiesBatch
 * Nightly safety net — geocodes any Activity that:
 *  (a) has an address but no coordinates (missed by trigger or bulk-imported), or
 *  (b) has a Pending_Retry log whose Next_Retry__c has passed.
 */
public with sharing class GeocodeActivitiesBatch implements Database.Batchable<SObject>, Database.AllowsCallouts, Schedulable {
  // Hard cap: one HTTP callout per record, 100 callout limit per transaction.
  @TestVisible
  private static final Integer MAX_BATCH_SIZE = 100;

  private final ActivityGeocodeService geocodeService;
  private final TravelActivitySelector activitySelector;

  /** Production constructor. */
  public GeocodeActivitiesBatch() {
    this(new ActivityGeocodeService(), new TravelActivitySelector());
  }

  /** Test-injectable constructor. */
  @TestVisible
  private GeocodeActivitiesBatch(
    ActivityGeocodeService geocodeService,
    TravelActivitySelector activitySelector
  ) {
    this.geocodeService = geocodeService;
    this.activitySelector = activitySelector;
  }

  public void execute(SchedulableContext ctx) {
    Database.executeBatch(new GeocodeActivitiesBatch(), MAX_BATCH_SIZE);
  }

  /**
   * Combines two candidate sets:
   *  1. Activities with address but no coordinates (first-time geocode).
   *  2. Activities with Pending_Retry logs (re-geocode after failure).
   *
   */
  public Database.QueryLocator start(Database.BatchableContext ctx) {
    return Database.getQueryLocator(
      [
        SELECT Id, Street__c, City__c, Country__c, Zip__c, Location__c
        FROM Travel_Activity__c
        WHERE
          Is_Geo_Tagged__c = FALSE
          AND Street__c != NULL
          AND City__c != NULL
          AND Zip__c != NULL
          AND Country__c != NULL
        ORDER BY CreatedDate ASC
      ]
    );
  }

  public void execute(
    Database.BatchableContext ctx,
    List<Travel_Activity__c> scope
  ) {
    Set<Id> ids = new Map<Id, Travel_Activity__c>(scope).keySet();
    geocodeService.geocodeActivities(ids);
  }

  public void finish(Database.BatchableContext ctx) {
    List<Travel_Activity__c> retryable = activitySelector.selectGeoTagRetryable();
    if (!retryable.isEmpty()) {
      Set<Id> retryIds = new Map<Id, Travel_Activity__c>(retryable).keySet();
      List<Id> idList = new List<Id>(retryIds);
      Integer i = 0;
      while (i < idList.size()) {
        Set<Id> chunk = new Set<Id>();
        for (
          Integer j = i; j < Math.min(i + MAX_BATCH_SIZE, idList.size()); j++
        ) {
          chunk.add(idList[j]);
        }
        geocodeService.geocodeActivities(chunk);
        i += MAX_BATCH_SIZE;
      }
    }
  }
}
