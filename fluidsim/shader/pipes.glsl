#[compute]
#version 450
layout(local_size_x = 8, local_size_y = 8) in;

layout(set = 0, binding = 0, rgba32f) uniform image2D map_in;
layout(set = 0, binding = 1, rgba32f) uniform image2D map_out;

vec4 getCell(ivec2 cell_idx) {
    return imageLoad(map_in, cell_idx);
}

// Simulate the pipes between two cells
float equalize(ivec2 pos_curr, ivec2 pos_neigh) {
    float val_curr = clamp(getCell(pos_curr).x, 0.0, 1.0);
    float val_neigh = clamp(getCell(pos_neigh).x, 0.0, 1.0);
    return (val_neigh - val_curr) / 4.0;
}

float sim_cell(ivec2 pos) {
  ivec2 dir = ivec2(1, 0);

  float height_old = getCell(pos).x;
  float height_new = height_old;
  height_new += equalize(pos, pos - dir);
  height_new += equalize(pos, pos + dir);
  height_new += equalize(pos, pos - dir.yx);
  height_new += equalize(pos, pos + dir.yx);

  return height_new;
}

void main() {
  ivec2 gidx = ivec2(gl_GlobalInvocationID.xy);
  float height_new = sim_cell(gidx);
  imageStore(map_out, gidx, vec4(height_new, 0.0, 0.0, 1.0));
}
