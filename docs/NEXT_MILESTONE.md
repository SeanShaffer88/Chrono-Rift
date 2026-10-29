# Next milestone: enemy combat and camera feel

User approved this priority after the visual, playable roster and collector pass.
Status: implemented; regression and Android validation results are documented in
COMBAT_CAMERA.md and the release notes.

## Playable combat slice

Implement one original enemy with patrol, awareness, pursuit, an attack windup
that clearly signals danger, active damage frames, recovery, stagger and death.
Use existing hitbox/hurtbox and dodge i-frame rules. No attack through walls,
double hits from one swing, post-death damage or lost guard/key progression.
Keep the three player characters on shared combat timings for this milestone.

## Camera

Tune camera distance, pitch and follow response for rooms and narrow corridors.
Prevent wall clipping and abrupt camera pops. Test lock-on acquisition, switching
and release when a target dies or leaves reach. Verify keyboard and touch input.
Create a mockup before changing camera controls, HUD or enemy warning visuals.

## Acceptance

- One dungeon encounter can be won or lost through clear attacks and dodges.
- Attacks and stagger respect damage acknowledgement and durability rules.
- Lock-on and camera remain usable against walls and through narrow corridors.
- Character switching, town return and companion collection remain correct.
- Regression suites pass; inspect graphical captures and Android emulator play.
- Build a debug APK; publish through a passing GitHub PR.

Following priorities: coherent animated models, persistent save/load, then pickup
feedback and broader content. Avoid adding more progression systems before this
combat slice is enjoyable and stable.
