#[compute]
#version 450
// layout(local_size_x = 8, local_size_y = 8) in;

// R - Heightmap - Water
// G - Heightmap - Terrain
// B
// A
layout(set = 0, binding = 0, rgba32f) readonly restrict uniform image2D map_in;
layout(set = 1, binding = 0, rgba32f) readonly restrict uniform image2D map_out;

// R - Flux left
// G - Flux right
// B - Flux top
// A - Flux bottom
layout(set = 2, binding = 0, rgba32f) readonly restrict uniform image2D flux_in;
layout(set = 3, binding = 0, rgba32f) uniform image2D flux_out;

layout(push_constant, std430) uniform Params {
// X - Viscosity
    // A value of 1.0 that the whole difference is added to the current flux
    // A lower value represents a slower liquid, similar to viscosity (though not the same)
// Y - Decay
    // Decay of previous flux. 0.0 means no decay, 1.0 maximal decay
    // In the simulation, waves can annihilate each other and so the water will calm even without decay.
// Z -
// A -
	vec4 params;
};

float height_total(ivec2 cell_idx) {
    // ivec2 size = imageSize(map_in);
    vec4 map = imageLoad(map_in, cell_idx);
    return map.x + map.y;
}

float height_water(ivec2 cell_idx) {
    // ivec2 size = imageSize(map_in);
    vec4 map = imageLoad(map_in, cell_idx);
    return map.x;
}

vec4 flux(ivec2 cell_idx) {
    ivec2 size = imageSize(map_in);
    return imageLoad(flux_in, cell_idx);
}

vec4 calc_flux(ivec2 pos) {
    // Height water and height total
    float h_w = height_water(pos);
    float h_t = height_total(pos);

    // Different directions. Right, Down, Down-left, Down-right
    ivec2 d_r = ivec2(1, 0);
    ivec2 d_d = ivec2(0, 1);
    ivec2 d_dl = ivec2(-1, 1);
    ivec2 d_dr = ivec2(1, 1);

    // The values shown in the UI are scaled because its hard to count zeros in e.g. 0.00001
    float viscos = params.x / 1000.0;
    float d = 1.0 - (params.y / 1000.0);

    float flux_r = d * flux(pos).r + viscos * (h_t - height_total(pos + d_r));
    float flux_d = d * flux(pos).g + viscos * (h_t - height_total(pos + d_d));
    float flux_dl = d * flux(pos).b + viscos * (h_t - height_total(pos + d_dl)) / 1.41;
    float flux_dr = d * flux(pos).a + viscos * (h_t - height_total(pos + d_dr)) / 1.41;


    float sqrt2_inv = 1.0 / 1.41;
    // 8 pipes in total but 4 of them are orthogonal and 4 four diagonal. The diagonal ones are prioritized less
    float num_pipes = 4 * (1.0 + sqrt2_inv);

    // TODO The upper limit is not checked because we never reach it.
    // Rather, I assume we never reach it. Verify this

    // The signs are tricky. Flows to the right are positive, to the left are negative.
    // Limiting the flow can be done in the form
    // - min(height(pos_right), - flux_right)
    // as the flow from the left is -flux_right
    // The above formula can also be rewritten by pushing the - inside the min
    // max( -height(pos_right), flux_right)
    // This latter form is the one used here
    flux_r = min(height_water(pos) / num_pipes, flux_r);
    flux_r = - min(height_water(pos + d_r) / num_pipes, -flux_r);

    flux_d = min(height_water(pos) / num_pipes, flux_d);
    flux_d = - min(height_water(pos + d_d) / num_pipes, -flux_d);

    flux_dl = min(height_water(pos) / num_pipes * sqrt2_inv, flux_dl);
    flux_dl = - min(height_water(pos + d_dl) / num_pipes * sqrt2_inv, -flux_dl);

    flux_dr = min(height_water(pos) / num_pipes * sqrt2_inv, flux_dr);
    flux_dr = - min(height_water(pos + d_dr) / num_pipes * sqrt2_inv, -flux_dr);

    return vec4(flux_r, flux_d, flux_dl, flux_dr);
}

void main() {
  ivec2 cell_idx = ivec2(gl_GlobalInvocationID.xy);
  vec4 flux_new = calc_flux(cell_idx);
  ivec2 size = imageSize(flux_in);
  if(cell_idx.x == 0)
      flux_new.b = 0.0;
  if(cell_idx.y == 0) {

  }
  if(cell_idx.x == size.x - 1) {
      flux_new.r = 0.0;
      flux_new.a = 0.0;
  }
  if(cell_idx.y == size.y - 1) {
      flux_new.g = 0.0;
      flux_new.b = 0.0;
      flux_new.a = 0.0;
  }
  imageStore(flux_out, cell_idx, flux_new);
}
