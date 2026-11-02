shader_type spatial;
render_mode cull_disabled;
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
    ALBEDO = base;
    ROUGHNESS = 1.0;
}

