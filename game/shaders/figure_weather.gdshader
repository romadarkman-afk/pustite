shader_type canvas_item;
// Один шейдер на фигуры жителей, хозяев мест и гостей.
// 1) Цвет фонаря героя: перекрашивает тёплое стекло и огонь внутри прямоугольника фонаря на картинке.
// 2) Иней: белая кромка по верхним краям силуэта (плечи, шапка, волосы), чем больше frost, тем толще.
// 3) Влага: ткань темнее, по верхним краям мокрый блик, по складкам бегает отражение.
// Никаких новых картинок: всё считается по альфа-каналу самой фигуры.

uniform vec4 lantern_rect = vec4(0.0, 0.0, 0.0, 0.0);   // x, y, ширина, высота в долях текстуры
uniform vec4 glass : source_color = vec4(1.0, 0.81, 0.42, 1.0);
uniform float strength = 0.0;
uniform float frost : hint_range(0.0, 1.0) = 0.0;
uniform float wet : hint_range(0.0, 1.0) = 0.0;
uniform float night : hint_range(0.0, 1.0) = 0.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec4 c = COLOR;   // в Godot 4 COLOR здесь уже содержит цвет текстуры
	vec2 p = (UV - lantern_rect.xy) / max(lantern_rect.zw, vec2(0.0001));
	float inside = step(0.0, p.x) * step(p.x, 1.0) * step(0.0, p.y) * step(p.y, 1.0);
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	// тёплое и светлое: огонь и освещённое стекло
	float warm = smoothstep(0.08, 0.3, c.r - c.b) * smoothstep(0.3, 0.6, lum);
	vec3 tinted = glass.rgb * (0.45 + lum * 0.9);
	c.rgb = mix(c.rgb, tinted, inside * warm * strength);

	if (frost > 0.001 || wet > 0.001) {
		vec2 px = TEXTURE_PIXEL_SIZE;
		float reach = 0.012 + 0.032 * max(frost, wet * 0.5);   // доля высоты картинки
		float a1 = texture(TEXTURE, UV - vec2(0.0, reach * 0.3)).a;
		float a2 = texture(TEXTURE, UV - vec2(0.0, reach * 0.65)).a;
		float a3 = texture(TEXTURE, UV - vec2(0.0, reach)).a;
		float topness = 1.0 - (a1 + a2 + a3) / 3.0;   // 1 у самой верхней кромки, 0 в глубине
		float grain = hash21(floor(UV / px / 4.0));

		// иней
		float f = frost * c.a * smoothstep(0.08, 0.85, topness + (grain - 0.5) * 0.4);
		vec3 ice = vec3(0.88, 0.94, 1.0) * mix(1.0, 0.72, night);
		c.rgb = mix(c.rgb, ice, clamp(f * 1.1, 0.0, 0.95));
		c.rgb = mix(c.rgb, c.rgb * vec3(0.9, 0.97, 1.06) + vec3(0.03), frost * 0.4 * (1.0 - UV.y));

		// влага
		c.rgb *= 1.0 - 0.17 * wet;
		float streak = pow(max(0.0, sin((UV.x * 3.0 - UV.y * 5.0) * 6.2832 + TIME * 0.45)), 14.0);
		c.rgb += vec3(0.5, 0.6, 0.72) * streak * wet * 0.3 * c.a * (0.35 + lum);
		float rim = wet * c.a * smoothstep(0.35, 1.0, topness) * (0.4 + 0.6 * grain);
		c.rgb += vec3(0.62, 0.74, 0.88) * rim * 0.45;
	}
	COLOR = c;
}
