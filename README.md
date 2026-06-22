Good time of a day, dear reader! The provided solution should be deployable as it is via sfdx.

1. 3rd party systems integration is handled via Custom Metadata:

Geocoding_Config\_\_mdt (record DeveloperName 'OpenCage') for api.opencagedata.com/geocode/v1/ endpoint

Mistral_Config\_\_mdt (record DeveloperName 'MistralBatch') for https://api.mistral.ai/v1/chat/completions endpoint

2. Records for both MDTs themselves will have to be created manually in the org and the API_Key\_\_c are to be properly populated.

3. Geocode integration works from a trigger as a queueable for one record updates (to provide close-to-RT solution for SF operators) and is invisioned as a scheduled batch solution for bulk geocoding.

4. AI enhancement of Listing_Summary\_\_c field is run as a scheduled batch only (as potentially more expensive tokenized tool). For endpoint limitation reasons the batch size is, unfortunately, 2 activities (something to improve).

5. Travel Activity custom object has a lookup relation field to Supplier custom object because during the data model design phase I thought it makes sense from a real-life business scenario that an activity might get detached from a supplier for a number of reasons, but should stay in the system.

6. Trade-offs: AI enhancement is an ad-hoc decision based on the limitations of used LLM endpoint. Part 5 of the candidate brief also had to be omitted because of my personal time limitations.

7. Given more resources Mistral AI enhancement tool could be improved significantly by using Mistral batch endpoint (either via json file upload and async operations with LLM or via agent) and better fine-tuned LLM request with guardrails and potentially different temperature/token values (something that will bring different summaries and is worth investigating together with the team). Mistral Integration itself might benefit from refactoring to align with a more lean and less pmd complex Geocode Integration.
