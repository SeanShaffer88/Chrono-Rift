# Visual cohesion pass

The target sheet is `images/visual-cohesion-concept.png`; its exact generation prompt is `visual-cohesion-prompt.txt`. The concept guides a modest native geometry pass, not a promise of cinematic rendering.

Characters share cached flat-shaded head and swept hair meshes, with connected hair/hood masses, compact facial features and fitted costume silhouettes. Riftwarden uses eight linked rings and one closed crescent blade. All additions are cosmetic; actor collision and combat hitboxes remain authoritative.

Dungeon art uses warm split flagstones over the existing floor, blue-slate staggered masonry, and solid backing outside walkable cells. Backing runs cover the expanded layout bounds exactly once. Distant silhouettes span the correct axis on each side. No decoration adds collision or navigation changes.

The player camera defaults to -40 degrees and manual orbit clamps to -60 through -35 degrees. Obstruction rescue can temporarily raise its downward pitch to -82 degrees, then restores the preferred pitch. Existing lock, touch ownership and immediate obstruction retraction are retained.

Inspector tuning: character camera distance/height remain on character_base; dungeon ambient lighting and background remain on DungeonManager/WorldEnvironment. Geometry dimensions and colors live in stylized_character.gd and environment_art.gd. Keep new decoration outside walkable combat lanes.

Validation uses the pinned Godot engine and existing native suites. The dungeon fixture captures four extreme walkable corners in four yaw directions using the actual player camera. At extreme rescue angles, the solid blue-slate backing has broad flat tops; these views remain less detailed than the concept. Physical-phone performance is unmeasured.
