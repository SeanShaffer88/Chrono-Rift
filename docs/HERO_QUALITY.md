# Paper hero quality

The original three heroes now use cached closed faceted head, hair, sleeve, bracer, boot and folded cloth volumes. Face details fit actual head triangles, keeping shallow eyes/brows/lids and a compact wedge nose attached. Infiltrator retains his sword and body-mounted back shield, with a slouched volumetric cap and blond fringe. Shadowblade retains his greatsword, with offset tapered silver locks, lapels and split tails. Riftwarden retains his red energy sword, ridged mask, folded hood, shoulder cowl and overlapping crimson cape.

Hero-only geometry is separate from the earlier fallback forms and material function used by enemy club art. Existing node names, motion roles, attachments, weapon pivots, hitbox geometry, collision and combat timing remain. Closed geometry and bounded caches are checked natively; repeated switching checks node count and shield ownership. Actual before/after captures use identical camera and light for the original three heroes.

Battlemage adds a bent pointed tan hat, blue folded coat, recessed dark face, two warm opaque eyes and protected Battlestaff. He uses the same melee controller and balance. His taller hat uses a slightly raised capture focus; it is not a directly matched before/after comparison. Devourer is documented separately in DEVOURER.md.

The menu uses two columns at viewport width 680 or above and one below, with wrapping labels, a scrolling card area and pinned Close. Its secret card appears only after the floor-six clear unlock. Native narrow-screen capture verifies a390-pixel viewport; Android validation uses the configured landscape orientation.

No new dependencies, downloaded assets, texture/shader/light systems or per-frame geometry generation were added. Models remain simple native prototypes, visibly less detailed than the aspirational concept boards. Emulator checks do not measure physical-phone performance. Future ranged identities and core upgrades remain plans only in COMBAT_ROADMAP.md.
