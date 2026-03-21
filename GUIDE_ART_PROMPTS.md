# RediM8 Guide Art Prompt Pack

This pack is for illustrated guide art across the RediM8 library.

Use AI for:
- guide cover art
- concept frames
- base compositions
- environment and gear reference

Do not use raw AI output as the final source of truth for:
- first aid procedures
- safety-critical hand positions
- tool use sequences
- knot tying sequences
- evacuation step diagrams

For those, generate a base image, then redraw or clean it into a controlled final diagram.

## Art Direction

Target feel:
- civilian emergency field manual
- calm, technical, credible
- Australian conditions
- not cartoon, not whimsical, not "storybook"

Visual rules:
- clean technical illustration
- realistic object proportions
- simple backgrounds
- clear negative space for labels added later
- one primary action per frame
- limited palette: charcoal, stone, sand, muted olive, restrained red or amber safety accents
- no text rendered inside the image

## Master Style Block

Append this to nearly every prompt:

```text
technical emergency field manual illustration, Australian civilian emergency preparedness, clean linework, restrained flat-shaded realism, diagram-ready composition, accurate gear proportions, neutral charcoal and sand palette with limited red safety accents, calm controlled tone, clear negative space for labels, no cartoon styling, no children's book look, no glossy startup aesthetic
```

## Negative Block

Append this to nearly every prompt:

```text
no text, no watermark, no logo, no UI, no infographic labels, no comic style, no whimsical expressions, no exaggerated proportions, no fantasy gear, no extra fingers, no cluttered background, no cinematic bokeh, no glossy 3D render, no bright toy-like colors
```

## Universal Prompt Templates

Cover art:

```text
[SUBJECT], shown as a premium RediM8 guide cover, one strong focal scene, subtle environmental context, visual emphasis on readiness and clarity, not panic, [MASTER STYLE BLOCK], [NEGATIVE BLOCK]
```

Step diagram plate:

```text
[SUBJECT], three-panel procedural plate, each panel showing one clear action, consistent viewpoint, space left for later labels and arrows, accurate hands, tools, and gear, [MASTER STYLE BLOCK], [NEGATIVE BLOCK]
```

Cross-section diagram:

```text
[SUBJECT], technical cutaway view, side-on cross-section, simple terrain and material layers, clear structure, no text, built for later annotation, [MASTER STYLE BLOCK], [NEGATIVE BLOCK]
```

Flat-lay equipment plate:

```text
[SUBJECT], top-down flat lay of emergency equipment, evenly spaced items, accurate Australian household and field gear, diagram-ready composition, [MASTER STYLE BLOCK], [NEGATIVE BLOCK]
```

## Prompt Families For The Actual RediM8 Library

### Medical And First Aid

These should be generated as reference-only bases, then redrawn before shipping.

CPR Basics:

```text
adult CPR response scene, one rescuer kneeling beside an unconscious adult on a flat surface, AED kit visible nearby, calm emergency field manual style, clear body positioning for later annotation, technical medical training plate, Australian civilian setting, [MASTER STYLE BLOCK], [NEGATIVE BLOCK]
```

Major Bleeding Control:

```text
major bleeding first aid reference plate, direct pressure and pressure bandage application to a limb, gloved hands, medical supplies laid out clearly, no gore, high instructional clarity, [MASTER STYLE BLOCK], [NEGATIVE BLOCK]
```

Burns First Aid:

```text
burns first aid reference scene, cooling a minor burn under clean running water, safe domestic setting, controlled neutral composition, no dramatic injury detail, [MASTER STYLE BLOCK], [NEGATIVE BLOCK]
```

Fracture Immobilisation:

```text
fracture immobilisation reference plate, arm sling and padded support setup, side view, accurate triangular bandage placement, clean technical medical illustration, [MASTER STYLE BLOCK], [NEGATIVE BLOCK]
```

Snake Bite First Aid:

```text
snake bite pressure immobilisation reference plate, Australian field first aid, leg bandaging sequence with pressure bandage and splint, patient lying still, minimal background, accurate wrap direction and spacing for later redraw, [MASTER STYLE BLOCK], [NEGATIVE BLOCK]
```

Wound Cleaning And Dressing:

```text
wound cleaning and dressing reference plate, irrigation bottle, gauze, dressing, gloved hands, controlled tabletop setup, sterile field-manual look, no gore, [MASTER STYLE BLOCK], [NEGATIVE BLOCK]
```

Asthma Attack Response:

```text
asthma response reference scene, seated patient using reliever inhaler with spacer, calm domestic emergency context, accurate posture and device handling, [MASTER STYLE BLOCK], [NEGATIVE BLOCK]
```

