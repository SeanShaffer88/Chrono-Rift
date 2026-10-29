shader_type spatial;
uniform vec4 deep_color : source_color = vec4(0.10, 0.35, 0.48, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.19, 0.57, 0.62, 1.0);
uniform float flow_speed : hint_range(0.0, 2.0) = 0.35;
uniform float ripple_strength : hint_range(0.0, 0.2) = 0.08;
varying vec3 world_position;
void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
    float flow = world_position.z * 1.6 - TIME * flow_speed;
    float wave = sin(flow + sin(world_position.x * 2.4) * 0.4);
    float aa = max(fwidth(wave), 0.035);
    float ripple = 1.0 - smoothstep(0.045, 0.045 + aa * 1.5, abs(wave));
    float depth = 0.5 + 0.5 * sin(world_position.x * 0.9 + world_position.z * 0.07);
    float band_aa = max(fwidth(depth), 0.015);
    depth = 0.5 * smoothstep(0.33-band_aa,0.33+band_aa,depth) + 0.5 * smoothstep(0.66-band_aa,0.66+band_aa,depth);
    ALBEDO = mix(deep_color.rgb, shallow_color.rgb, depth) + ripple * ripple_strength;
    ROUGHNESS = 0.85;
    SPECULAR = 0.0;
}
