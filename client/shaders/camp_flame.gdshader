shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec4 flame_color : source_color = vec4(1.0,0.36,0.04,1.0);
void vertex() {
    float tip = clamp(VERTEX.y + 0.5,0.0,1.0);
    VERTEX.x += sin(TIME*3.4 + VERTEX.y*4.0)*0.07*tip;
    VERTEX.z += cos(TIME*2.7 + VERTEX.y*3.0)*0.055*tip;
}
void fragment() { ALBEDO = flame_color.rgb; }
