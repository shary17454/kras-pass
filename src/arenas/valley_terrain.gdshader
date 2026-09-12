shader_type spatial;

uniform sampler2D ground_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ground_nor_gl : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ground_rough : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_nor_gl : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_rough : filter_linear_mipmap_anisotropic, repeat_enable;
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
}
