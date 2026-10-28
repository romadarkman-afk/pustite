shader_type canvas_item;
// Комикс-фото (TASK-102). Один шейдер на все кадры колод, чтобы картинки из разных генераций смотрелись одним комиксом:
// 1) контраст и раздавленные чёрные, 2) холодные тени и тёплые света по цвету акта,
// 3) воспоминание (memory) выцветает в сепию, 4) полутон в тенях, 5) зерно плёнки, 6) вспышка.
// Цвета и силу задаёт колода (SlidePlayer.GRADES). Режим «упрощённая графика» шейдер не включает.

uniform vec3 cold : source_color = vec3(0.10, 0.17, 0.30);
uniform vec3 warm : source_color = vec3(1.0, 0.72, 0.42);
uniform float tone : hint_range(0.0, 1.0) = 0.32;
uniform float contrast : hint_range(0.5, 2.0) = 1.16;
uniform float memory : hint_range(0.0, 1.0) = 0.0;
uniform float grain : hint_range(0.0, 0.3) = 0.06;
uniform float halftone : hint_range(0.0, 1.0) = 0.22;
uniform float dot_size = 5.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec4 c = COLOR;   // в Godot 4 COLOR уже содержит цвет текстуры
	vec3 rgb = (c.rgb - 0.5) * contrast + 0.5;
	rgb = max(rgb - 0.02, vec3(0.0));
	float lum = dot(rgb, vec3(0.2126, 0.7152, 0.0722));

	// разделение тонов: тени уходят в холодный, света в тёплый
	vec3 split = mix(cold * 3.2, warm * 1.15, smoothstep(0.12, 0.78, lum));
	rgb = mix(rgb, rgb * split, tone);

	// воспоминание: сепия и мягкие света
	vec3 sepia = vec3(lum) * vec3(1.08, 0.93, 0.74) + vec3(0.02, 0.012, 0.0);
	rgb = mix(rgb, sepia, memory * 0.88);

	// полутон только в тенях
	float cell = max(dot_size, 2.0);
	vec2 g = fract(FRAGCOORD.xy / cell) - 0.5;
	float dots = smoothstep(0.44, 0.26, length(g));
	float shadow = 1.0 - smoothstep(0.06, 0.40, lum);
	rgb *= 1.0 - halftone * shadow * dots * 0.42;

	// зерно: шаг сетки в два пикселя, меняется двенадцать раз в секунду
	float t = floor(TIME * 12.0);
	float n = hash21(floor(FRAGCOORD.xy / 2.0) + vec2(t * 17.0, t * 31.0)) - 0.5;
	rgb += n * grain * (1.15 - lum);

	rgb = mix(rgb, vec3(1.0), flash);
	COLOR = vec4(clamp(rgb, 0.0, 1.0), c.a);
}
