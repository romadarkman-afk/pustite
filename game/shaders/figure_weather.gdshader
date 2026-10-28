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

// 4) Живая сетка. Фотография целая, поэтому сетка гнёт только то, что гнётся у человека:
// ноги качаются вокруг тазобедренных суставов, верх корпуса клонится вокруг пояса, голова поворачивается вокруг шеи.
// Все значения по умолчанию нулевые: без анимации вершины стоят на месте. Размеры в единицах посёлка.
uniform vec2 fig = vec2(60.0, 85.0);                      // ширина и рост фигуры
uniform vec4 anat = vec4(0.53, 0.04, 0.17, 0.0);          // пояс (доля роста сверху), полуширина перехода, шея, сдвиг центра ног (доля ширины)
uniform vec4 anat2 = vec4(0.0, 0.1, 0.07, 1.0);           // 1 если ноги разведены, ширина перехода между ногами (доля ширины), полуширина таза (доля ширины), начало стопы (доля роста)
uniform vec4 legs_anim = vec4(0.0);                       // угол левой и правой ноги (рад, плюс вперёд), подъём стопы левой и правой (единицы)
uniform vec4 body_anim = vec4(0.0);                       // опускание всего тела (вниз плюс), смещение таза вбок, подъём груди на вдохе, наклон верха вокруг пояса (рад, плюс вперёд)
uniform vec4 head_anim = vec4(0.0);                       // поворот головы вокруг шеи (рад), сдвиг вбок, сдвиг по высоте, резерв

vec2 rot2(vec2 v, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

void vertex() {
	vec2 p = VERTEX;
	float y = 1.0 + p.y / fig.y;                          // 0 макушка, 1 подошвы
	float x = p.x / fig.x - anat.w;                       // от оси ног, доли ширины
	float hip_y = (anat.x - 1.0) * fig.y;
	// верх корпуса клонится вокруг пояса; ниже пояса держит нога
	float upper = 1.0 - smoothstep(anat.x - anat.y, anat.x + anat.y, y);
	vec2 waist = vec2(anat.w * fig.x, hip_y);
	p += upper * (rot2(p - waist, body_anim.w) - (p - waist));
	// ноги: каждая вращается вокруг своего сустава, между ногами плавный переход,
	// стопа поворачивается назад (anat2.w доля роста, с которой начинается стопа; 1 если стопы не видно)
	float leg = 1.0 - upper;
	float wr = smoothstep(-anat2.y, anat2.y, x);
	float wl = 1.0 - wr;
	vec2 hl = vec2((anat.w - anat2.z) * fig.x, hip_y);
	vec2 hr = vec2((anat.w + anat2.z) * fig.x, hip_y);
	float along = clamp((y - anat.x) / max(1.0 - anat.x, 0.01), 0.0, 1.0);
	float ankle = (anat2.w - 1.0) * fig.y;
	float ankle_along = clamp((anat2.w - anat.x) / max(1.0 - anat.x, 0.01), 0.0, 1.0);
	float ft = smoothstep(anat2.w, anat2.w + 0.03, y);
	vec2 ql = hl + rot2(VERTEX - hl, legs_anim.x) + vec2(0.0, -legs_anim.z * along);
	vec2 qr = hr + rot2(VERTEX - hr, legs_anim.y) + vec2(0.0, -legs_anim.w * along);
	vec2 al = hl + rot2(vec2(hl.x, ankle) - hl, legs_anim.x) + vec2(0.0, -legs_anim.z * ankle_along);
	vec2 ar = hr + rot2(vec2(hr.x, ankle) - hr, legs_anim.y) + vec2(0.0, -legs_anim.w * ankle_along);
	ql = mix(ql, al + rot2(ql - al, -0.85 * legs_anim.x), ft);
	qr = mix(qr, ar + rot2(qr - ar, -0.85 * legs_anim.y), ft);
	p += leg * (wl * (ql - VERTEX) + wr * (qr - VERTEX));
	// таз уходит вбок над опорной ногой, стопы остаются на земле
	p.x += body_anim.y * (1.0 - smoothstep(anat.x, 1.0, y));
	// на вдохе грудь и плечи поднимаются, к поясу всё меньше
	p.y -= body_anim.z * clamp(1.0 - y / max(anat.x, 0.01), 0.0, 1.0);
	// голова поворачивается и сдвигается вокруг шеи
	float head = 1.0 - smoothstep(anat.z - 0.025, anat.z + 0.02, y);
	vec2 neck = vec2(anat.w * fig.x, (anat.z - 1.0) * fig.y);
	neck += rot2(neck - waist, body_anim.w) - (neck - waist);   // шея едет вместе с наклоном корпуса
	neck.x += body_anim.y;
	p += head * (rot2(p - neck, head_anim.x) - (p - neck) + head_anim.yz);
	p.y += body_anim.x;
	VERTEX = p;
}

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
