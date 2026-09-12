shader_type spatial;
render_mode cull_disabled;
varying vec3 world_position;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
    vec2 p = world_position.xz * 0.55 + vec2(TIME * 0.09, TIME * 0.025);
    p += vec2(noise(p * 0.35), noise(p * 0.35 + 13.0)) * 2.0;
    float flow = noise(p) * 0.65 + noise(p * 2.7) * 0.25 + noise(p * 7.0) * 0.1;
    float crust = smoothstep(0.43, 0.61, flow);
    vec3 heat = mix(vec3(0.8, 0.055, 0.004), vec3(1.0, 0.38, 0.025), noise(p * 1.3));
    ALBEDO = mix(heat, vec3(0.065, 0.035, 0.028), crust);
    EMISSION = heat * (1.0 - crust) * 0.9;
    ROUGHNESS = 0.8;
}
