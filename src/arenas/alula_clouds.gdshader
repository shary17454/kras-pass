shader_type sky;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise2(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void sky() {
    vec2 p = EYEDIR.xz / max(EYEDIR.y + 0.35, 0.15) * 2.2;
    float n = noise2(p) * 0.53 + noise2(p * 2.1) * 0.27 + noise2(p * 4.3) * 0.13 + noise2(p * 8.2) * 0.07;
    vec3 clouds = mix(vec3(0.13, 0.17, 0.21), vec3(0.53, 0.57, 0.59), smoothstep(0.18, 0.85, n));
    COLOR = mix(vec3(0.43, 0.47, 0.48), clouds, smoothstep(0.0, 0.3, EYEDIR.y));
}
