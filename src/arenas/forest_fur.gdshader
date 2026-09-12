shader_type spatial;
uniform bool tiger = false;
varying vec3 local_pos;
void vertex() { local_pos = VERTEX; }
void fragment() {
    float grain = sin(local_pos.y * 210.0 + sin(local_pos.z * 170.0)) * 0.025;
    vec3 coat = tiger ? vec3(0.68, 0.28, 0.065) : vec3(0.43, 0.26, 0.12);
    float wave = sin(local_pos.z * 18.0 + sin(local_pos.y * 4.0) * 2.4 + sin(local_pos.x * 5.0));
    float stripe = smoothstep(0.46, 0.64, wave) * smoothstep(-0.85, -0.2, local_pos.y);
    ALBEDO = (tiger ? mix(coat, vec3(0.025, 0.018, 0.012), stripe) : coat) + grain;
    ROUGHNESS = 0.92;
}
