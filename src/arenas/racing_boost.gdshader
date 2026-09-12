shader_type spatial;
render_mode cull_disabled;
void fragment() {
    float arrow = step(0.42, fract(UV.y * 3.0 + abs(UV.x - 0.5) * 1.3));
    float border = step(0.06, UV.x) * step(UV.x, 0.94) * step(0.04, UV.y) * step(UV.y, 0.96);
    vec3 green = mix(vec3(0.015, 0.12, 0.035), vec3(0.2, 1.0, 0.055), arrow * border);
    ALBEDO = green;
    EMISSION = green * 0.6;
    ROUGHNESS = 0.7;
}
