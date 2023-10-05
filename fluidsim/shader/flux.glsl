#[compute]
#version 450
// layout(local_size_x = 8, local_size_y = 8) in;

// R - Heightmap - Water
// G - Heightmap - Terrain
// B
// A
layout(set = 0, binding = 0, rgba32f) uniform image2D map_in;
layout(set = 0, binding = 2, rgba32f) uniform image2D map_out;

// R - Flux left
// G - Flux right
// B - Flux top
// A - Flux bottom
layout(set = 0, binding = 1, rgba32f) uniform image2D flux_in;
layout(set = 0, binding = 3, rgba32f) uniform image2D flux_out;

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
    // Different directions. Right, Down, Down-left, Down-right
    ivec2 d_r = ivec2(1, 0);
    ivec2 d_d = ivec2(0, 1);
    ivec2 d_dl = ivec2(-1, 1);
    ivec2 d_dr = ivec2(1, 1);

    // A value of 1.0 that the whole difference is added to the current flux
    // A lower value represents a slower liquid, similar to viscosity (though not the same)
    float viscos = 0.000001;
    float d = 0.9998;
    // float d = 1.0;
    float flux_r = d * flux(pos).r + viscos * (height_total(pos) - height_total(pos + d_r));
    float flux_d = d * flux(pos).g + viscos * (height_total(pos) - height_total(pos + d_d));
    float flux_dl = d * flux(pos).b + viscos * (height_total(pos) - height_total(pos + d_dl));
    float flux_dr = d * flux(pos).a + viscos * (height_total(pos) - height_total(pos + d_dr));

    int num_pipes = 2;

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
    flux_r = max(-height_water(pos + d_r) / num_pipes, flux_r);
    // flux_r = max((-1.0 + height(pos + d_r)) / num_pipes, flux_r);
    // flux_r = min(( 1.0 - height(pos)) / num_pipes, flux_r);

    flux_d = min(height_water(pos) / num_pipes, flux_d);
    flux_d = max(-height_water(pos + d_d) / num_pipes, flux_d);
    // flux_d = max((-1.0 + height(pos + d_d)) / num_pipes, flux_d);
    // flux_d = min(( 1.0 - height(pos)) / num_pipes, flux_d);

    flux_dl = min(height_water(pos) / num_pipes, flux_dl);
    flux_dl = max(-height_water(pos + d_dl) / num_pipes, flux_dl);
    // flux_dl = max((-1.0 + height(pos + d_dl)) / num_pipes, flux_dl);
    // flux_dl = min(( 1.0 - height(pos)) / num_pipes, flux_dl);

    flux_dr = min(height_water(pos) / num_pipes, flux_dr);
    flux_dr = max(-height_water(pos + d_dr) / num_pipes, flux_dr);
    // flux_dr = max((-1.0 + height(pos + d_dr)) / num_pipes, flux_dr);
    // flux_dr = min(( 1.0 - height(pos)) / num_pipes, flux_dr);

    // TODO experiment: Dampen extreme fluxes, hopefully equivalent to a low-pass on the frequency of the waves
    // float exp = 0;
    // flux_r *= pow(1-abs(flux_r), exp);
    // flux_d *= pow(1-abs(flux_d), exp);
    // flux_dl *= pow(1-abs(flux_dl), exp);
    // flux_dr *= pow(1-abs(flux_dr), exp);

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
