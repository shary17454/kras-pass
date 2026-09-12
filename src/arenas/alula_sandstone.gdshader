shader_type spatial;
uniform sampler2D scan_color : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D scan_normal : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D detail : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 world_position;
varying vec3 world_normal;
void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
    vec3 scan = texture(scan_color, UV).rgb;
    float luminance = dot(scan, vec3(0.299, 0.587, 0.114));
    vec3 weights = pow(abs(world_normal), vec3(4.0));
    weights /= max(dot(weights, vec3(1.0)), 0.001);
    vec3 p = world_position * 0.25;
    vec3 grain = texture(detail, p.xy).rgb * weights.z + texture(detail, p.zy).rgb * weights.x + texture(detail, p.xz).rgb * weights.y;
    float strata = sin(world_position.y * 0.8 + grain.r * 3.0 + sin(world_position.x * 0.07)) * 0.045;
    vec3 sandstone = mix(vec3(0.16, 0.071, 0.035), vec3(0.66, 0.40, 0.21), clamp(luminance * 1.7, 0.0, 1.0));
    ALBEDO = sandstone * (0.82 + grain.r * 0.38 + strata);
    NORMAL_MAP = texture(scan_normal, UV).rgb;
    NORMAL_MAP_DEPTH = 0.85;
    ROUGHNESS = 0.7 + grain.r * 0.16;
}
