# Fixed gameplay view and localized walls

Dungeon play and town walking use the approved fixed view: orthographic
KEEP_HEIGHT size 14, yaw 45 degrees, pitch -55 degrees and follow distance 14.
The angle and framing were selected from native size-12/14/16 comparisons using
the existing art. They are not claimed as another game's internal settings.
Georama editing starts with the same isometric framing, while retaining orbit, tilt, pan and pinch controls. User adjustments persist during editing; returning from walking restores the default.

Gameplay camera keys, right-side drags and lock-on no longer rotate the view.
Lock-on still changes combat facing and its existing movement multiplier.
Movement and directional dodge invert the fixed camera's ground projection,
then normalize to the original stick magnitude. Screen diagonals stay aligned
without increasing world speed. Combat, dodge timing, layouts, geometry, palette
and assets are unchanged.

Save format remains 4. Existing camera yaw/pitch fields are accepted while the
fixed view takes precedence; inventories, progress, position and facing restore
normally. This feature does not reset or migrate saves.

## Ownership and rendering

Each generated floor or town model owns its material variants and shadow
proxies. Initialization scans only explicitly eligible architecture: dungeon
wall/detail/pier/masonry batches and wall-owned backing/caps; town wall panels
and door leaves. Floors, grout, rails, furniture, scenery, characters and UI are
not eligible. Existing inside-house roof hiding remains unchanged.

The rig reuses the six cached body-envelope points solely to detect blocking
architecture, not to steer the camera. Orthographic rays start at each point's
projected pixel origin and remain parallel. Original material references stay
bound when the body view is clear. A blocked view swaps prebuilt references;
only fragments inside a feathered body capsule and between camera and body
become translucent. A shared batch never fades across the whole map.

The branch-free shader samples the original albedo once and uses no mask/noise
texture. Variants preserve source tint, vertex-color/sRGB flags, UV transform,
texture filtering, roughness, metallic/specular and emission. Town wall variants
retain their existing mathematical paper fibers. Depth-always rendering avoids
the measured Vulkan alpha-prepass sorting loss of masonry details.

For an originally shadow-casting surface, one precreated SHADOWS_ONLY proxy
shares its original mesh or MultiMesh and materials. It inherits the source
transform and visibility, including moving doors. The faded surface stops
casting while that proxy is visible, so the active caster count does not grow.
Clear/editor views restore exact original material/caster references and hide
the cached proxy. Owner teardown frees caches/proxies. No per-frame cloning or
scene scans occur. The active gameplay camera owns shader globals; an old
camera's release cannot clear a newer town/dungeon owner's aperture.

## Inspector setup

1. Open `data/camera/isometric_view_settings.tres` in the Inspector.
2. Keep the approved framing at Yaw Degrees **45**, Pitch Degrees **-55**,
   Orthographic Size **14** and Follow Distance **14**. Save the resource and
   restart play after framing changes. Keep pitch within the save validator's
   -60 to -35 degree range.
3. Tune **Wall Aperture Radius** (default **0.70 m**) and **Wall Aperture Feather**
   (**0.12 m**) together. Inspect a blocked corner and an open room; the aperture
   must reveal the body without hiding unrelated nearby architecture.
4. **Wall Minimum Opacity** defaults to **0.18**. Increasing it retains more wall
   color but reduces silhouette readability. **Wall Fading Enabled** is the
   persisted master switch. No material resources need manual edits.
5. Globals named `rift_iso_*` in Project Settings → Shader Globals are runtime
   camera data; leave their saved defaults alone. The resource fields above are
   the supported tuning controls. Never attach the shader to a floor or prop.
6. Review both Compatibility/GLES and Vulkan Mobile, door opening, roof hiding,
   edit/walk transitions and floor regeneration after changing settings. Check
   original floor shadows, not just shader compilation.

Native regressions retain enemy combat/LOS checks and add eight-direction analog
projection, off-center orthographic blockers, fixed framing under lock/input,
save compatibility, shadow counts, cache teardown and viewport ownership.
Matched native render and Android evidence, residual pixel metrics, exact
commands and hardware limitations are recorded in the task results. No claim
of exact cross-renderer pixel equality or physical-phone performance is made.