### Evacuation And Household Action

Household Evacuation Quick Start:

```text
family evacuation readiness scene, go bags at the door, keys, medications, documents, pets prepared, vehicle staged outside, controlled pre-departure moment, not chaotic, [MASTER STYLE BLOCK], [NEGATIVE BLOCK]
```

Shelter-in-Place Steps:

```text
household shelter-in-place setup, interior room with sealed windows, radio, water, torch, medications, safe calm posture, operational domestic briefing style, [MASTER STYLE BLOCK], [NEGATIVE BLOCK]
```

Utility Shutoff Safety:

```text
home utility shutoff reference plate, gas, water, and electricity shutoff points shown in a simplified Australian house service area, clear mechanical components, technical manual style, [MASTER STYLE BLOCK], [NEGATIVE BLOCK]
```

Safe Cleanup After Disaster:

```text
post-disaster cleanup safety scene, gloves, boots, mask, long sleeves, debris sorting tools, cautious posture, realistic household cleanup equipment, [MASTER STYLE BLOCK], [NEGATIVE BLOCK]
```

Official Warning Monitoring:

```text
emergency monitoring scene, phone with cached alerts, battery radio, written notes, map, household checking official warnings calmly, field operations desk feel, [MASTER STYLE BLOCK], [NEGATIVE BLOCK]
```

### Water

Boil, Filter, and Disinfect Water:

```text
water treatment sequence plate, settle filter boil disinfect store workflow, side-by-side vessels and equipment, clean container logic, outdoors or blackout household setup, highly scannable arrangement, [MASTER STYLE BLOCK], [NEGATIVE BLOCK]
```

Store Water Safely in Heat:

```text
household water storage setup for extreme heat, sealed containers in cool shaded ventilated area, rotation-ready arrangement, Australian home preparedness context, [MASTER STYLE BLOCK], [NEGATIVE BLOCK]
```

Ration Water Without Dehydration:

```text
water ration planning scene, measured containers, daily allocation layout, notebook, bottle, cup, clear domestic emergency planning setup, [MASTER STYLE BLOCK], [NEGATIVE BLOCK]
```

Collect Rainwater Safely:

```text
safe rainwater collection setup, clean catchment surface feeding into covered container, first-flush separation implied by layout, technical field guide look, [MASTER STYLE BLOCK], [NEGATIVE BLOCK]
```

After-Flood Drinking Water Checks:

```text
post-flood water safety inspection scene, sealed bottles, contaminated floodwater kept separate, gloves and test materials visible, clear safe-versus-unsafe contrast without labels, [MASTER STYLE BLOCK], [NEGATIVE BLOCK]
```

### Bushfire, Fire, And Heat

Bushfire Leave-Early Plan:

```text
bushfire leave-early preparation scene, vehicle packed before smoke thickens, masks, water, pet carrier, documents, route map on bonnet, dry Australian suburban or regional setting, calm urgency, [MASTER STYLE BLOCK], [NEGATIVE BLOCK]
```

Fire Extinguisher Basics:

```text
fire extinguisher training plate, household extinguisher aimed at the base of a small contained training fire, safe stance, side view, clean instructional layout, [MASTER STYLE BLOCK], [NEGATIVE BLOCK]
```

Fire Blanket Use:

```text
fire blanket use reference plate, blanket being deployed over a small stovetop fire, kitchen context, accurate protective posture, no dramatic flames, [MASTER STYLE BLOCK], [NEGATIVE BLOCK]
```

Ember Attack Home Actions:

```text
ember attack home preparation scene, gutters checked, hoses staged, vents screened, outdoor furniture moved, ember-aware Australian home exterior, [MASTER STYLE BLOCK], [NEGATIVE BLOCK]
```

Smoke Exposure Reduction:

```text
smoke exposure reduction household setup, closed windows, towel seals, filtered room setup, masks, air-clean area, safe indoor refuge feel, [MASTER STYLE BLOCK], [NEGATIVE BLOCK]
```

Heat Exhaustion vs Heat Stroke:

```text
heat illness comparison reference plate, two side-by-side human figures with contrasting body language and cooling response context, technical public health poster style without text, [MASTER STYLE BLOCK], [NEGATIVE BLOCK]
```

Cool a Home Without Power:

```text
passive cooling setup in a blackout, shaded windows, cross-ventilation, reflective coverings, water and fans staged, hot Australian home context, [MASTER STYLE BLOCK], [NEGATIVE BLOCK]
```

### Storms, Cyclones, And Flood

Severe Storm Room Setup:

```text
storm-safe room setup, interior room away from windows, torch, radio, water, helmets, blankets, documents, family sheltering calmly, [MASTER STYLE BLOCK], [NEGATIVE BLOCK]
```

