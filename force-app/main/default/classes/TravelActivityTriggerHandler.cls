public with sharing class TravelActivityTriggerHandler extends TriggerHandler {
  private List<Travel_Activity__c> newRecords;
  private Map<Id, Travel_Activity__c> oldMap;

  public TravelActivityTriggerHandler() {
    this.newRecords = (List<Travel_Activity__c>) Trigger.new;
    this.oldMap = (Map<Id, Travel_Activity__c>) Trigger.oldMap;
  }

  override protected void afterInsert() {
    enqueueGeocodingIfEligible(newRecords, null);
  }

  override protected void afterUpdate() {
    enqueueGeocodingIfEligible(newRecords, oldMap);
  }

  private static void enqueueGeocodingIfEligible(
    List<Travel_Activity__c> newRecords,
    Map<Id, Travel_Activity__c> oldMap
  ) {
    Set<Id> eligibleIds = getEligibleIds(newRecords, oldMap);
    if (
      eligibleIds.isEmpty() ||
      eligibleIds.size() > GeocodeActivityQueueable.SINGLE_RECORD_THRESHOLD ||
      System.isFuture() ||
      System.isQueueable()
    ) {
      return;
    }

    System.enqueueJob(new GeocodeActivityQueueable(eligibleIds));
  }

  private static Set<Id> getEligibleIds(
    List<Travel_Activity__c> newRecords,
    Map<Id, Travel_Activity__c> oldMap
  ) {
    Set<Id> eligible = new Set<Id>();

    for (Travel_Activity__c record : newRecords) {
      if (
        String.isBlank(record.Street__c) ||
        String.isBlank(record.City__c) ||
        String.isBlank(record.Country__c) ||
        String.isBlank(record.Zip__c) ||
        record.Is_Geo_Tagged__c
      ) {
        continue;
      }

      if (oldMap == null) {
        eligible.add(record.Id);
      } else {
        Travel_Activity__c oldActivity = oldMap.get(record.Id);
        Boolean isAddressChanged = (record.Street__c != oldActivity.Street__c ||
        record.City__c != oldActivity.City__c ||
        record.Country__c != oldActivity.Country__c ||
        record.Zip__c != oldActivity.Zip__c);
        Boolean isGeotagCleared =
          !record.Is_Geo_Tagged__c && oldActivity.Is_Geo_Tagged__c;

        if (isAddressChanged || isGeotagCleared) {
          eligible.add(record.Id);
        }
      }
    }

    return eligible;
  }
}
