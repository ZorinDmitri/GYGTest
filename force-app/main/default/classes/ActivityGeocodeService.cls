public with sharing class ActivityGeocodeService {
  private final GeocodeIntegrationService geocodeSvc;
  private final TravelActivitySelector activitySelector;
  private final IntegrationLogService logSvc;
  private final IntegrationLogSelector logSelector;

  // Constructor injection — allows mocking in tests.
  public ActivityGeocodeService(
    GeocodeIntegrationService geocodeSvc,
    TravelActivitySelector activitySelector,
    IntegrationLogService logSvc,
    IntegrationLogSelector logSelector
  ) {
    this.geocodeSvc = geocodeSvc;
    this.activitySelector = activitySelector;
    this.logSvc = logSvc;
    this.logSelector = logSelector;
  }

  public ActivityGeocodeService() {
    this(
      new GeocodeIntegrationService(),
      new TravelActivitySelector(),
      new IntegrationLogService(),
      new IntegrationLogSelector()
    );
  }

  public void geocodeActivities(Set<Id> activityIds) {
    if (activityIds == null || activityIds.isEmpty())
      return;

    List<Travel_Activity__C> activities = activitySelector.selectByIds(
      activityIds
    );
    if (activities.isEmpty())
      return;

    Map<Id, Integration_Log__c> existingLogs = logSelector.selectLatestByOperationAndRecordIds(
      activityIds,
      IntegrationLogService.GEOCODE
    );

    List<GeocodeDTO.GeocodeResult> results = geocodeSvc.geocode(activities);

    List<Travel_Activity__C> toUpdate = new List<Travel_Activity__C>();
    List<GeocodeDTO.GeocodeResult> loggableResults = new List<GeocodeDTO.GeocodeResult>();

    for (GeocodeDTO.GeocodeResult result : results) {
      loggableResults.add(result);
      if (result.success) {
        toUpdate.add(
          new Travel_Activity__C(
            Id = result.activityId,
            Location__Latitude__s = result.latitude,
            Location__Longitude__s = result.longitude,
            Is_Geo_Tagged__c = true
          )
        );
      }
    }

    if (!toUpdate.isEmpty()) {
      update toUpdate;
    }

    logSvc.logResults(loggableResults, existingLogs);
  }
}
