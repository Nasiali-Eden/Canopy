# Environmental Section Research

## Scope
This brief combines:
- What the current Canopy codebase already models for environmental operations.
- What a Kenya-first environmental section should cover in practice.
- A Nairobi pilot assumption, because the repo repeatedly anchors environmental work to Kenya, Nairobi, Kibera, Mathare, Langata, and Mombasa.

## Core Finding
The environmental section is not just a directory of organizations. The repo already implies a full operating system for:
- discovering and tagging sites,
- mapping collection territory,
- posting material demand,
- assigning collectors,
- logging verified handoffs,
- tracking dumpsite transformation,
- tracking tree survival,
- issuing evidence-backed credits.

That means our research and content design should be organized around processes, not only around organization profiles.

## What The Repo Already Supports

### 1. Environmental org classification
The codebase already separates environmental actors by:
- sector and org type in `assets/organization_taxonomy.json`
- environmental capability type in `assets/environ_ops/env_shared_types.json`
- services offered in `assets/canopy_org_services_taxonomy.json`

Current organization categories already include:
- recyclers
- cleanup organizations
- conservation and restoration groups
- waste-to-art creators
- upcyclers
- clean energy from waste groups

Current service tags already include:
- `svc_cleanup_drive`
- `svc_tree_planting`
- `svc_waste_collection`
- `svc_marketplace_listing`
- `svc_volunteer_programme`
- `svc_advocacy_campaign`

This is important because "tagging" in Canopy already exists at three levels:
- org taxonomy tagging
- service tagging
- spatial map tagging

### 2. Spatial tagging already exists in two layers
There are two separate map layers in the repo:

Layer A: community map pins in `lib/Organization/Map/org_map_ops.dart`
- `dumpsite`
- `recycling_dropoff`
- `tree_site`
- `cleanup_event`
- plus common civic pins like `water_point`, `school`, `market`, `community_center`

Layer B: environmental operations map entities in `assets/environ_ops/env_territory_models.json`
- `collectionZones` for operational polygons
- `siteMarkers` for operational points
- `processing_hub`
- `drop_off_point`
- `active_collection_site`

Interpretation:
- The community map is good for discovery, community reporting, and public tagging.
- The Env Ops map is good for operations, verification, routing, and credit evidence.

### 3. Materials are already standardized
The repo already has a controlled material taxonomy in:
- `assets/environmental/material_types.json`
- `assets/environ_ops/env_market_models.json`
- `assets/environ_ops/env_shared_types.json`

Current categories include:
- plastics
- metals
- glass
- paper and cardboard
- rubber and composites
- reclaimed wood
- textiles
- electronics

Plastic subtypes already include:
- PET clean
- PET contaminated
- HDPE natural
- HDPE mixed
- LDPE film
- carrier bags
- soft film
- PP mixed
- PVC
- polystyrene

This means collection sites should never be tagged only as "plastic." They should also support subtype tagging so pricing, buy orders, and credit logic can work.

## Recommended Process Model

### A. Dumpsite process
For Canopy, a dumpsite should be treated as a lifecycle, not a pin.

Recommended process:
1. Discovery
2. Public map pin creation
3. Managing-org linking
4. Baseline evidence capture
5. Intervention event
6. Follow-up verification
7. Transformation status update
8. Long-term monitoring or failure logging

Minimum fields:
- site name
- GPS point
- surrounding area or neighborhood
- managing organization
- current status: active, monitored, under intervention, transformed, failed, closed
- waste type profile
- nearby risk receptors: schools, homes, waterways, markets
- baseline photos
- intervention date
- 30-day follow-up
- 90-day follow-up
- whether site held or relapsed

Why this matters:
- The repo's `transformation_records` and `dumpsite_transformation` credit model already assumes staged verification and honest failure recording.
- A dumpsite is therefore not "cleaned" in one event; it is only transformed if it still holds after follow-up.

### B. Plastic collection site process
The repo already implies this chain:
1. Organization maps a zone.
2. Organization creates or tags a hub or drop-off point.
3. Organization posts a buy order for a material type.
4. Collectors respond or deliver.
5. Handoff is weighed, paid, geotagged, and linked to a zone and site.
6. Verified volume contributes to impact stats and credit eligibility.

Minimum fields for a plastic collection site:
- site type: drop-off, hub, roaming collection point, buy-back center
- accepted material categories
- accepted plastic subtypes
- price per kg, if public
- operating hours
- weighing capacity
- storage capacity
- M-Pesa or cash payout method
- linked organization
- linked zone
- whether household delivery is accepted
- whether org fleet can pick up

