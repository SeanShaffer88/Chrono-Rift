shader_type spatial;
uniform vec4 deep_color : source_color = vec4(0.10, 0.35, 0.48, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.19, 0.57, 0.62, 1.0);
uniform float flow_speed : hint_range(0.0, 2.0) = 0.6;
varying vec3 world_position;
void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
    float flow = world_position.z * 2.2 - TIME * flow_speed;
    float ripple = 1.0 - smoothstep(0.025, 0.15, abs(sin(flow + sin(world_position.x * 4.0) * 0.55)));
    float depth = 0.5 + 0.5 * sin(world_position.x * 0.9 + world_position.z * 0.07);
    depth = floor(depth * 3.0) / 2.0;
    ALBEDO = mix(deep_color.rgb, shallow_color.rgb, depth) + ripple * vec3(0.11, 0.16, 0.16);
    ROUGHNESS = 0.85;
    SPECULAR = 0.0;
}
