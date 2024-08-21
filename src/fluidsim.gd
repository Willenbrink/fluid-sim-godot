#@tool
extends Area3D

@export var run = true;
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
@export var viscosity = 0.1;
@export var decay = 1.0;
@export var water_initial_height = 0.05;
@export var brush_water = 0.2;

@export var height_threshold : float :
	get: return height_threshold
	set(value):
		height_threshold = value
		$WaterSurface.material_override.set_shader_parameter("height_threshold", value)
		
@export var flux_enhancer : float :
	get: return flux_enhancer
	set(value):
		flux_enhancer = value
		$WaterSurface.material_override.set_shader_parameter("flux_enhancer", value)

var rd: RenderingDevice
var flux_shader_file: RDShaderFile = preload("res://src/shader/flux.glsl")
var height_shader_file: RDShaderFile = preload("res://src/shader/pipes.glsl")

# Arrays where 0 stores the shader RID and 1 the pipeline RID
var flux_shader_pipeline: Array
var height_shader_pipeline: Array

@export var texture_size = Vector2i(256,256)
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

var mouse_pos = Vector3(0, 0, 0)
var fill_water = 0
@export var brush_size = 1

func _ready() -> void:
	# Data for compute shaders has to come as an array of bytes
	await noise_terrain.changed
	init()

func init() -> void:
	var terrain_image := noise_terrain.get_image()
	terrain_image.decompress()
	
	var heightmap = Image.create(texture_size.x, texture_size.y, false, image_format)
	for i in texture_size.x:
		for j in texture_size.y:
			var water = Color(water_initial_height, 0.0, 0.0, 0.0)
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
	tex_map_format.depth = 1
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
	if (run):
		process_real()

func process_real():
	# Based on https://github.com/godotengine/godot-demo-projects/blob/4.2-31d1c0c/compute/texture/water_plane/water_plane.gd
	var flux_params : PackedFloat32Array = PackedFloat32Array()
	flux_params.push_back(viscosity)
	flux_params.push_back(decay)
	flux_params.push_back(0.0)
	flux_params.push_back(0.0)
	
	var pipes_params : PackedFloat32Array = PackedFloat32Array()
	var u : int = (mouse_pos.x + 512 / 2) / 512 * texture_size.x;
	var v : int = (mouse_pos.z + 512 / 2) / 512 * texture_size.y;
	pipes_params.push_back(u)
	pipes_params.push_back(v)
	pipes_params.push_back(brush_size)
	pipes_params.push_back(brush_water if fill_water == 1 else -brush_water if fill_water == 2 else 0.0)
	RenderingServer.call_on_render_thread(compute.bind(accel_factor if accelerate else 1, flux_params, pipes_params))

func compute(num_iter, flux_params, pipes_params) -> void:
	for n in num_iter:
		# Process:
		# list begin: Start compute list to start recording compute commands
		# bind pipeline: Bind the pipeline and shader
		# bind uniform: Binds the uniform set with the data we want to give to the shader
		# add barrier: Prevent second half from running before ALL invocations of the first are done
		
		var compute_list := rd.compute_list_begin()
		rd.compute_list_bind_compute_pipeline(compute_list, flux_shader_pipeline[1])
		rd.compute_list_bind_uniform_set(compute_list, uniform_set_height_in, 0)
		rd.compute_list_bind_uniform_set(compute_list, uniform_set_height_out, 1)
		rd.compute_list_bind_uniform_set(compute_list, uniform_set_flux_in, 2)
		rd.compute_list_bind_uniform_set(compute_list, uniform_set_flux_out, 3)
		rd.compute_list_set_push_constant(compute_list, flux_params.to_byte_array(), flux_params.size() * 4)
		rd.compute_list_dispatch(compute_list, texture_size.x, texture_size.y, 1)
		
		rd.compute_list_add_barrier(compute_list)
		
		rd.compute_list_bind_compute_pipeline(compute_list, height_shader_pipeline[1])
		rd.compute_list_bind_uniform_set(compute_list, uniform_set_height_in, 0)
		rd.compute_list_bind_uniform_set(compute_list, uniform_set_height_out, 1)
		rd.compute_list_bind_uniform_set(compute_list, uniform_set_flux_in, 2)
		rd.compute_list_bind_uniform_set(compute_list, uniform_set_flux_out, 3)
		rd.compute_list_set_push_constant(compute_list, pipes_params.to_byte_array(), pipes_params.size() * 4)
		rd.compute_list_dispatch(compute_list, texture_size.x, texture_size.y, 1)
		rd.compute_list_end()
		
		var flux_tmp = uniform_set_flux_in
		var height_tmp = uniform_set_height_in
		uniform_set_flux_in = uniform_set_flux_out
		uniform_set_flux_out = flux_tmp
		uniform_set_height_in = uniform_set_height_out
		uniform_set_height_out = height_tmp
	
	
# UI related functions. Note that there is NO two-way coupling.
# Modifying the (default) values will not modify the displayed UI values
# Could be fixed but wasn't important enough for the demo
func _input_event(camera, event, position, normal, shape_idx):
	mouse_pos = position
	event.is_pressed()
	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		fill_water = 1
	elif event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_MIDDLE:
		fill_water = 2
	if event is InputEventMouseButton and event.is_released() and (event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_MIDDLE):
		fill_water = 0

func _on_button_pressed() -> void:
	step = true


func _on_button_2_pressed() -> void:
	reset = true


func _on_init_water_value_changed(value: float) -> void:
	water_initial_height = value


func _on_brush_water_value_changed(value: float) -> void:
	brush_water = value


func _on_brush_radius_value_changed(value: float) -> void:
	brush_size = value


func _on_acceleration_factor_value_changed(value: float) -> void:
	accel_factor = value


func _on_accelerate_toggled(toggled_on: bool) -> void:
	accelerate = !accelerate


func _on_run_toggled(toggled_on: bool) -> void:
	run = toggled_on


func _on_noise_seed_value_changed(value: float) -> void:
	noise_terrain.noise.seed = value


func _on_spin_box_value_changed(value: float) -> void:
	texture_size.x = value
	texture_size.y = value
	noise_terrain.width = value
	noise_terrain.height = value


func _on_viscosity_value_changed(value: float) -> void:
	viscosity = value


func _on_decay_value_changed(value: float) -> void:
	decay = value


func _on_height_threshold_value_changed(value: float) -> void:
	height_threshold = value / 1000.0


func _on_river_magnifier_value_changed(value: float) -> void:
	flux_enhancer = value * 1000.0
