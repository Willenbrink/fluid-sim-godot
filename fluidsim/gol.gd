@tool
extends Area3D

@export var run_in_editor = false;
@export var step : bool :
	get: return false
	set(_value):
		step = false
		process_real()
@export var show_flux = false;
@export var reset : bool :
	get: return false
	set(_value):
		reset = false
		init()
@export var accelerate = false;
@export var accel_factor = 5;

var rd: RenderingDevice
var flux_shader_file: RDShaderFile = preload("res://fluidsim/shader/flux.glsl")
var height_shader_file: RDShaderFile = preload("res://fluidsim/shader/pipes.glsl")

# Arrays where 0 stores the shader RID and 1 the pipeline RID
var flux_shader_pipeline: Array
var height_shader_pipeline: Array

@export var texture_size = Vector2i(256,256)
@export var noise_water: Texture2D
@export var noise_terrain: Texture2D

var texture_water : Texture2DRD
var tex_flux_water : Texture2DRD
var texture_terrain : Texture2DRD

var tex_height_in: RID
var tex_height_out: RID
var tex_flux_in: RID
var tex_flux_out: RID

var uniform_set_height_in
var uniform_set_height_out
var uniform_set_flux_in
var uniform_set_flux_out

# Keep those in sync!
var image_format := Image.FORMAT_RGBAF
var data_format := RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT

var mouse_pos = null
var fill_water = true
var brush_size = 3

func _ready() -> void:
	# Data for compute shaders has to come as an array of bytes
	await noise_water.changed
	await noise_terrain.changed
	init()

func init() -> void:
	var water_image := noise_water.get_image()
	var terrain_image := noise_terrain.get_image()
	water_image.decompress()
	terrain_image.decompress()
	
	var heightmap = Image.create(texture_size.x, texture_size.y, false, image_format)
	for i in texture_size.x:
		for j in texture_size.y:
			var water = water_image.get_pixel(i, j) * 0.1
			water = Color(0.05, 0.0, 0.0)
			var terrain = terrain_image.get_pixel(i, j)
			heightmap.set_pixel(i, j, Color(water.r, terrain.r, 0.0, 1.0))
	
	RenderingServer.call_on_render_thread(init_render.bind(heightmap.get_data()))
	
	var material_water = $WaterSurface.material_override
	var material_terrain = $TerrainSurface.material_override
	if not material_water or not material_terrain:
		print("Failed to get material")
		set_process(false)
		return
	texture_water = material_water.get_shader_parameter("heightmap")
	tex_flux_water = material_water.get_shader_parameter("fluxmap")
	texture_terrain = material_terrain.get_shader_parameter("heightmap")
	texture_water.texture_rd_rid = tex_height_in
	tex_flux_water.texture_rd_rid = tex_flux_in
	texture_terrain.texture_rd_rid = tex_height_in

func create_shader(file: RDShaderFile):
	var spirv := file.get_spirv()
	var shader = rd.shader_create_from_spirv(spirv)
	var pipeline = rd.compute_pipeline_create(shader)
	return [shader, pipeline]
	
func create_uniform_set(tex_rid, shader):
	var uniform = RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = 0
	uniform.add_id(tex_rid)
	return rd.uniform_set_create([uniform], shader, 0)
	
func init_render(heightmap_initial) -> void:
	rd = RenderingServer.get_rendering_device()
	if not rd:
		set_process(false)
		print("Compute shaders are not available")
		return
	
	height_shader_pipeline = create_shader(height_shader_file)
	flux_shader_pipeline = create_shader(flux_shader_file)


	var tex_map_format := RDTextureFormat.new()
	tex_map_format.width = texture_size.x
	tex_map_format.height = texture_size.y
	tex_map_format.depth = 4
	tex_map_format.format = data_format
	tex_map_format.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	tex_map_format.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
		| RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
		| RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
		| RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
		| RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT
	)
	var tex_view := RDTextureView.new()
	tex_height_in = rd.texture_create(tex_map_format, tex_view, [heightmap_initial])
	tex_height_out = rd.texture_create(tex_map_format, tex_view, [])
	tex_flux_in = rd.texture_create(tex_map_format, tex_view, [])
	tex_flux_out = rd.texture_create(tex_map_format, tex_view, [])
	
	#rd.texture_clear(tex_height_A, Color(0, 0, 0, 0), 0, 1, 0, 1)
	rd.texture_clear(tex_height_out, Color(0, 0, 0, 0), 0, 1, 0, 1)
	rd.texture_clear(tex_flux_in, Color(0, 0, 0, 0), 0, 1, 0, 1)
	rd.texture_clear(tex_flux_out, Color(0, 0, 0, 0), 0, 1, 0, 1)
	
	uniform_set_height_in = create_uniform_set(tex_height_in, flux_shader_pipeline[0])
	uniform_set_height_out = create_uniform_set(tex_height_out, flux_shader_pipeline[0])
	uniform_set_flux_in = create_uniform_set(tex_flux_in, flux_shader_pipeline[0])
	uniform_set_flux_out = create_uniform_set(tex_flux_out, flux_shader_pipeline[0])
	
	# Great fun, there are no primitives, only buffers