Cyclone Pre-Landfall Actions:

```text
cyclone preparation scene, outdoor items secured, windows protected, supplies staged indoors, tropical Australian home context, controlled pre-impact atmosphere, [MASTER STYLE BLOCK], [NEGATIVE BLOCK]
```

Generator Safety After Storm:

```text
portable generator safety scene, generator outdoors away from windows, extension lead routed safely, rain cover positioned correctly, no enclosed use, technical household safety illustration, [MASTER STYLE BLOCK], [NEGATIVE BLOCK]
```

Downed Powerline Safety:

```text
downed powerline hazard scene, wide exclusion distance around fallen line near road or flood edge, bystanders held back, emergency-safety field manual composition, [MASTER STYLE BLOCK], [NEGATIVE BLOCK]
```

Flood Evacuation Timing:

```text
flood evacuation readiness scene, vehicle leaving early before road inundation, bags loaded, route checked, elevated terrain in background, [MASTER STYLE BLOCK], [NEGATIVE BLOCK]
```

Turn Around, Don't Drown:

```text
vehicle stopped before flooded roadway, water depth uncertain, driver decision point, strong composition showing refusal to enter floodwater, [MASTER STYLE BLOCK], [NEGATIVE BLOCK]
```

Sandbag Placement Basics:

```text
sandbag placement technical plate, doorway barrier with overlapping sandbags, side and front view logic, flood protection setup, [MASTER STYLE BLOCK], [NEGATIVE BLOCK]
```

### Shelter, Fieldcraft, Navigation, Signal

Safe Tarp Shelter Setup:

```text
tarp ridgeline shelter technical plate, Australian bush campsite, tensioned tarp, drainage slope, sleeping area raised from wet ground, side-on structure clarity, [MASTER STYLE BLOCK], [NEGATIVE BLOCK]
```

Campfire Safety Without Mains:

```text
contained outdoor campfire safety scene, cleared fire ring, water bucket, shovel, safe spacing from vegetation, controlled manual-plate feel, [MASTER STYLE BLOCK], [NEGATIVE BLOCK]
```

Improvised Signal Methods:

```text
improvised emergency signalling plate, whistle, mirror, torch, ground marker, high-contrast layout, field communication tools shown clearly, [MASTER STYLE BLOCK], [NEGATIVE BLOCK]
```

Basic Knot Selection:

```text
knot selection reference plate, bowline, clove hitch, reef knot on rope samples, neutral background, highly legible rope paths for later redraw, technical outdoor manual style, [MASTER STYLE BLOCK], [NEGATIVE BLOCK]
```

Navigate with Map and Compass:

```text
map and compass navigation plate, topographic map, baseplate compass, bearing check, hands and tools shown from a readable top-down angle, [MASTER STYLE BLOCK], [NEGATIVE BLOCK]
```

Route Planning Without GPS:

```text
offline route planning scene, printed map, notebook, compass, marked checkpoints, fuel and water notes, field planning desk aesthetic, [MASTER STYLE BLOCK], [NEGATIVE BLOCK]
```

Night Navigation Safety:

```text
night navigation safety scene, red-light torch, map, controlled movement, reflective markers, low-light but readable field-manual composition, [MASTER STYLE BLOCK], [NEGATIVE BLOCK]
```

Vehicle Trip Check-In Routine:

```text
remote travel check-in routine scene, 4WD, paper route plan, radio or phone, departure checklist, water and recovery gear visible, Australian outback context, [MASTER STYLE BLOCK], [NEGATIVE BLOCK]
```

### Blackout Food And Cooking

Pantry Damper on a Hotplate:

```text
blackout damper cooking plate, simple dough, covered pan on hotplate, minimal pantry ingredients arranged clearly, practical field-kitchen style, [MASTER STYLE BLOCK], [NEGATIVE BLOCK]
```

Skillet Bread Without an Oven:

```text
skillet bread method plate, dough in covered skillet, stovetop setup, simple blackout cooking environment, clean overhead instructional composition, [MASTER STYLE BLOCK], [NEGATIVE BLOCK]
```

Blackout Scones from a Basic Pantry:

```text
blackout pantry scones plate, flour, milk, butter, simple mixing and pan-cooking setup, rugged household emergency kitchen style, [MASTER STYLE BLOCK], [NEGATIVE BLOCK]
```

### Food Growing

Grow Salad Greens Fast:

```text
raised-bed salad greens guide art, compact productive bed with fast-growing leafy greens, spacing visibly organised, suburban Australian backyard context, [MASTER STYLE BLOCK], [NEGATIVE BLOCK]
```

