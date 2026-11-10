shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform float grain_strength : hint_range(0.0, 0.03) = 0.010;

void fragment() {
	vec4 source = texture(screen_texture, SCREEN_UV);
	float luminance = dot(source.rgb, vec3(0.2126, 0.7152, 0.0722));
	float shadow_mask = 1.0 - smoothstep(0.12, 0.62, luminance);
	float blue_strength = strength * shadow_mask * 0.68;
	vec3 blue_shadow = source.rgb * vec3(0.76, 0.84, 1.08) + vec3(0.006, 0.012, 0.032);
	float amber = smoothstep(0.035, 0.24, source.r - source.g) * smoothstep(0.08, 0.38, source.r);
	vec3 graded = mix(source.rgb, blue_shadow, blue_strength);
	graded = mix(graded, source.rgb, amber * strength * 0.82);
	// Едва заметное зерно, обновляется шесть раз в секунду и не окрашивает интерфейс.
	vec2 pixel = floor(FRAGCOORD.xy * 0.5);
	pixel.x += floor(TIME * 6.0);
	float grain = fract(52.9829189 * fract(dot(pixel, vec2(0.06711056, 0.00583715))));
	graded += vec3((grain - 0.5) * grain_strength * strength);
	COLOR = vec4(clamp(graded, vec3(0.0), vec3(1.0)), source.a);
}
