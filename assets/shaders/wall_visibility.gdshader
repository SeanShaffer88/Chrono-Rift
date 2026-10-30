shader_type spatial;
render_mode depth_draw_always, cull_back;
// One original albedo lookup; no mask/noise texture. Only wall-owned surfaces use this.
uniform sampler2D albedo_texture : source_color, hint_default_white, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0);
uniform float vertex_colors = 0.0;
uniform float vertex_srgb = 0.0;
uniform float roughness_value = 1.0;
uniform float metallic_value = 0.0;
uniform float specular_value = 0.5;
uniform vec3 uv_scale = vec3(1.0);
uniform vec3 uv_offset = vec3(0.0);
uniform vec3 emission_color : source_color = vec3(0.0);
uniform float fiber_strength = 0.0;
uniform float fiber_scale = 32.0;
global uniform vec3 rift_iso_body_a;
global uniform vec3 rift_iso_body_b;
global uniform vec3 rift_iso_camera;
global uniform vec3 rift_iso_right;
global uniform vec3 rift_iso_up;
global uniform vec3 rift_iso_forward;
global uniform float rift_iso_enabled;
global uniform float rift_iso_radius;
global uniform float rift_iso_feather;
global uniform float rift_iso_opacity;
varying vec3 wall_world_point;
void vertex() {
    wall_world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    UV = UV * uv_scale.xy + uv_offset.xy;
}
void fragment() {
    vec3 linear_vertex = mix(COLOR.rgb / 12.92, pow((COLOR.rgb + vec3(0.055)) / 1.055, vec3(2.4)), step(vec3(0.04045), COLOR.rgb));
    vec3 vertex_color = mix(COLOR.rgb, linear_vertex, vertex_srgb * float(!OUTPUT_IS_SRGB));
    vec3 color = texture(albedo_texture, UV).rgb * tint.rgb * mix(vec3(1.0), vertex_color, vertex_colors);
    vec3 cell = floor(wall_world_point * fiber_scale);
    float fiber = fract(sin(dot(cell, vec3(12.9898, 78.233, 37.719))) * 43758.5453) - 0.5;
    float fiber_lod = 1.0 - smoothstep(0.03, 0.12, length(fwidth(wall_world_point)));
    ALBEDO = color * (1.0 + fiber * fiber_strength * fiber_lod);
    ROUGHNESS = roughness_value;
    METALLIC = metallic_value;
    SPECULAR = specular_value;
    EMISSION = emission_color;
    vec3 offset = wall_world_point - rift_iso_body_a;
    vec3 axis = rift_iso_body_b - rift_iso_body_a;
    vec2 p = vec2(dot(offset, rift_iso_right), dot(offset, rift_iso_up));
    vec2 b = vec2(dot(axis, rift_iso_right), dot(axis, rift_iso_up));
    float t = clamp(dot(p, b) / max(dot(b, b), 0.00001), 0.0, 1.0);
    float aperture = 1.0 - smoothstep(rift_iso_radius-rift_iso_feather, rift_iso_radius+rift_iso_feather, length(p-b*t));
    float fragment_depth = dot(wall_world_point-rift_iso_camera, rift_iso_forward);
    float body_depth = dot(mix(rift_iso_body_a,rift_iso_body_b,t)-rift_iso_camera,rift_iso_forward);
    float blocking = smoothstep(0.05,0.15,body_depth-fragment_depth)*step(0.0,fragment_depth);
    ALPHA = mix(1.0,rift_iso_opacity,clamp(aperture*blocking*rift_iso_enabled,0.0,1.0));
}
