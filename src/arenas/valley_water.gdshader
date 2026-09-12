shader_type spatial;
render_mode cull_disabled;
varying vec3 world_position;

void vertex() {
    VERTEX.x += sin(VERTEX.z * 0.035) * -5.0;
    VERTEX.y += sin(VERTEX.z * 0.75 + TIME * 1.4) * 0.06;
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    float a = sin(world_position.x * 4.7 + world_position.z * 1.9 + TIME * 1.8);
    float b = sin(world_position.z * 7.2 - world_position.x * 3.1 - TIME * 2.4);
    float c = sin(world_position.z * 1.3 + world_position.x * 0.7 - TIME * 0.8);
    NORMAL_MAP = normalize(vec3((a + c) * 0.06, (b + c) * 0.05, 1.0)) * 0.5 + 0.5;
    ALBEDO = mix(vec3(0.02, 0.08, 0.075), vec3(0.04, 0.13, 0.115), c * 0.5 + 0.5);
    ROUGHNESS = 0.14;
    METALLIC = 0.0;
    SPECULAR = 0.28;
}
