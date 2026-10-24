shader_type canvas_item;
// Пучки травы из атласа. Один MultiMesh, одна отрисовка. Качает ветер: верх пучка гуляет,
// низ стоит. Снег ложится шапкой на пучок и совсем закрывает его при сильном покрове.

uniform sampler2D sheet : filter_linear_mipmap;
uniform vec2 frames = vec2(4.0, 2.0);
uniform float wind : hint_range(0.0, 1.0) = 0.2;
uniform float snow : hint_range(0.0, 1.0) = 0.0;
uniform float night : hint_range(0.0, 1.0) = 0.0;
uniform float sway = 0.22;          // размах верхушки в долях ширины пучка (VERTEX здесь в единицах квадрата)
uniform vec3 night_tint = vec3(0.5, 0.58, 0.85);

varying float v_frame;
varying float v_rand;

void vertex() {
	v_frame = INSTANCE_CUSTOM.x;
	v_rand = INSTANCE_CUSTOM.y;
	float h = 1.0 - UV.y;
	float gust = sin(TIME * (1.1 + wind * 1.4) + v_rand * 6.283 + VERTEX.x * 0.03)
		+ 0.45 * sin(TIME * 2.7 + v_rand * 19.0);
	VERTEX.x += gust * (0.35 + wind * 1.2) * sway * pow(h, 1.7);
}

void fragment() {
	vec2 f = vec2(mod(v_frame, frames.x), floor(v_frame / frames.x));
	vec4 c = texture(sheet, (f + UV) / frames);
	float top = 1.0 - UV.y;
	float cap = smoothstep(0.15, 0.9, top + snow * 0.9) * snow;
	vec3 rgb = mix(c.rgb, vec3(0.9, 0.94, 1.0), cap * 0.9);
	rgb *= mix(vec3(1.0), night_tint, night);
	float a = c.a * (1.0 - smoothstep(0.82, 1.0, snow) * (1.0 - top * 0.6));
	COLOR = vec4(rgb, a);
}
