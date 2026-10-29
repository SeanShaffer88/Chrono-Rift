shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;
// A single small vent quad. Zero texture fetches, no particles or fragment branches.
uniform vec4 steam_color : source_color = vec4(0.75, 0.78, 0.74, 1.0);
uniform float opacity : hint_range(0.0, 0.2) = 0.1;
uniform float rise_speed : hint_range(0.0, 2.0) = 0.45;
void fragment() {
    float height = 1.0 - UV.y;
    float center = 0.5 + sin(height * 8.0 - TIME * rise_speed * 3.0) * height * 0.15;
    float width = mix(0.07, 0.3, height);
    float body = 1.0 - smoothstep(width * 0.4, width, abs(UV.x - center));
    float pulse = 0.7 + 0.3 * sin(height * 12.0 - TIME * rise_speed * 5.0);
    ALBEDO = steam_color.rgb;
    ALPHA = body * smoothstep(0.0, 0.15, height) * (1.0 - height) * pulse * opacity;
}