# https://old.reddit.com/r/godot/comments/1510ge1/uniforms_vs_buffers_in_compute_shaders_and_how_do/kxmxtqz/
	
	#var buffer := rd.storage_buffer_create(16, [0.1, 0.2, 0.3, 0.4])
	#var uniform_fluid = RDUniform.new()
	#uniform_fluid.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	#uniform_fluid.binding = 0
	#uniform_fluid.add_id(buffer)
	#uniform_set_variables = rd.uniform_set_create([uniform_fluid], flux_shader_pipeline[0], 0)
	

# func _exit_tree() -> void:
# 	free()
	
func free() -> void:
	rd.free_rid(height_shader_pipeline[0])
	rd.free_rid(height_shader_pipeline[1])
	rd.free_rid(flux_shader_pipeline[0])
	rd.free_rid(flux_shader_pipeline[1])

func _process(_delta: float) -> void:
	#place_fluid()
	if (not Engine.is_editor_hint() || run_in_editor):
		process_real()

func process_real():
	if mouse_pos != null:
		var u = (mouse_pos.x + 256) / 512 * 100;
		var v = (mouse_pos.z + 256) / 512 * 100;
		print("Left", mouse_pos, u, v)
		#image_height.set_pixel(u, v, Color(1.0, 0.0, 0.0, 1.0))
	RenderingServer.call_on_render_thread(compute.bind(accel_factor if accelerate else 1))
	#texture_water.texture_rd_rid = tex_height_A
	#texture_terrain.texture_rd_rid = tex_height_A

func compute(num_iter) -> void:
	for n in num_iter:
		# Process:
		# list begin: Start compute list to start recording our compute commands
		# bind pipeline: Bind the pipeline, this tells the GPU what shader to use
		# bind uniform: Binds the uniform set with the data we want to give our shader
		# list end: Tell the GPU we are done with this compute task
		# submit and sync: start and await computation
		
		var compute_list := rd.compute_list_begin()
		rd.compute_list_bind_compute_pipeline(compute_list, flux_shader_pipeline[1])
		rd.compute_list_bind_uniform_set(compute_list, uniform_set_height_in, 0)
		rd.compute_list_bind_uniform_set(compute_list, uniform_set_height_out, 1)
		rd.compute_list_bind_uniform_set(compute_list, uniform_set_flux_in, 2)
		rd.compute_list_bind_uniform_set(compute_list, uniform_set_flux_out, 3)
		rd.compute_list_dispatch(compute_list, texture_size.x, texture_size.y, 1)
		
		#rd.barrier(RenderingDevice.BARRIER_MASK_COMPUTE)
		rd.compute_list_add_barrier(compute_list)
		
		rd.compute_list_bind_compute_pipeline(compute_list, height_shader_pipeline[1])
		rd.compute_list_bind_uniform_set(compute_list, uniform_set_height_in, 0)
		rd.compute_list_bind_uniform_set(compute_list, uniform_set_height_out, 1)
		rd.compute_list_bind_uniform_set(compute_list, uniform_set_flux_in, 2)
		rd.compute_list_bind_uniform_set(compute_list, uniform_set_flux_out, 3)
		rd.compute_list_dispatch(compute_list, texture_size.x, texture_size.y, 1)
		rd.compute_list_end()
		
		var flux_tmp = uniform_set_flux_in
		var height_tmp = uniform_set_height_in
		uniform_set_flux_in = uniform_set_flux_out
		uniform_set_flux_out = flux_tmp
		uniform_set_height_in = uniform_set_height_out
		uniform_set_height_out = height_tmp
	#texture_water.texture_rd_rid = tex_height_in
	#texture_terrain.texture_rd_rid = tex_height_in


func _on_static_body_3d_input_event(camera, event, position, normal, shape_idx):
	if event is InputEventMouseButton and (
		event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT):
		mouse_pos = position if event.pressed else null
		fill_water = event.button_index == MOUSE_BUTTON_LEFT
	else:
		mouse_pos = position if mouse_pos != null else null
