@tool
extends Area3D

@export var run_in_editor = false;
@export var step : bool :
	get: return false
	set(_value):
		step = false
		_process(1)
@export var show_flux = false;
@export var reset : bool :
	get: return false
	set(_value):
		reset = false
		_ready()
@export var accelerate = false;
@export var accel_factor = 5;

var rd: RenderingDevice
var flux_shader_file: RDShaderFile = preload("res://fluidsim/shader/flux.glsl")
var height_shader_file: RDShaderFile = preload("res://fluidsim/shader/pipes.glsl")

# Arrays where 0 stores the shader RID and 1 the pipeline RID
var flux_shader_pipeline: Array
var height_shader_pipeline: Array

@export var texture_size = Vector2i(256,256)
@export var water_noise: Texture2D
@export var terrain_noise: Texture2D

var texture_water : Texture2DRD
var texture_terrain : Texture2DRD

# We use two sets of uniforms, once for reading from A and writing to B
# and the other way round. We need to keep track of this to render the data from the right buffer.
var reading_A: bool
var tex_height_A: RID
var tex_height_B: RID
var tex_flux_A: RID
var tex_flux_B: RID

var data_height_A: PackedByteArray
var data_height_B: PackedByteArray
var data_flux_A: PackedByteArray
var data_flux_B: PackedByteArray

var image_height: Image
var image_flux: Image

var uniform_set_height_A2B: RID
var uniform_set_height_B2A: RID
var uniform_set_flux_A2B: RID
var uniform_set_flux_B2A: RID
# Keep those in sync!
var image_format := Image.FORMAT_RGBAF
var data_format := RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT

var mouse_pos = null
var fill_water = true
var brush_size = 3

func _ready() -> void:
	# Data for compute shaders has to come as an array of bytes
	await water_noise.changed
	await terrain_noise.changed
	var water_image := water_noise.get_image()
	var terrain_image := terrain_noise.get_image()
	water_image.decompress()
	terrain_image.decompress()
	
	image_height = Image.create(texture_size.x, texture_size.y, false, image_format)
	image_flux = Image.create(texture_size.x, texture_size.y, false, image_format)
	for i in texture_size.x:
		for j in texture_size.y:
			var water = water_image.get_pixel(i, j) * 0.1
			water = Color(0.05, 0.0, 0.0)
			var terrain = terrain_image.get_pixel(i, j)
			image_height.set_pixel(i, j, Color(water.r, terrain.r, 0.0, 1.0))
	
	data_height_A = image_height.get_data()
	data_height_B = PackedByteArray()
	data_height_B.resize(data_height_A.size())
	
	image_flux = Image.create(texture_size.x, texture_size.y, false, image_format)
	data_flux_A = image_flux.get_data()
	data_flux_B = PackedByteArray()
	data_flux_B.resize(data_flux_A.size())
	
	RenderingServer.call_on_render_thread(init_render.bind(data_height_A, data_height_B, data_flux_A, data_flux_B))
	
	var material_water = $WaterSurface.material_override
	var material_terrain = $TerrainSurface.material_override
	if not material_water or not material_terrain:
		print("Failed to get material")
		set_process(false)
		return
	texture_water = material_water.get_shader_parameter("heightmap")
	texture_terrain = material_terrain.get_shader_parameter("heightmap")

	#texture_water.texture_rd_rid = water_noise.get_rid()
	texture_water.texture_rd_rid = tex_height_A
	texture_terrain.texture_rd_rid = tex_height_A

func init() -> void:
	pass

func create_shader(file: RDShaderFile):
	var spirv := file.get_spirv()
	var shader = rd.shader_create_from_spirv(spirv)
	var pipeline = rd.compute_pipeline_create(shader)
	return [shader, pipeline]
	
