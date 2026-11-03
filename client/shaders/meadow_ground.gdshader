shader_type spatial;
render_mode cull_disabled;
uniform sampler2D meadow_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 world_position;
float hash(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q,q.yzx+33.33); return fract((q.x+q.y)*q.z); }
float noise(vec2 p) {
    vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
    return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
    float patches = noise(world_position.xz * 0.65);
    float grain = noise(world_position.xz * 13.0);
    vec3 base = pow(COLOR.rgb, vec3(1.85)) * mix(0.92,1.12,patches);
    base *= mix(0.96,1.03,grain);
    float grass = smoothstep(-0.01,0.04,COLOR.g-COLOR.r);
    vec3 detail = texture(meadow_albedo,world_position.xz*0.25).rgb;
    float texture_value = dot(detail,vec3(0.25,0.60,0.15));
    base *= mix(1.0,mix(0.64,1.38,smoothstep(0.05,0.28,texture_value)),grass);
    ALBEDO = base;
    ROUGHNESS = 1.0;
}

