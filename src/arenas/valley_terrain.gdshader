shader_type spatial;

uniform sampler2D ground_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ground_nor_gl : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ground_rough : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_nor_gl : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_rough : filter_linear_mipmap_anisotropic, repeat_enable;
uniform int biome = 0;
varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
    vec3 weights = pow(abs(world_normal), vec3(4.0));
    weights /= max(dot(weights, vec3(1.0)), 0.001);
    vec3 p = world_position * 0.16;
    vec3 rocks = texture(rock_diff, p.zy).rgb * weights.x
               + texture(rock_diff, p.xz).rgb * weights.y
               + texture(rock_diff, p.xy).rgb * weights.z;
    float slope = 1.0 - smoothstep(0.52, 0.9, world_normal.y);
    vec3 earth = texture(ground_diff, p.xz).rgb;
    ALBEDO = mix(earth, rocks, slope);
    NORMAL_MAP = mix(texture(ground_nor_gl, p.xz).rgb, texture(rock_nor_gl, p.xz).rgb, slope);
    NORMAL_MAP_DEPTH = 0.55;
    ROUGHNESS = mix(texture(ground_rough, p.xz).r, texture(rock_rough, p.xz).r, slope);
    float grain = dot(ALBEDO, vec3(0.299, 0.587, 0.114));
    if (biome == 0) {
        vec3 grass = vec3(grain * 0.52, grain * 0.85, grain * 0.36);
        ALBEDO = mix(ALBEDO, grass, (1.0 - slope) * 0.55);
    } else if (biome == 1) {
        float ripples = sin(world_position.x * 2.6 + sin(world_position.z * 0.24) * 3.0);
        ALBEDO = mix(vec3(0.56, 0.34, 0.15), vec3(0.84, 0.65, 0.38), clamp(grain * 2.0, 0.0, 1.0));
        ALBEDO *= 0.96 + ripples * 0.04;
        ROUGHNESS = 0.95;
    } else if (biome == 2) {
        ALBEDO = mix(vec3(0.68, 0.79, 0.86) + grain * 0.18, vec3(grain * 0.65), slope * 0.85);
        NORMAL_MAP_DEPTH = 0.18;
        ROUGHNESS = 0.66;
    } else if (biome == 3) {
        ALBEDO = vec3(grain * 0.35 + 0.025);
        ROUGHNESS = 0.9;
    } else if (biome == 5) {
        vec3 sandstone = mix(vec3(0.21, 0.12, 0.065), vec3(0.52, 0.35, 0.22), clamp(grain * 1.6, 0.0, 1.0));
        ALBEDO = sandstone;
        ROUGHNESS = mix(0.65, 0.83, slope);
        NORMAL_MAP_DEPTH = 0.35;
    } else if (biome == 4) {
        ALBEDO *= 0.62;
        ROUGHNESS = mix(0.22, 0.55, slope);
    }
}
