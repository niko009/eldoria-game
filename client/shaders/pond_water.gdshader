shader_type spatial;
render_mode unshaded, cull_disabled;
varying vec2 local_position;
uniform float animation_speed = 1.0;
void vertex() { local_position = VERTEX.xz; }
void fragment() {
    float water = 1.0 - smoothstep(7.8, 9.2, length(local_position));
    float phase = TIME * animation_speed * 0.45;
    float ripple = sin(local_position.y*5.8 + sin(local_position.x*1.4+phase)*0.55 + phase);
    float breaks = smoothstep(0.25,0.75,sin(local_position.x*2.3 + local_position.y*0.4));
    float glint = smoothstep(0.96,1.0,ripple) * breaks * water;
    vec3 color = COLOR.rgb;
    color = mix(color, vec3(0.62,0.79,0.77), glint*0.35);
    ALBEDO = color;
}
