shader_type spatial;
render_mode unshaded;

uniform sampler2D heightmap;
uniform sampler2D normalmap;

varying vec2 pos;

void vertex() {
	pos = VERTEX.xz / 64.0 + 0.5;
	vec4 height = texture(heightmap, pos);
	VERTEX.y += (height.x + height.y) * 20.0;
	//COLOR.xyz = vec3(height / amplitude);
	//COLOR.xyz = vec3((height - 0.5) / amplitude / 4.0,(height - 0.25) / amplitude / 4.0,1.0);
	COLOR.r = (height.x - 0./3.) * 3.0;
	COLOR.g = (height.x - 1./3.) * 3.0;
	COLOR.b = (height.x - 2./3.) * 3.0;
	if(height.x < 0.01) {
		COLOR.b = 1.0;
	}
}

void fragment() {
	//COLOR.xyz = vec3(1.0,0.0,0.0);
	ALBEDO = COLOR.xyz;
	NORMAL_MAP = texture(normalmap, pos).xyz;
}