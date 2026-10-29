shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, blend_mix;

// Zero samplers. Both Compatibility and Vulkan Mobile use this arithmetic path.
uniform vec4 base_color : source_color = vec4(0.16, 0.015, 0.045, 1.0);
uniform vec4 energy_color : source_color = vec4(0.8, 0.08, 0.18, 1.0);
uniform float emission_strength : hint_range(0.0, 3.0, 0.05) = 0.8;
uniform float arc_frequency : hint_range(1.0, 20.0, 0.5) = 9.0;
uniform float arc_width : hint_range(0.01, 0.25, 0.01) = 0.07;
uniform float speed : hint_range(0.0, 8.0, 0.1) = 2.0;
uniform float pulse_strength : hint_range(0.0, 0.8, 0.05) = 0.2;
uniform float opacity : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform float dissolve_amount : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float dissolve_scale : hint_range(2.0, 32.0, 1.0) = 12.0;
varying vec3 object_position;

void vertex() {
    object_position = VERTEX;
    // Final dissolve contracts the actual vertices as well as the coverage mask.
    VERTEX *= 1.0 - smoothstep(0.85, 1.0, dissolve_amount);
}

void fragment() {
    float time = TIME * speed;
    float warp = sin(object_position.y * 19.0 + time) * 0.7;
    float wave = abs(sin((object_position.x + object_position.z) * arc_frequency * 7.0 + warp - time * 3.0));
    float arc = 1.0 - smoothstep(arc_width, arc_width + 0.06, wave);
    float pulse = 1.0 - pulse_strength * (0.5 + 0.5 * sin(time * 2.0));
    vec3 cell = floor(object_position * dissolve_scale);
    float noise_value = fract(sin(dot(cell, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
    float coverage = step(dissolve_amount, noise_value * 0.98 + 0.01) * (1.0 - step(0.999, dissolve_amount));
    ALBEDO = mix(base_color.rgb, energy_color.rgb, arc);
    EMISSION = energy_color.rgb * arc * emission_strength * pulse;
    ALPHA = opacity * coverage * pulse;
}
