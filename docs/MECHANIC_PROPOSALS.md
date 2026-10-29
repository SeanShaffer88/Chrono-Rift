Chrono Rift: core-loop review and five optional mechanic proposals

This is design advice, not approval to implement five more systems.

CORE LOOP AND AUDIENCE
The intended loop is: explore a procedural dungeon, read and fight enemies, manage
weapon condition, collect town parts, defeat the key guard, then restore physical
buildings and residents. Restored people reveal requests and reopen services;
weapon preparation and build-up support the next expedition. The three heroes
currently share combat and keep distinct starter weapons and inventories.

Based on the user's Dark Cloud reference and controller-style Android controls,
the audience is players who enjoy deliberate action RPG exploration and the
satisfaction of bringing a place back to life. This is an inference from the
approved direction, not market research. The tone is hopeful, colorful fantasy
with atmospheric ruins and an optional darker hero silhouette.

Existing foundations include attack commitment, dodge i-frames, weapon wear,
protected starters, build-up data, automatic nearby collection, guard/key gates,
same-floor town return, multipart Georama, resident requests and services.
Those should not be relabeled as new mechanics. The current limits matter:
one enemy type, basic animation/art, no disk save/load and incomplete deeper
weapon progression. Finish the environment pass and reliable saving before
expanding progression. The following five are candidates, not a feature backlog
that must all ship.

1. FOOTWORK COUNTERS
How: Evading a clearly telegraphed strike at the last readable moment opens a
brief counter opportunity on that enemy. The next ordinary attack can interrupt
its recovery; it does not grant a long invulnerability chain or huge damage bonus.
An ordinary dodge remains useful and missing the precision window adds no penalty.
Why it fits: Existing windup, active, recovery and dodge states already teach
timing. This adds mastery without extra currencies or repeated farming.
Integration: Detect a near miss during the enemy's active window; attach a short
counter flag to that enemy, cleared by one accepted hit, death or expiration.
Use the existing attack input and acknowledged-hit durability rules. Tune timing
for touch input and offer a wider optional accessibility window.

2. RESETTABLE ROOM CONTRAPTIONS
How: Some rooms contain one readable mechanism: rotate a stone divider to split
an enemy approach, lower a bridge to open a flank, or redirect a brazier to reveal
a side passage. Players can use it tactically or take the normal combat route.
Why it fits: The game promises a physical 3D world. These turn rooms into places
to understand rather than empty corridors between pickups.
Integration: Author small encounter modules for the procedural generator. Tag
their collision/navigation changes explicitly, retain a guaranteed main route,
and reset mechanisms safely on retry. Never put mandatory town parts behind a
consumable, a hidden one-shot trick, or an unsolvable mechanism state.

3. READABLE ROUTE FORKS
How: At selected floor junctions, show two honest alternatives: a shorter exposed
route with a tougher encounter, or a longer route with cover and smaller fights.
The player can change their mind before committing. Both routes reach progression.
Why it fits: HP, durability and room positioning already matter. Choosing a route
turns preparation into a decision without inventing another resource economy.
Integration: Add optional connected branches to the existing seeded layout and
verify both with reachability tests. Use visible geometry and enemy silhouettes
as clues. Do not tie required restoration pieces to a riskier branch or scale
rewards to encourage repeated runs of the same easy route.

4. RESIDENT FIELD STORIES
How: A restored villager occasionally opens a short, authored dungeon encounter
connected to their life: recover a damaged sign from a collapsed workshop, or
solve a mill-channel problem that changes a place back in town. Each is a finite
story and encounter, not 'kill 50 enemies' or a repeatable daily contract.
Why it fits: Restoring actual people should change the adventure and make the
village emotionally meaningful. This extends in-person dialogue beyond a service
flag or a placement preference.
Integration: A housed resident's dialogue unlocks a small encounter definition;
completion changes their dialogue and one town detail. Optional cosmetic/story
outcomes are permanent and deterministic. Basic shops, repair and required floor
progression remain available without completing every optional story.

5. RESIDENT-TAUGHT WEAPON SIDEGRADES
How: A relevant restored resident offers a short, safe practice challenge that
teaches one optional technique: a planted wrench strike trades lunge for control,
a swordsman step-cut trades damage for repositioning, or a short chain pull
trades damage for a small opening against eligible enemies.
Why it fits: Town restoration feeds back into combat mastery. Heroes can gradually
gain identity after the shared-combat prototype is stable, without requiring
hours of XP accumulation or making one character strictly superior.
Integration: Store learned technique flags separately from individual weapons;
build-up and character switching preserve them. Reuse existing inputs through
an explicit stance/loadout choice rather than adding many touch buttons. Preview
the tradeoff, allow free switching in safety, and keep the base combo viable.

PRIORITY AND FAIRNESS
Prototype Footwork Counters first after the current foundations are solid; it is
small and tests whether an added mechanic actually improves combat. Room
Contraptions are the strongest next exploration experiment. Add the remaining
ideas only if playtests justify them. Avoid stacking all five at once.

No proposal depends on daily streaks, expiring rewards, loot-box odds, paid power,
artificial scarcity or repeat-grind progression. Required village restoration
must remain achievable through ordinary play. Test accessibility and comprehension,
not retention pressure. These ideas need mockups and scope approval before code.
