shader_type canvas_item;
// Тени от облаков ползут по земле. Картинка clouds.png листается шейдером в двух слоях
// с разной скоростью, поэтому тени не повторяются в лоб.

uniform sampler2D clouds : repeat_enable, filter_linear;
uniform vec2 area_size = vec2(816.0, 609.0);
uniform vec2 wind_dir = vec2(1.0, 0.12);
uniform float speed = 9.0;
uniform float scale_px = 1500.0;
uniform float cloudiness : hint_range(0.0, 1.0) = 0.3;
uniform float strength : hint_range(0.0, 1.0) = 0.34;
uniform float night : hint_range(0.0, 1.0) = 0.0;
uniform vec3 shade = vec3(0.03, 0.05, 0.09);

void fragment() {
	vec2 pos = UV * area_size;
	vec2 drift = wind_dir * TIME * speed;
	vec2 size1 = vec2(scale_px, scale_px * 0.25);
	vec2 size2 = vec2(scale_px * 0.62, scale_px * 0.155);
	float a1 = texture(clouds, (pos - drift) / size1).a;
	float a2 = texture(clouds, (pos - drift * 1.7) / size2 + vec2(0.31, 0.5)).a;
	float c = max(a1, a2 * 0.85);
	float thr = mix(0.62, 0.08, cloudiness);
	c = smoothstep(thr, thr + 0.4, c);
	// у краёв области тень сходит на нет, чтобы не было резкой рамки
	vec2 e = min(UV, 1.0 - UV);
	c *= smoothstep(0.0, 0.08, min(e.x, e.y));
	COLOR = vec4(shade, c * strength * (1.0 - 0.8 * night));
}
