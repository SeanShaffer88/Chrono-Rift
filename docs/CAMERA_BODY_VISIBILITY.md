# Camera body visibility

A reproducible steep corner had a clear six-metre camera arm while masonry hid
the boots and torso. Camera-arm clearance alone did not establish visibility.
Matched frozen renders identified both the coping overhang and a physical wall
between the camera and the lower body. This is not an overhead-pitch change.

The rig retains the manual -60 to -35 degree range, intended yaw persistence,
lock/manual timeout and sphere safety. Six cached art-local probes follow the
current art transforms: four conservative boot-envelope corners and two tunic
side points, or actual spherical-shell slice extrema for Devourer. Lower points
are clamped above the floor during cosmetic dodge poses. These are a visibility
envelope, not a claim that every point lies on the rendered surface.

Current-view rays start at the actual camera, including a shortened arm. An
obstruction triggers one immediate candidate search per rescue episode; repeat
searches run at most 10 Hz. Eight unique yaw candidates are ranked by all-six
visibility plus usable arm, then angle and side stability. Partial candidates
rank lower-body clearance first. Three consecutive preferred-clear samples are
required before restoring the intended view while the incumbent remains safe.
An unsafe incumbent yields immediately to a clear preferred view; the episode
stays latched until confirmation completes. Actual sphere retraction remains
unthrottled. Profiles scan meshes only at initialization and reuse node-local
points and a ray-query object during play.

Only coping boxes move: their top is 2.80 m and their inner face is 1.005 m from
the walkable-cell centre. Other masonry and collision stay unchanged. Slate-cap
facets receive baked 0.88–1.06 tone variation; vertices, coverage and height
ceiling stay unchanged. No fades, proxies, new physics layers or shaders.

The measured Foundry corner selects -45 degrees instead of +45: torso/limbs and
boots are fully visible in the paired masks. Broad Riftwarden cape panels can
still overlap walls at steep angles. This bounded heuristic cannot guarantee
every accessory or every surface is visible in all possible scenes.

Native regressions cover all profiles, moving art, alternating visibility,
continuous-orbit query bounds, transient short arms, save yaw, sphere safety and
the existing house doorway/interior. Android evidence and emulator-only timing
are recorded in the task results; they are not physical-phone performance data.
