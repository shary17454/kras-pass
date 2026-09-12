shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
uniform float elapsed = 0.0;
uniform bool pool = false;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
void fragment() {
    vec2 flow = vec2(UV.x * 36.0, UV.y * 7.0 + elapsed * 3.0);
    float streak = noise(flow) * 0.7 + noise(flow * 2.3) * 0.3;
    float ripples = sin(length(UV - 0.5) * 100.0 - elapsed * 5.0);
    float foam = pool ? smoothstep(0.5, 1.0, ripples) * 0.45 : smoothstep(0.15, 0.75, streak);
    ALBEDO = mix(vec3(0.12, 0.26, 0.25), vec3(0.88, 0.94, 0.92), foam);
    ALPHA = pool ? 0.88 : smoothstep(0.0, 0.08, UV.x) * smoothstep(0.0, 0.08, 1.0 - UV.x) * (0.65 + foam * 0.35);
    ROUGHNESS = 0.22;
    METALLIC = 0.15;
    NORMAL_MAP = vec3(0.5 + (streak - 0.5) * 0.15, 0.5 + ripples * 0.04, 1.0);
}
