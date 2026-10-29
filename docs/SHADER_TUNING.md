# Procedural energy shader: Inspector tuning

Town paper, layered river and dungeon vent steam tuning is documented in
[ENVIRONMENT_ART.md](ENVIRONMENT_ART.md#shader-inspector-tuning).

Used for the small dark red companion core and amber enemy windup sector.
Source: assets/shaders/procedural_energy.gdshader. Presets:
assets/shaders/companion_energy.tres and assets/shaders/attack_warning.tres.

## Open and preview

1. In Godot's FileSystem panel, select companion_energy.tres or attack_warning.tres.
2. In the Inspector, expand **Shader Parameters**. Duplicate the material first
   when testing a variant; both presets intentionally share the shader source.
3. Run the dungeon to preview the companion. For the warning, approach its guard
   or run tests/fixtures/combat_visual_fixture.gd for a reproducible windup view.
4. Tune one parameter at a time using the steps below. Save the .tres when done.
   For a one-off instance, use **Make Unique** on its material before editing.
   When assigning the material to another mesh, set that mesh's **Geometry >
   Cast Shadow** to **Off**. The existing orb and warning already do this;
   the shader's shadows_disabled render mode only disables receiving shadows.

## Exposed parameters

| Parameter | Steps and purpose | Companion default | Warning default |
| --- | --- | --- | --- |
| Base Color | Start here. Set the dark body/fill color; keep companion red subdued. | dark burgundy | amber |
| Energy Color | Set the electrical streak color after the base. | crimson | gold |
| Emission Strength | Raise in 0.1 steps for brighter streaks; keep below 1 on this mobile pass. | 0.8 | 0.25 |
| Arc Frequency | Raise to add tighter streaks, lower for broader shapes. | 9 | 2 |
| Arc Width | Raise in 0.01 steps to thicken lines; keep above 0.04 to reduce tiny-line shimmer. | 0.07 | 0.12 |
| Speed | Set 0 to inspect a static pattern; raise slowly for faster electricity/pulsing. | 2 | 3 |
| Pulse Strength | Set 0 for steady brightness; 0.15–0.25 gives a restrained pulse. | 0.2 | 0.25 |
| Opacity | Set last; keep orb solid-looking, warning translucent over the floor. | 1 | 0.45 |
| Dissolve Amount | Scrub 0→1 to remove mathematical cell coverage. Final 15% also contracts vertices. Keep 0 for normal play. | 0 | 0 |
| Dissolve Scale | With dissolve near 0.5, raise for finer cells; lower for large fragments. | 12 | 12 |

5. Restore Dissolve Amount to 0 after previewing; 1 intentionally hides all pixels.
6. Inspect against both bright and dark backgrounds and at Android screen scale.
7. Validate the Compatibility renderer and Vulkan Mobile before committing.

## Mobile constraints and behavior

The shader declares no samplers and performs **zero noise/mask texture fetches**.
It uses local object coordinates, sine waves and a mathematical cell hash. Its
fragment function contains no conditional branches, loops or discard statements;
coverage uses step/smoothstep. Vertex contraction also uses smoothstep. Both
presets are unshaded, double-sided and shadowless. Emission needs no bloom; it
raises streak brightness even where bloom is unavailable.

Godot TIME continues during pause, so this cosmetic pulse keeps animating while
menus pause simulation. It never changes attack timing or pickup behavior.

ALPHA means blended rendering and overdraw: keep the orb small and limit the
warning to the short windup. Do not put this material on all opaque world meshes.
Shader dissolve only affects rendering; it does not disable collision, release
nodes or replace the guard's death/attack state machine. Floating-point hash
patterns may vary slightly between GPUs; game logic does not depend on them.

Relevant API references:
https://docs.godotengine.org/en/4.7/tutorials/shaders/shader_reference/spatial_shader.html
https://docs.godotengine.org/en/4.7/classes/class_shadermaterial.html
