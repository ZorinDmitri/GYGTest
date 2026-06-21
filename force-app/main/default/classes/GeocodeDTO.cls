public class GeocodeDTO {
  public class GeocodeResult {
    public final String activityId;
    public final Decimal latitude;
    public final Decimal longitude;
    public final Boolean success;
    public final String errorMessage;
    public final Integer httpStatus;

    public GeocodeResult(
      String activityId,
      Decimal lat,
      Decimal lng,
      Integer httpStatus
    ) {
      this.activityId = activityId;
      this.latitude = lat;
      this.longitude = lng;
      this.success = true;
      this.errorMessage = null;
      this.httpStatus = httpStatus;
    }

    public GeocodeResult(
      String activityId,
      String errorMessage,
      Integer httpStatus
    ) {
      this.activityId = activityId;
      this.latitude = null;
      this.longitude = null;
      this.success = false;
      this.errorMessage = errorMessage;
      this.httpStatus = httpStatus;
    }
  }

  public class OpenCageResponse {
    public Integer total_results;
    public List<OcResult> results;
  }

  public class OcResult {
    public OcGeometry geometry;
  }

  public class OcGeometry {
    public Decimal lat;
    public Decimal lng;
  }
}
