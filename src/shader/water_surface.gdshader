shader_type spatial;

uniform bool fluxvis;
uniform bool energyvis;
uniform vec4 color;
uniform float heightscale;
uniform sampler2D heightmap;
uniform sampler2D fluxmap;

float sum(vec2 xy) {
	return xy.x + xy.y;
}

float mag(vec4 v) {
	vec4 sq = v * v;
	return sqrt(sq.x + sq.y + sq.z + sq.w);
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
varying flat vec4 color2;
varying vec4 flux;
void vertex() {
	vec4 height = texture(heightmap, UV);
	flux = texture(fluxmap, UV);

    VERTEX.y += height.y * heightscale;
	if(energyvis) {
		VERTEX.y += height.x * heightscale + mag(flux) * 10000.0;
	} else {
   		VERTEX.y += height.x * heightscale;
	}
	VERTEX.y += 0.001 * heightscale;
	water_height = height.x;
	COLOR = color;
	if(height.z > 0.0
		&& false) {
		COLOR = vec4(1.0, 0.0, 0.0, 1.0);
		water_height = 1.0;
	}
	float mult = 1000.;
	color2.r = flux.x * mult;
	color2.g = flux.y * mult;
	color2.b = flux.z * mult;
    NORMAL = calc_normal(UV);
}

void fragment() {
	RIM = 0.5;
	METALLIC = 0.0;
	ROUGHNESS = 0.1;
	if(fluxvis)
		ALBEDO = color2.xyz;
	else
		ALBEDO = COLOR.xyz;
	ALPHA = 1.0;
	float threshold = 0.003 - 2000000.0 * mag(flux) * mag(flux);
	threshold = max(0.00000000001, threshold);
	// TODO ideally: hard boundaries when delta water_height is large (FLUX?!)
	// This gives smooth boundaries near streams (which are often only one cell)
	// but hard ones around lakes
	if(water_height <= threshold && !energyvis) {
		ALPHA = water_height / threshold;
	}
}
