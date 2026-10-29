shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;
// One small gate plane, zero texture fetches; analytic ring, branch-free fragment.
uniform vec4 rift_color : source_color = vec4(0.22,0.68,0.70,1.0);
uniform float speed : hint_range(0.0,2.0) = 0.4;
uniform float opacity : hint_range(0.0,0.8) = 0.3;
void fragment() {
    vec2 p = (UV-0.5)*2.0;
    float radius = length(p);
    float edge = 1.0-smoothstep(0.75,0.97,radius);
    float ring = 1.0-smoothstep(0.025,0.1,abs(radius-0.76));
    float streak = pow(0.5+0.5*sin(radius*28.0-TIME*speed*8.0+p.y*4.0),4.0);
    ALBEDO = rift_color.rgb*(0.4+ring+streak*0.4);
    ALPHA = edge*(0.18+ring*0.55+streak*0.25)*opacity;
}
