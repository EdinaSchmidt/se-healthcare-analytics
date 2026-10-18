## Access

**1. How close is each region to the care guarantee?**
Measure the share of calls and chats answered the same day, and the share of patients assessed within 0 and within 3 days, by region and month since July 2025.

**2. Is poor access a regional problem or a health-centre problem?** 
Compare the spread between regions with the spread between centres inside the same region. This is analytically the most interesting access question, and it matters to Kry. If centres within a region differ wildly, the cause is local operations, not funding.

## Quality

**3. Where do patients rate their care lowest, and on which dimensions?** 
Use the NPE dimensions, such as accessibility, involvement and emotional support. Report at region level using SKR's own aggregates, and at centre level.

## Cost

**4. How has health-centre cost per inhabitant developed from 2020 to 2025, and how much does it vary between regions?** 
Build the cost from the cost_role seed. If you want to show care, add a small CPI seed so you can show real terms alongside nominal.

## The connecting questions (the payoff)

**5. Do centres with faster access get better patient ratings?**
This uses 2025 data, matched at centre level. It requires the name-to-HSA-ID mapping, which makes it your hardest engineering problem and your best story. Report the match rate openly.

**6. Do regions that spend more deliver better access or experience?**
Compare 2025 cost per inhabitant against care-guarantee performance and NPE scores.