func init_render(data_height_A, data_height_B, data_flux_A, data_flux_B) -> void:
	# We will be using our own RenderingDevice to handle the compute commands
	rd = RenderingServer.get_rendering_device()
	if not rd:
		set_process(false)
		print("Compute shaders are not available")
		return
	
	height_shader_pipeline = create_shader(height_shader_file)
	flux_shader_pipeline = create_shader(flux_shader_file)

	
	reading_A = true

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
	)
	var tex_view_height := RDTextureView.new()
	tex_height_A = rd.texture_create(tex_map_format, tex_view_height, [data_height_A])
	tex_height_B = rd.texture_create(tex_map_format, tex_view_height, [data_height_B])
	
	var tex_view_flux := RDTextureView.new()
	tex_flux_A = rd.texture_create(tex_map_format, tex_view_flux, [data_flux_A])
	tex_flux_B = rd.texture_create(tex_map_format, tex_view_flux, [data_flux_B])
	
	
	var uniform_height_from_A := RDUniform.new()
	uniform_height_from_A.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform_height_from_A.binding = 0
	uniform_height_from_A.add_id(tex_height_A)
	var uniform_height_to_A := RDUniform.new()
	uniform_height_to_A.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform_height_to_A.binding = 2
	uniform_height_to_A.add_id(tex_height_A)
	
	var uniform_height_from_B := RDUniform.new()
	uniform_height_from_B.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform_height_from_B.binding = 0
	uniform_height_from_B.add_id(tex_height_B)
	var uniform_height_to_B := RDUniform.new()
	uniform_height_to_B.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform_height_to_B.binding = 2
	uniform_height_to_B.add_id(tex_height_B)
	
	var uniform_flux_from_A := RDUniform.new()
	uniform_flux_from_A.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform_flux_from_A.binding = 1
	uniform_flux_from_A.add_id(tex_flux_A)
	var uniform_flux_to_A := RDUniform.new()
	uniform_flux_to_A.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform_flux_to_A.binding = 3
	uniform_flux_to_A.add_id(tex_flux_A)
	
	var uniform_flux_from_B := RDUniform.new()
	uniform_flux_from_B.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform_flux_from_B.binding = 1
	uniform_flux_from_B.add_id(tex_flux_B)
	var uniform_flux_to_B := RDUniform.new()
	uniform_flux_to_B.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform_flux_to_B.binding = 3
	uniform_flux_to_B.add_id(tex_flux_B)
	
	
	var set_A2B = [uniform_height_from_A, uniform_height_to_B,
				   uniform_flux_from_A, uniform_flux_to_B]
	var set_B2A = [uniform_height_from_B, uniform_height_to_A,
				   uniform_flux_from_B, uniform_flux_to_A]
	
	uniform_set_height_A2B = rd.uniform_set_create(set_A2B, height_shader_pipeline[0], 0)
	uniform_set_height_B2A = rd.uniform_set_create(set_B2A, height_shader_pipeline[0], 0)
	uniform_set_flux_A2B = rd.uniform_set_create(set_A2B, flux_shader_pipeline[0], 0)
	uniform_set_flux_B2A = rd.uniform_set_create(set_B2A, flux_shader_pipeline[0], 0)
	

# func _exit_tree() -> void:
# 	free()
	
func free() -> void:
	pass

func _process(_delta: float) -> void:
	#place_fluid()
	if (not Engine.is_editor_hint() || run_in_editor):
		if mouse_pos != null:
			var u = (mouse_pos.x + 256) / 512 * 100;
			var v = (mouse_pos.z + 256) / 512 * 100;
			print("Left", mouse_pos, u, v)
			image_height.set_pixel(u, v, Color(1.0, 0.0, 0.0, 1.0))
		RenderingServer.call_on_render_thread(compute.bind(accel_factor if accelerate else 1))

#func place_fluid() -> void:

func compute(num_iter) -> void:
	rd.texture_update(tex_height_A, 0, image_height.get_data())
	rd.texture_update(tex_flux_A, 0, image_flux.get_data())
	for n in num_iter:
		# Process:
		# list begin: Start compute list to start recording our compute commands
		# bind pipeline: Bind the pipeline, this tells the GPU what shader to use
		# bind uniform: Binds the uniform set with the data we want to give our shader
		# list end: Tell the GPU we are done with this compute task
		# submit and sync: start and await computation
		
		var compute_list := rd.compute_list_begin()
		rd.compute_list_bind_compute_pipeline(compute_list, flux_shader_pipeline[1])
		rd.compute_list_bind_uniform_set(compute_list, uniform_set_flux_A2B if reading_A else uniform_set_flux_B2A, 0)
		rd.compute_list_dispatch(compute_list, texture_size.x, texture_size.y, 1)
		rd.compute_list_end()
		#rd.submit()
		
		rd.barrier(RenderingDevice.BARRIER_MASK_COMPUTE)
		
		compute_list = rd.compute_list_begin()
		rd.compute_list_bind_compute_pipeline(compute_list, height_shader_pipeline[1])
		rd.compute_list_bind_uniform_set(compute_list, uniform_set_height_A2B if reading_A else uniform_set_height_B2A, 0)
		rd.compute_list_dispatch(compute_list, texture_size.x, texture_size.y, 1)
		rd.compute_list_end()
		
		#rd.sync()  # Finish flux calc first
		#rd.submit()
		#rd.sync()
		
		reading_A = !reading_A
	
	# Now we can grab our data from the texture
	# Confusing: At this point reading_A has already been flipped
	data_height_A = rd.texture_get_data(tex_height_A if reading_A else tex_height_B, 0)
	data_flux_A = rd.texture_get_data(tex_flux_A if reading_A else tex_flux_B, 0)
	
	image_height = Image.create_from_data(texture_size.x, texture_size.y, false, image_format, data_height_A)
	image_flux = Image.create_from_data(texture_size.x, texture_size.y, false, image_format, data_flux_A)
	
	reading_A = true



func _on_static_body_3d_input_event(camera, event, position, normal, shape_idx):
	if event is InputEventMouseButton and (
		event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT):
		mouse_pos = position if event.pressed else null
		fill_water = event.button_index == MOUSE_BUTTON_LEFT
	else:
		mouse_pos = position if mouse_pos != null else null
