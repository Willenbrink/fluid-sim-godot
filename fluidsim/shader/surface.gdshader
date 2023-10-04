shader_type spatial;
render_mode specular_toon;

uniform bool water;
uniform vec4 color;
uniform float heightscale;
uniform sampler2D heightmap;
// uniform sampler2D normalmap;

vec3 calc_normal(vec2 uv) { 
    const vec3 off = vec3(-1,0,1);
    vec2 texelSize = 1.0 / vec2(textureSize(heightmap, 0));

    float left = texture(heightmap, uv + texelSize * off.xy).x * heightscale;
    float right = texture(heightmap, uv + texelSize * off.zy).x * heightscale;
    float top = texture(heightmap, uv + texelSize * off.yx).x * heightscale;
    float down = texture(heightmap, uv + texelSize * off.yz).x * heightscale;

    return normalize(vec3(left-right, 2.0, down-top));
}


void vertex() {
	vec2 pos = UV;
	vec4 height = texture(heightmap, pos);
    if(water) {
    	VERTEX.y += height.x * heightscale;
    }
    VERTEX.y += height.y * heightscale;
	//COLOR.xyz = vec3(height / amplitude);
	//COLOR.xyz = vec3((height - 0.5) / amplitude / 4.0,(height - 0.25) / amplitude / 4.0,1.0);
	COLOR = color;
	if(water && height.x <= 0.01) {
		COLOR.w = 0.0;
	}
    NORMAL = calc_normal(UV);
}

void fragment() {
	float fresnel = sqrt(1.0 - dot(NORMAL, VIEW));
    //COLOR.xyz = vec3(1.0,0.0,0.0);
	RIM = 0.2;
	METALLIC = 0.0;
	ROUGHNESS = 0.01 * (1.0 - fresnel);
	//ALBEDO = COLOR.xyz;
	ALBEDO = vec3(0.01, 0.03, 0.05) + (0.1 * fresnel);
	//ALPHA = COLOR.w;
	// NORMAL_MAP = texture(normalmap, pos).xyz;
}
