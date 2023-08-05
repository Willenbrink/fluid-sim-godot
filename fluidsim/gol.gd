@tool
extends TextureRect

@export var run_in_editor = false;
@export var step : bool :
	get: return false
	set(_value):
		step = false
		compute(accel_factor)
		show_texture()
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

var shader_flux: RID
var shader_height: RID

var pipeline_flux: RID
var pipeline_height: RID

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

var uniform_set_height_A2B: RID
var uniform_set_height_B2A: RID
var uniform_set_flux_A2B: RID
var uniform_set_flux_B2A: RID

@export var image_size: Vector2i
@export var use_noise = false
@export var noise: Texture2D
# Keep those in sync!
var image_format := Image.FORMAT_RGBAF
var data_format := RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT

func _ready() -> void:
	# We will be using our own RenderingDevice to handle the compute commands
	rd = RenderingServer.create_local_rendering_device()
	if not rd:
		set_process(false)
		print("Compute shaders are not available")
		return
	init()
	
func init() -> void:
	# Create shader and pipeline
	var height_spirv := height_shader_file.get_spirv()
	shader_height = rd.shader_create_from_spirv(height_spirv)
	pipeline_height = rd.compute_pipeline_create(shader_height)
	
	var flux_spirv := flux_shader_file.get_spirv()
	shader_flux = rd.shader_create_from_spirv(flux_spirv)
	pipeline_flux = rd.compute_pipeline_create(shader_flux)
	
	# Data for compute shaders has to come as an array of bytes
	var image_height := Image.create(image_size.x, image_size.y, false, image_format)
	if use_noise:
		var og_image := noise.get_image()
		og_image.decompress()
		for i in image_size.x:
			for j in image_size.y:
				image_height.set_pixel(i, j, og_image.get_pixel(i, j))
	else:
		for i in image_size.x:
			for j in image_size.y:
				image_height.set_pixel(i, j, Color.BLACK)
		for i in image_size.x:
			for j in image_size.y:
				var upper = image_size.x / 2 * 1.1
				var lower = image_size.x / 2 * 0.9
				upper = 55
				lower = 15
				if i > lower && i < upper && j > lower && j < upper:
				#if i > 220 && i < 260 && j > 220 && j < 260:
					image_height.set_pixel(i, j, Color.RED)
					image_height.set_pixel(i, j, Color.RED)
		#image_height.set_pixel(50, 50, Color.RED)
	
	reading_A = true
	
	data_height_A = image_height.get_data()
	data_height_B = PackedByteArray()
	data_height_B.resize(data_height_A.size())
	
	var image_flux := Image.create(image_size.x, image_size.y, false, image_format)
	data_flux_A = image_flux.get_data()
	data_flux_B = PackedByteArray()
	data_flux_B.resize(data_flux_A.size())	

	var tex_map_format := RDTextureFormat.new()
	tex_map_format.width = image_size.x
	tex_map_format.height = image_size.y
	tex_map_format.depth = 4
	tex_map_format.format = data_format
	tex_map_format.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
		| RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
		| RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	)
	var tex_view_height := RDTextureView.new()
	tex_height_A = rd.texture_create(tex_map_format, tex_view_height, [data_height_A])
	tex_height_B = rd.texture_create(tex_map_format, tex_view_height, [data_height_B])
	
	var tex_view_flux := RDTextureView.new()
	tex_flux_A = rd.texture_create(tex_map_format, tex_view_flux, [data_flux_A])
	tex_flux_B = rd.texture_create(tex_map_format, tex_view_flux, [data_flux_B])
	
	
	var uniform_height_A := RDUniform.new()
	uniform_height_A.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform_height_A.binding = 0
	uniform_height_A.add_id(tex_height_A)
	var uniform_height_B := RDUniform.new()
	uniform_height_B.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform_height_B.binding = 2
	uniform_height_B.add_id(tex_height_B)
	
	var uniform_flux_A := RDUniform.new()
	uniform_flux_A.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform_flux_A.binding = 1
	uniform_flux_A.add_id(tex_flux_A)
	var uniform_flux_B := RDUniform.new()
	uniform_flux_B.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform_flux_B.binding = 3
	uniform_flux_B.add_id(tex_flux_B)
	
	
	var set_A2B = [uniform_height_A, uniform_height_B, uniform_flux_A, uniform_flux_B]
	var set_B2A = [uniform_height_B, uniform_height_A, uniform_flux_B, uniform_flux_A]
	
	uniform_set_height_A2B = rd.uniform_set_create(set_A2B, shader_height, 0)
	uniform_set_height_B2A = rd.uniform_set_create(set_B2A, shader_height, 0)
	uniform_set_flux_A2B = rd.uniform_set_create(set_A2B, shader_flux, 0)
	uniform_set_flux_B2A = rd.uniform_set_create(set_B2A, shader_flux, 0)
	
	show_texture();

# func _exit_tree() -> void:
# 	free()
	
func free() -> void:
	pass

func _process(_delta: float) -> void:
	#place_fluid()
	if (not Engine.is_editor_hint() || run_in_editor):
		compute(accel_factor if accelerate else 1)
		show_texture();

#func place_fluid() -> void:

func compute(num_iter) -> void:
	for n in num_iter:
		rd.texture_update(tex_height_A, 0, data_height_A)
		rd.texture_update(tex_flux_A, 0, data_flux_A)
		# Process:
		# list begin: Start compute list to start recording our compute commands
		# bind pipeline: Bind the pipeline, this tells the GPU what shader to use
		# bind uniform: Binds the uniform set with the data we want to give our shader
		# list end: Tell the GPU we are done with this compute task
		# submit and sync: start and await computation
		
		var compute_list := rd.compute_list_begin()
		rd.compute_list_bind_compute_pipeline(compute_list, pipeline_flux)
		rd.compute_list_bind_uniform_set(compute_list, uniform_set_flux_A2B if reading_A else uniform_set_flux_B2A, 0)
		rd.compute_list_dispatch(compute_list, image_size.x, image_size.y, 1)
		rd.compute_list_end()
		rd.submit()
		rd.sync()  # Finish flux calc first
		
		compute_list = rd.compute_list_begin()
		rd.compute_list_bind_compute_pipeline(compute_list, pipeline_height)
		rd.compute_list_bind_uniform_set(compute_list, uniform_set_height_A2B if reading_A else uniform_set_height_B2A, 0)
		rd.compute_list_dispatch(compute_list, image_size.x, image_size.y, 1)
		rd.compute_list_end()
		rd.submit()
		rd.sync()
		data_height_A = rd.texture_get_data(tex_height_B if reading_A else tex_height_A, 0)
		data_flux_A = rd.texture_get_data(tex_flux_B if reading_A else tex_flux_A, 0)
		
		#reading_A = !reading_A
	
	# Now we can grab our data from the texture
	reading_A = true

func show_texture() -> void:
	if show_flux:
		var image_flux := Image.create_from_data(image_size.x, image_size.y, false, image_format, data_flux_A)
		texture = ImageTexture.create_from_image(image_flux)
	else:
		var image_height := Image.create_from_data(image_size.x, image_size.y, false, image_format, data_height_A)
		texture = ImageTexture.create_from_image(image_height)
