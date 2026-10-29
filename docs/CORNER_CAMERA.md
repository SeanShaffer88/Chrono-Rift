# Corner camera yaw escape

`outputs/Corner-camera-mockup.svg` was authored before camera source changes. The diagram proposes a temporary side view when the intended view is blocked; it is not an in-game capture.

The rig owns intended_yaw independently of its applied pivot rotation. Keyboard/touch orbit changes intended yaw while preserving the existing 0.8-second manual priority; lock tracking updates intended yaw after that timeout. Pitch always remains within -60 to -35 degrees. The forced -72/-82 overhead recovery has been removed.

Each update resolves the existing pivot/lock shoulder anchor, then probes the intended view. Below 2.4 units of clearance it checks bounded offsets ±45, ±90, ±135 and 180 degrees using the same sphere query. Candidates mutate the query only. The smallest offset reaching the clearance target wins; otherwise a meaningful improvement is selected. A 0.35-unit side-switch margin reduces competing-side oscillation. No candidate search runs when the intended view is clear.

When clear, the yaw target returns to intended yaw. Applied yaw and pitch ease toward their targets, but clearance is checked again using that actual interpolated orientation every update. Retraction is immediate; outward extension remains eased. The previous near plane, sphere/margins, mask, lock shoulder offset and touch ownership are retained.

Persistence API: get_preferred_yaw() returns the intended view; restore_view(yaw,pitch) sets intended yaw and clamps pitch before snap(). snap() preserves intended yaw, clears transient rescue state, reanchors and resolves the view. SaveData keeps the existing yaw/pitch fields and serializes intended yaw; SaveSession calls restore_view. The pitch validator minimum now accepts -60 degrees, retaining the old upper validation range for compatibility. External camera code must use restore_view rather than directly assigning the pivot yaw before snap.

## Verification

Initial source work deferred execution at the user's request. Testing was later explicitly authorized. The pinned native suite now covers perpendicular corners, actual intermediate sphere clearance, immediate retraction/eased recovery, intended yaw persistence and the -60-degree JSON boundary. Isolated Android QA repeats corner/touch/lock/sphere checks across all three biomes. Actual native and Android captures are retained; see outputs/Validation-results.txt for exact commands and outcomes. Physical-phone performance is unmeasured.

Old overhead-rescue expectations and direct-pivot fixtures now use the explicit restore API. Future work should broaden generated-seed coverage, competing-side hysteresis and moving-obstacle cases, and profile Android query cost. Representative corner checks do not prove every possible floor configuration.
