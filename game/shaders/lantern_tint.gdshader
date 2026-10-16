shader_type canvas_item;
// Фонарь героя другого цвета: перекрашивает только тёплое стекло и огонь внутри
// прямоугольника фонаря на картинке. Корпус, рука и одежда остаются как есть.

uniform vec4 lantern_rect = vec4(0.0, 0.0, 0.0, 0.0);   // x, y, ширина, высота в долях текстуры
uniform vec4 glass : source_color = vec4(1.0, 0.81, 0.42, 1.0);
uniform float strength = 0.0;

void fragment() {
	vec4 c = COLOR;   // в Godot 4 COLOR здесь уже содержит цвет текстуры
	vec2 p = (UV - lantern_rect.xy) / max(lantern_rect.zw, vec2(0.0001));
	float inside = step(0.0, p.x) * step(p.x, 1.0) * step(0.0, p.y) * step(p.y, 1.0);
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	// тёплое и светлое: огонь и освещённое стекло
	float warm = smoothstep(0.08, 0.3, c.r - c.b) * smoothstep(0.3, 0.6, lum);
	vec3 tinted = glass.rgb * (0.45 + lum * 0.9);
	c.rgb = mix(c.rgb, tinted, inside * warm * strength);
	COLOR = c;
}
