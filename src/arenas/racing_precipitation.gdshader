shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;
uniform float speed = 20.0;
uniform vec4 tint : source_color = vec4(0.8, 0.9, 1.0, 0.4);
uniform bool plume = false;
varying float lifetime;
void vertex() {
    lifetime = mod(INSTANCE_CUSTOM.r * 55.0 - TIME * speed, 55.0) / 55.0;
    vec3 center = MODEL_MATRIX[3].xyz;
    center.x += sin(TIME * 0.6 + INSTANCE_CUSTOM.g * 6.28) * 0.8;
    center.y += lifetime * 55.0 - (plume ? 0.0 : 10.0);
    if (plume) { center.x += lifetime * 14.0; }
    MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], vec4(center, 1.0));
}
void fragment() {
    float edge = 1.0 - smoothstep(0.15, 0.5, abs(UV.x - 0.5));
    ALBEDO = tint.rgb;
    ALPHA = tint.a * edge;
    if (plume) {
        ALPHA = tint.a * (1.0 - smoothstep(0.1, 0.5, length(UV - vec2(0.5)))) * sin(lifetime * 3.14159);
    }
}
