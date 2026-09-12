shader_type spatial;
render_mode cull_disabled;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
    vec2 p = world_position.xz;
    float flow = sin(p.x * 2.0 + sin(p.y * 1.7 - TIME * 0.7) * 2.0);
    float crust = smoothstep(0.1, 0.7, flow * sin(p.y * 2.5 - TIME * 0.3));
    vec3 heat = mix(vec3(1.0, 0.16, 0.01), vec3(1.0, 0.65, 0.07), sin(p.y + TIME) * 0.5 + 0.5);
    ALBEDO = mix(heat, vec3(0.065, 0.035, 0.028), crust);
    EMISSION = heat * (1.0 - crust) * 1.7;
    ROUGHNESS = 0.8;
}
