public class ActivityDiscoveryMapDTO {
  @AuraEnabled
  public String id;
  @AuraEnabled
  public String name;
  @AuraEnabled
  public Decimal latitude;
  @AuraEnabled
  public Decimal longitude;
  @AuraEnabled
  public String category;
  @AuraEnabled
  public String goodFor;
  @AuraEnabled
  public String city;
  @AuraEnabled
  public String country;
  @AuraEnabled
  public String listingSummary;
  @AuraEnabled
  public String supplierName;

  public ActivityDiscoveryMapDTO(Travel_Activity__C a) {
    this.id = a.Id;
    this.name = a.Name;
    this.latitude = a.Location__Latitude__s;
    this.longitude = a.Location__Longitude__s;
    this.category = a.Category__c;
    this.goodFor = a.Good_For__c;
    this.city = a.City__c;
    this.country = a.Country__c;
    this.listingSummary = a.Listing_Summary__c;
    this.supplierName = a.Supplier__r?.Name;
  }

  /** Convenience factory for lists */
  public static List<ActivityDiscoveryMapDTO> fromList(
    List<Travel_Activity__C> activities
  ) {
    List<ActivityDiscoveryMapDTO> dtos = new List<ActivityDiscoveryMapDTO>();
    for (Travel_Activity__C a : activities) {
      dtos.add(new ActivityDiscoveryMapDTO(a));
    }
    return dtos;
  }
}
