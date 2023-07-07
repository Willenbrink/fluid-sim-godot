shader_type spatial;
render_mode unshaded;

uniform sampler2D heightmap;
uniform sampler2D normalmap;

varying vec2 pos;

void vertex() {
	pos = VERTEX.xz / 64.0 + 0.5;
	float height = texture(heightmap, pos).x;
	VERTEX.y += height * 50.0;
	//COLOR.xyz = vec3(height / amplitude);
	//COLOR.xyz = vec3((height - 0.5) / amplitude / 4.0,(height - 0.25) / amplitude / 4.0,1.0);
	COLOR.r = (height - 0./3.) * 3.0;
	COLOR.g = (height - 1./3.) * 3.0;
	COLOR.b = (height - 2./3.) * 3.0;
}

void fragment() {
	//COLOR.xyz = vec3(1.0,0.0,0.0);
	ALBEDO = COLOR.xyz;
	NORMAL_MAP = texture(normalmap, pos).xyz;
}