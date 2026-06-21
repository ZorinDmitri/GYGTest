public class GeocodeActivityQueueable implements Queueable, Database.AllowsCallouts {
  public static final Integer SINGLE_RECORD_THRESHOLD = 1;

  private final Set<Id> activityIds;
  private final ActivityGeocodeService geocodeService;

  private GeocodeActivityQueueable(
    Set<Id> activityIds,
    ActivityGeocodeService geocodeService
  ) {
    this.activityIds = activityIds;
    this.geocodeService = geocodeService;
  }
  /** Production constructor. */
  public GeocodeActivityQueueable(Set<Id> activityIds) {
    this(activityIds, new ActivityGeocodeService());
  }

  public void execute(QueueableContext ctx) {
    geocodeService.geocodeActivities(activityIds);
  }
}