Operational note:
- A collection site should support both public discovery and internal proof.
- Public users need "where can I take my plastic?"
- Verified workflows need "was this material actually delivered, weighed, and matched to a zone and evidence chain?"

### C. Tree planting process
The tree flow in the repo is stricter than a normal volunteer event model.

Current logic:
1. Tree is planted and GPS-pinned.
2. Species is selected from a controlled list.
3. Tree becomes a permanent record.
4. Monthly photo confirmations are added.
5. GPS at update must be within tolerance of planting location.
6. Survival at 90 days determines credit eligibility.

Implication:
- Canopy should not treat tree planting as "event completed" when seedlings go into the ground.
- The real metric is survival, not planting count.

Minimum fields:
- tree ID
- species
- common name
- planting date
- planter or lead org
- GPS location
- area and optional zone
- next update due date
- latest photo
- health status
- survival confirmed at 90 days or not

### D. Organization onboarding process
Environmental organizations should be modeled in stages:
1. Register org
2. Assign environmental taxonomy
3. Assign active services
4. Add facilities and map pins
5. Define territory
6. Enable market activity
7. Enable collectors and handoffs
8. Enable verified impact exports

This staged model fits the repo's verification tiers:
- registered
- verified
- impact partner
- credit issuer

## Suggested Tagging System

### Tagging layer 1: org identity tags
Use for search, filters, and profile classification.

Recommended tags:
- recycler
- waste collector
- plastic recycler
- cleanup org
- dumpsite intervention org
- conservation body
- tree nursery
- tree planting org
- community forest group
- waste picker collective
- upcycler
- e-waste recycler
- circular economy advocate

### Tagging layer 2: service tags
Use for what the org actually does now.

Recommended tags:
- cleanup drive
- waste collection service
- plastic buy-back
- school collection partnership
- household collection
- tree planting programme
- nursery management
- ecosystem restoration
- volunteer programme
- advocacy campaign

### Tagging layer 3: site tags
Use for map pins and operations.

Recommended tags:
- dumpsite
- informal dumpsite
- transfer point
- processing hub
- drop-off point
- buy-back center
- active collection site
- tree planting site
- tree nursery
- cleanup event site
- riverbank hotspot
- school-adjacent risk site

### Tagging layer 4: material tags
Use for market logic, fleet handoffs, and collection matching.

Recommended fields:
- category
- subtype
- grade
- contamination level
- units
- recurring demand yes or no

### Tagging layer 5: verification tags
Use for trust and evidence.

Recommended tags:
- community reported
- org submitted
- pending verification
- verified GPS
- verified photos
- 30-day confirmed
- 90-day confirmed
- failed follow-up
- credit eligible
- credit issued

## Kenya And Nairobi Context

### National policy signals
Kenya's environmental system is already pushing toward the exact kind of workflows Canopy is modeling:
- NEMA positions Extended Producer Responsibility as a lifecycle obligation for producers, including post-consumer handling.
- NEMA explicitly maintains resources for plastic bag enforcement, EPR, circular economy, and solid waste management.
- Kenya's plastic carrier bag ban remains a major enforcement anchor.
- The Ministry of Environment, Climate Change and Forestry frames its mission around sustainable management, land restoration, and community forestry.

Useful implications for product design:
- environmental records should connect producers, collectors, processors, and communities
- plastic workflows should support take-back and compliance evidence
- tree workflows should connect planting to stewardship and restoration, not only publicity

### Dumpsite reality
For Nairobi research, Dandora remains the reference case because it shows the full problem:
- heavy waste inflow
- informal recovery by waste pickers
- smoke and health harm
- nearby schools and residents as risk receptors
- a mix of public-system failure and informal circularity

That means Canopy should model dumpsites as:
- environmental hazards
- livelihood sites
- intervention sites
- verification sites
- policy and justice sites

### Tree initiative reality
Kenya's national tree-growing push creates a strong backdrop for local Canopy work:
- National Tree Growing Day was launched on November 13, 2023.
- The national goal is 15 billion trees by 2032.

For Canopy, this means local tree records can connect:
- community volunteering
- school programs
- faith and neighborhood groups
- nursery supply chains
- restoration evidence

## Local Organizations Worth Tracking
These are good reference organizations for Kenya-first environmental mapping and partnership logic.

### Green Belt Movement
Why it matters:
- foundational Kenyan tree-planting and environmental justice organization
- combines reforestation, livelihoods, advocacy, and women-centered community organizing
- useful reference for long-term stewardship rather than one-off planting

