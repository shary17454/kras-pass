shader_type spatial;
render_mode cull_disabled;
varying vec3 world_position;

void vertex() {
    VERTEX.x += sin(VERTEX.z * 0.035) * -5.0;
    VERTEX.y += sin(VERTEX.z * 0.75 + TIME * 1.4) * 0.06;
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    float phase_a = world_position.x * 1.7 + world_position.z * 0.9 + TIME * 1.8;
    float phase_b = world_position.z * 2.2 - world_position.x * 1.1 - TIME * 2.4;
    // Fade sub-pixel ripples before they turn into distant moire stripes.
    float a = sin(phase_a) * (1.0 - smoothstep(0.3, 1.8, fwidth(phase_a)));
    float b = sin(phase_b) * (1.0 - smoothstep(0.3, 1.8, fwidth(phase_b)));
    float c = sin(world_position.z * 0.23 + world_position.x * 0.17 - TIME * 0.8) * 0.45
            + sin(world_position.x * 0.31 - world_position.z * 0.12 + TIME * 0.53) * 0.35;
    NORMAL_MAP = normalize(vec3((a + c) * 0.06, (b + c) * 0.05, 1.0)) * 0.5 + 0.5;
    ALBEDO = vec3(0.017, 0.092, 0.115) + c * 0.004;
    ROUGHNESS = 0.32;
    METALLIC = 0.0;
    SPECULAR = 0.28;
}
