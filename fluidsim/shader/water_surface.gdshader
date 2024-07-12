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
    NORMAL = calc_normal(UV);
}

void fragment() {
	RIM = 0.5;
	METALLIC = 0.0;
	ROUGHNESS = 0.1;
	ALBEDO = color.xyz;
	ALPHA = 1.0;
	if(water_height <= 0.005) {
		ALPHA = water_height * 50.0;
	}
}
