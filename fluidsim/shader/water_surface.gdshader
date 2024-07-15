shader_type spatial;

uniform vec4 color;
uniform float heightscale;
uniform sampler2D heightmap;

float sum(vec2 xy) {
	return xy.x + xy.y;
}

vec3 calc_normal(vec2 uv) { 
    const vec3 off = vec3(-1,0,1);
    vec2 texelSize = 1.0 / vec2(textureSize(heightmap, 0));
	
    float left = sum(texture(heightmap, uv + texelSize * off.xy).xy * heightscale);
    float right = sum(texture(heightmap, uv + texelSize * off.zy).xy * heightscale);
    float top = sum(texture(heightmap, uv + texelSize * off.yx).xy * heightscale);
    float down = sum(texture(heightmap, uv + texelSize * off.yz).xy * heightscale);

    return normalize(vec3(left-right, 2.0, down-top));
}

varying float water_height;
void vertex() {
	vec4 height = texture(heightmap, UV);
   	VERTEX.y += height.x * heightscale;
    VERTEX.y += height.y * heightscale;
	water_height = height.x;
	COLOR = color;
	if(height.z > 0.0
		&& false) {
		COLOR = vec4(1.0, 0.0, 0.0, 1.0);
		water_height = 1.0;
	}
    NORMAL = calc_normal(UV);
}

void fragment() {
	RIM = 0.5;
	METALLIC = 0.0;
	ROUGHNESS = 0.1;
	ALBEDO = COLOR.xyz;
	ALPHA = 1.0;
	float threshold = 0.00001;
	// TODO ideally: hard boundaries when delta water_height is large (FLUX?!)
	// This gives smooth boundaries near streams (which are often only one cell)
	// but hard ones around lakes
	if(water_height <= threshold) {
		ALPHA = water_height / threshold;
	}
}
