shader_type canvas_item;
uniform sampler2D water_texture;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

float getHeight(vec2 coord) {
	return textureLod(screen_texture, coord, 0.0).x + textureLod(water_texture, coord, 0.0).x;
}

void fragment() {
    float cell = getHeight(SCREEN_UV);
	
	// One pixel to the side, i.e. 1/64
	vec2 dir = vec2(1.0 / 128.0, 0.0);
    float cellL = getHeight(SCREEN_UV - dir);
    float cellR = getHeight(SCREEN_UV + dir);
    float cellT = getHeight(SCREEN_UV - dir.yx);
    float cellB = getHeight(SCREEN_UV + dir.yx);
	
    COLOR.x = cell * 2.0 + cellL + cellR + cellT + cellB;
	COLOR.x = COLOR.x / 6.0;
	COLOR.y = 0.0;
	COLOR.z = 0.0;
	//COLOR.z = mod(TIME, 10.0) / 10.0;
	if(mod(TIME, 10.0) < 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	}
}