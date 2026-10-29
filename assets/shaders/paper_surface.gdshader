shader_type spatial;
// One palette fetch, mathematical fibers, opaque surfaces on both mobile renderers.
uniform sampler2D palette_texture : source_color, hint_default_white, filter_nearest;
uniform vec4 tint : source_color = vec4(1.0);
uniform float vertex_colors : hint_range(0.0, 1.0) = 0.0;
uniform float red_roof : hint_range(0.0, 1.0) = 0.0;
uniform float fiber_strength : hint_range(0.0, 0.12) = 0.045;
uniform float fiber_scale : hint_range(4.0, 80.0) = 32.0;
varying vec3 paper_position;
void vertex() {
    paper_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
    vec3 color = texture(palette_texture, UV).rgb;
    float green = smoothstep(0.02, 0.12, color.g - max(color.r, color.b));
    color = mix(color, vec3(0.62, 0.18, 0.12), green * red_roof);
    vec3 cell = floor(paper_position * fiber_scale);
    float fiber = fract(sin(dot(cell, vec3(12.9898, 78.233, 37.719))) * 43758.5453) - 0.5;
    float fade = 1.0 - smoothstep(0.03, 0.12, length(fwidth(paper_position)));
    ALBEDO = color * tint.rgb * mix(vec3(1.0), COLOR.rgb, vertex_colors) * (1.0 + fiber * fiber_strength * fade);
    ROUGHNESS = 1.0;
    SPECULAR = 0.0;
}
