public with sharing class MistralConfigSelector {
  private static final String MISTRAL_ERROR_MESSAGE = 'Mistral_Config__mdt record "MistralBatch" missing or has no key or has no url.';
  public static Mistral_Config__mdt getMistralConfig() {
    List<Mistral_Config__mdt> result = [
      SELECT Api_Key__c, Mistral_Batch_URL__c
      FROM Mistral_Config__mdt
      WHERE DeveloperName = 'MistralBatch'
      LIMIT 1
    ];
    if (
      result.isEmpty() ||
      String.isBlank(result[0].Api_Key__c) ||
      String.isBlank(result[0].Mistral_Batch_URL__c)
    ) {
      throw new MDTCustomException(MISTRAL_ERROR_MESSAGE);
    }
    return result[0];
  }
}
