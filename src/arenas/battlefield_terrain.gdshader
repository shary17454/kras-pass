shader_type spatial;

uniform sampler2D ground_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ground_nor_gl : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ground_rough : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_nor_gl : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_rough : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D road_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D road_nor_gl : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D road_rough : filter_linear_mipmap_anisotropic, repeat_enable;
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
    vec2 trail = world_position.xz - vec2(sin(world_position.z * 0.045), sin(world_position.x * 0.05)) * 2.0;
    vec2 grid = abs(mod(trail + vec2(9.0), vec2(18.0)) - vec2(9.0));
    float edge_noise = texture(ground_rough, p.xz * 0.43).r;
    float road = 1.0 - smoothstep(3.4, 5.0, min(grid.x, grid.y) + edge_noise * 0.65);
    road *= 1.0 - smoothstep(40.0, 47.0, max(abs(world_position.x), abs(world_position.z)));
    vec3 earth = mix(texture(ground_diff, p.xz).rgb, texture(road_diff, p.xz).rgb, road);
    ALBEDO = mix(earth, rocks, slope);
    NORMAL_MAP = mix(mix(texture(ground_nor_gl, p.xz).rgb, texture(road_nor_gl, p.xz).rgb, road), texture(rock_nor_gl, p.xz).rgb, slope);
    NORMAL_MAP_DEPTH = 0.55;
    ROUGHNESS = mix(mix(texture(ground_rough, p.xz).r, texture(road_rough, p.xz).r, road), texture(rock_rough, p.xz).r, slope);
}
