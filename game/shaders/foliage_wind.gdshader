shader_type canvas_item;
// Мягко качает только лесную кромку панорамы, облака остаются неподвижны.
uniform float strength : hint_range(0.0, 0.006) = 0.002;
uniform float speed : hint_range(0.1, 2.0) = 0.65;

void fragment() {
	float treeline = smoothstep(0.78, 0.91, UV.y) * (1.0 - smoothstep(0.982, 1.0, UV.y));
	float gust = sin(TIME * speed + UV.x * 28.0 + UV.y * 5.0)
		+ 0.25 * sin(TIME * speed * 1.7 + UV.x * 41.0);
	vec2 warped_uv = UV + vec2(gust * strength * treeline, 0.0);
	COLOR = texture(TEXTURE, warped_uv) * COLOR;
}