# AI Usage

> This file is **graded**. We assume you used AI — we want to see _how_. Keep it honest and specific; bullet points are fine.

## Tools used

1. Claude Code - Geocode Integration, Activity Discovery Map LWC, Unit test coverage
2. Mistral - Mistral Supplier Summary Integration

## Prompts that worked well

1. I have the following structure in my salesforce org:
   Custom Object:
   Travel_Activity**c
   Custom Fields:
   SupplierNotes**c (Long Text Area 32768)
   Name (activity name)
   City\_\_c (city where this traveller activity is taking place)

I want you to help me design salesforce apex class structure to enable the following:

Send `Supplier_Notes__c` (plus title/city) to Le Mistral LLM and have it return structured JSON that I can parse and write to typed fields. Extract at least:

- `Category__c` (picklist — e.g. Sightseeing, History & Culture, Food & Drink, Outdoor & Adventure, Family, Nightlife)
- `Duration__c`, `Languages__c`, `Accessibility__c` (e.g. wheelchair Yes/No/Partial), `Good_For__c` (e.g. Families / Couples / Solo)
- `Listing_Summary__c` (2–3 sentence customer-facing blurb)

What to be aware about:

- Prompt engineering for reliable structured output (constrain the schema; map free text to your picklist values).
- Robust parsing & validation — the model will sometimes omit a field, invent a category, or wrap JSON in prose. Handle it; don't let one bad response corrupt the record.

URL and API key should be stored in CMDT. Implement selector and service design patterns for apex

2. activityDiscoveryMap LWC generation with leaflet static resource went surprisingly well and needeed only a minor effort fine-tuning. And it was probably my mistake all along because of how static resource files were retrieved from Leaflet site. prompt used: word-to-word copy-paste from Part 4 of CANDIDATE_BRIEF.md

3. the part 3 extraction prompt is present in MistralIntegrationService: return 'You are a travel expert. Extract structured data from the following travel activities separated by ";". ' +
   'Return ONLY a valid JSON object with an "activities" array containing objects with these fields: ' +
   'Id - reference id, given in "Id" field, ' +
   'Category (picklist: Sightseeing, History & Culture, Food & Drink, Outdoor & Adventure, Family, Nightlife), ' +
   'Duration (in minutes, e.g., "120 minutes"), ' +
   'Languages (if you cannot decide, assume by the Country, comma-separated, e.g., "English,Spanish"), ' +
   'Accessibility (Yes/No/Partial), ' +
   'Good_For (Families/Couples/Solo/Group), ' +
   'Listing_Summary (2-3 sentence summary). ' +
   'If a field cannot be determined, set it to null. ' +
   'When you create the summary, think and write like a travel agent. ' +
   'Activities: ' +
   activitiesList;

## Where the AI was wrong or misleading

Mistral AI got carried away with Integrations and had issues reading/interpreting Mistral's API documentation. Spent quite some time and effort trying to implement uploads in batches for LLM processing. Ended up with a deadlock, which was broken by me suggesting a totally different approach. Also the Mistral Integration/Logging part was done in a slightly different (less optimal) manner and required fixes/refactors to bring it in line with Geocoding/Logging.

Claude ignored its own CalloutMocks initially, when asked to create unit tests some mock versions were not used, ended up being just sitting there not being called anywhere.
In one instance when explicitely asked to provide unit test coverage according to TestDataFactory pattern, using selector classes and test data in test setup where appropriate for a selection of classes - it created one uber-test to cover everything with no test data factory and inline soql queries.

Both AIs would hallucinate occasionally with using reserve words or methods more appropriate for Java (could be remedied by an .MD skill file or something, I guess) or ignore direct instructions like "use provided file version instead of your output for further work".

The same LWC part was both quite amazing in the "ready from first prompt" effect and the debugging/refactoring part when the LWC didn't work. AI started doubting everything and tried to re-write .js with approaches that had nothing to do with the actual problem: images inside the static resource .zip were saved by the user in .html format, not .png. Even though it touched in its assumptions on the subject of static resource structure, it never went beyond assumptions about leaflet.js and leaflet.css files.

## What you chose NOT to delegate to AI, and why

API keys were not handled to the AI for security purposes, nor was it fed actual supplier/activity data or live debug logs (only failing unit test logs), nor did it have access to SF org itself. Because it can potentially lead to LLM getting access to company data and credentials.
