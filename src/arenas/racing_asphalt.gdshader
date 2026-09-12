shader_type spatial;
uniform sampler2D aggregate : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D surface_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float road_width = 14.0;
uniform bool wet = false;
void fragment() {
    // The ribbon UVs use four metres per unit across and along the road.
    float x = UV.x * 4.0;
    float metres = UV.y * 4.0;
    float grain = dot(texture(aggregate, UV * 3.0).rgb, vec3(0.299, 0.587, 0.114));
    vec3 asphalt = vec3(0.055, 0.061, 0.066) + grain * 0.09;
    float aa = max(fwidth(x), 0.015);
    float centre = 1.0 - smoothstep(0.10, 0.10 + aa, abs(x - road_width * 0.5));
    float dash = 1.0 - smoothstep(3.5, 3.5 + max(fwidth(metres), 0.03), mod(metres, 7.0));
    float edge_distance = min(abs(x - 0.4), abs(x - road_width + 0.4));
    float edge = 1.0 - smoothstep(0.12, 0.12 + aa, edge_distance);
    float paint = max(centre * dash, edge);
    ALBEDO = mix(asphalt * (wet ? 0.75 : 1.0), vec3(0.88, 0.88, 0.79), paint);
    ROUGHNESS = mix(wet ? 0.32 : 0.87, 0.65, paint);
    NORMAL_MAP = texture(surface_normal, UV * 3.0).rgb;
    NORMAL_MAP_DEPTH = 0.25 * (1.0 - paint);
}