Start Seeds in Small Spaces:

```text
small-space seed starting setup, trays, pots, labels left blank, window light or compact growing area, orderly propagation layout, [MASTER STYLE BLOCK], [NEGATIVE BLOCK]
```

Grow Potatoes in Bags:

```text
potatoes in grow bags cross-section plate, layered soil and plant growth stages, practical home-food resilience style, [MASTER STYLE BLOCK], [NEGATIVE BLOCK]
```

### No-Infrastructure Survival Skills

Bow Drill Fire:

```text
bow drill fire-starting reference plate, spindle, hearth board, bow, bearing block, tinder bundle, side-by-side tool layout plus action frame, survival manual style, [MASTER STYLE BLOCK], [NEGATIVE BLOCK]
```

Hand Drill Fire:

```text
hand drill fire-starting reference plate, spindle and hearth board with ember collection area, accurate hand positions for later redraw, sparse natural background, [MASTER STYLE BLOCK], [NEGATIVE BLOCK]
```

Flint and Steel:

```text
flint and steel fire-starting plate, striker, char material, tinder bundle, spark capture moment, technical survival illustration, [MASTER STYLE BLOCK], [NEGATIVE BLOCK]
```

Debris Hut Shelter:

```text
debris hut shelter cross-section, layered debris insulation over frame, small heat-efficient sleeping cavity, cold-weather bush survival manual look, [MASTER STYLE BLOCK], [NEGATIVE BLOCK]
```

Lean-To Shelter:

```text
lean-to shelter construction plate, angled frame, windward orientation, bedding and ground insulation visible, practical bushcraft manual style, [MASTER STYLE BLOCK], [NEGATIVE BLOCK]
```

Ground Insulation Critical:

```text
ground insulation survival plate, sleeper separated from cold ground using leaves, grass, branches, side-on cross-section, technical thermal logic illustration, [MASTER STYLE BLOCK], [NEGATIVE BLOCK]
```

Rainwater Runoff Collection:

```text
rainwater runoff capture setup, tarp or bark runoff feeding into improvised container, natural terrain context, technical fieldcraft illustration, [MASTER STYLE BLOCK], [NEGATIVE BLOCK]
```

Waste Disposal Distance Rules:

```text
wilderness sanitation distance diagram, latrine area separated from shelter and water source, terrain overview from above, field-manual planning plate, [MASTER STYLE BLOCK], [NEGATIVE BLOCK]
```

Sun Navigation Southern Hemisphere:

```text
sun navigation reference plate for Australia, shadow stick method, simple terrain context, morning and afternoon sun positions implied visually, technical survival guide style, [MASTER STYLE BLOCK], [NEGATIVE BLOCK]
```

Southern Cross Navigation:

```text
Southern Cross navigation reference scene, southern night sky over Australian landscape, constellation orientation for south finding, minimal clean astronomical survival-manual style, [MASTER STYLE BLOCK], [NEGATIVE BLOCK]
```

Ground Signals for Air Rescue:

```text
ground-to-air rescue signal scene, large high-contrast ground markers arranged in open terrain, aerial-readability emphasized, practical survival signalling illustration, [MASTER STYLE BLOCK], [NEGATIVE BLOCK]
```

Vehicle Stay vs Leave:

```text
vehicle survival decision scene, stranded vehicle in remote Australian terrain with shelter value, visibility, water, and route considerations implied through composition, field manual style, [MASTER STYLE BLOCK], [NEGATIVE BLOCK]
```

Vehicle Visibility Signalling:

```text
stranded vehicle visibility signalling plate, hazard marker, reflective material, open bonnet or high-visibility signal placement, remote road context, [MASTER STYLE BLOCK], [NEGATIVE BLOCK]
```

## Model-Specific Guidance

If using a very strong image model:
- ask for "technical illustration" or "field manual plate", not "beautiful art"
- ask for "space for later labels"
- specify camera/viewpoint: top-down, side-on, or cross-section
- ask for one action only if the model starts overcomplicating scenes

If the result looks too soft:
- add "sterile technical linework"
- add "public safety manual"
- add "training plate"
- add "diagram clarity over mood"

If the result looks too cinematic:
- add "flat educational lighting"
- add "minimal background"
- add "cutaway / orthographic / top-down"

If the result looks too childish:
- add "adult field manual"
- add "serious emergency training material"
- add "no cute style, no storybook illustration"

## Recommended Workflow

1. Generate 4 to 8 concepts per guide.
2. Pick the best composition, not the prettiest image.
3. Regenerate one tighter version with the same structure.
4. Redraw the final instructional diagram in a controlled style.
5. Use AI outputs directly only for cover art or non-procedural support art.