### Seedballs Kenya
Why it matters:
- strong fit for degraded-land restoration and low-cost seeding workflows
- useful for aerial seeding, indigenous species campaigns, and public participation models
- useful reference for campaign-style restoration

### TakaTaka Solutions
Why it matters:
- models vertically integrated waste operations
- collects, sorts, recycles, composts, and works with waste pickers
- useful reference for buy-back center and recovery-chain design

### Ecopost
Why it matters:
- converts waste plastic into durable products
- publicly states active purchasing of plastic waste and calls out youth groups, women groups, waste yards, county officials, and collection companies as suppliers
- useful reference for processor-side demand signals

### Waste picker organizations and collectives
Why they matter:
- they are not just beneficiaries; they are core operators in the recycling chain
- the Dandora context shows that informal recovery already powers a major part of the circular system
- Canopy should represent collectors, picker groups, and welfare associations as first-class actors, not footnotes

## Product Recommendations For The Environmental Section

### 1. Separate discovery from verification
Use:
- community pins for discovery
- Env Ops records for proof

Do not force one record type to do both jobs.

### 2. Treat dumpsite transformation as staged evidence
Required stages:
- baseline
- intervention
- 30-day hold
- 90-day hold

### 3. Treat tree planting as survival tracking
Primary metrics should be:
- trees planted
- trees current
- trees overdue
- trees alive at 90 days
- trees dead or missing

### 4. Support informal-to-formal transition
Environmental work in Kenya often starts informally.
The product should support:
- unverified site reports
- community-submitted pins
- linking to later registered organizations
- collector histories and payment logs
- eventual compliance and credit pathways

### 5. Model nearby risk and benefit
For each dumpsite or collection site, also capture:
- nearby schools
- nearby homes
- nearby waterways
- nearby markets
- whether the site creates income opportunities
- whether it creates public health risks

### 6. Add explicit "managing organization" and "operating organization"
These may differ.
For example:
- a community reports a dumpsite
- a county manages it
- a CBO runs the cleanup
- a recycler buys recovered plastics

## Immediate Research Gaps
These are the main gaps still worth filling before final product copy or schema lock:
- list of active county-approved drop-off and recycling points by area
- county-specific dumpsite status and closure plans
- named waste picker groups by settlement
- local nursery partners by ward
- school and church tree programmes by neighborhood
- which orgs operate as collectors versus processors versus both
- which organizations can provide follow-up verification, not just event photos

## Suggested Next Deliverables
The strongest next step would be a structured dataset, not another narrative memo.

Recommended outputs:
- `environmental_org_taxonomy_expanded.json`
- `environmental_site_tagging_schema.json`
- `environmental_process_flows.md`
- `nairobi_environmental_orgs_seed.csv`

## Sources
Internal repo sources:
- `assets/organization_taxonomy.json`
- `assets/canopy_org_services_taxonomy.json`
- `assets/environmental/material_types.json`
- `assets/environ_ops/env_shared_types.json`
- `assets/environ_ops/env_territory_models.json`
- `assets/environ_ops/env_fleet_models.json`
- `assets/environ_ops/env_market_models.json`
- `assets/environ_ops/env_trees_models.json`
- `assets/environ_ops/env_verified_models.json`
- `lib/Organization/Map/org_map_ops.dart`

External sources:
- Green Belt Movement: https://www.greenbeltmovement.org/
- Seedballs Kenya: https://www.seedballskenya.com/
- TakaTaka Solutions: https://takatakasolutions.com/
- Ecopost: https://ecopost.co.ke/
- National Environment Management Authority (NEMA): https://nema.go.ke/
- NEMA Plastic Bags Ban page: https://nema.go.ke/ban-on-plastic-carrier-bags/
- Ministry of Environment, Climate Change and Forestry: https://environment.go.ke/
- AP on Kenya's National Tree Growing Day and 15 billion tree goal: https://apnews.com/article/c0b82a93b185d8b47e2867e4f3ca7b9f
- AP on Dandora and school-led bamboo planting: https://apnews.com/article/d75d555dbeebd9c7f18b06a02889fac7
- Guardian on Dandora waste pickers: https://www.theguardian.com/global-development/2026/mar/08/waste-pickers-kenya-recycling-dandora-rubbish-dump

## Assumptions
- Local geography is Kenya-first, with Nairobi as the immediate pilot context.
- "Tagging" should cover map pins, operational records, org classification, services, materials, and verification state.
- The environmental section should be designed around traceable operations and evidence, not only storytelling.
