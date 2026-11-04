shader_type sky;
render_mode disable_fog;
uniform float night_mix : hint_range(0.0, 1.0) = 0.0;

// Analytic, static sky. No texture fetches, screen buffers or volumetrics.
void sky() {
    vec3 direction = normalize(EYEDIR);
    float height = max(direction.y, 0.0);
    vec3 horizon = vec3(0.78, 0.82, 0.80);
    vec3 zenith = vec3(0.26, 0.52, 0.74);
    vec3 color = mix(horizon, zenith, pow(height, 0.38));
    vec3 sun_direction = normalize(vec3(-0.55, 0.38, -0.72));
    float sun = max(dot(direction, sun_direction), 0.0);
    color += vec3(0.30, 0.19, 0.07) * pow(sun, 12.0);
    color = mix(color, vec3(1.0, 0.92, 0.65), smoothstep(0.9992, 0.9997, sun));
    vec2 p = direction.xz / max(height + 0.20, 0.20);
    float cloud = sin(p.x * 2.1 + sin(p.y * 2.4)) * 0.5;
    cloud += sin(p.y * 3.7 + p.x * 0.7) * 0.28;
    cloud += sin(p.x * 7.1 + p.y * 5.6) * 0.12;
    float mask = smoothstep(0.39, 0.48, cloud) * smoothstep(0.035, 0.18, height);
    vec3 cloud_color = mix(vec3(0.79, 0.83, 0.85), vec3(1.0, 0.91, 0.77), pow(sun, 3.0));
    color = mix(color, cloud_color, mask * 0.88);
    // A cheap dusk-to-night tint; no star textures, volumetric lights or
    // extra material passes on low-end Android renderers.
    vec3 night = mix(vec3(0.08, 0.14, 0.26), vec3(0.015, 0.045, 0.11), pow(height, 0.45));
    color = mix(color, night, night_mix);
    // Sparse procedural stars use one hash per sky pixel and no textures,
    // point lights, full-screen passes or volumetric shaders on Android.
    vec2 star_tile = floor(direction.xz / max(height + 0.30, 0.30) * 98.0);
    float star_hash = fract(sin(dot(star_tile, vec2(12.9898, 78.233))) * 43758.5453);
    float star = step(0.996, star_hash) * smoothstep(0.14, 0.35, height);
    color += vec3(0.52, 0.61, 0.83) * star * night_mix;
    COLOR = direction.y >= 0.0 ? color : vec3(0.32, 0.42, 0.39);
}
