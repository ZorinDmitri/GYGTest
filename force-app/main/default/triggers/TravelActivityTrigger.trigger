trigger TravelActivityTrigger on Travel_Activity__c (
    before insert, before update,
    after insert,  after update
) {
    new TravelActivityTriggerHandler().run();
}