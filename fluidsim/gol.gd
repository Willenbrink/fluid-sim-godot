@tool
extends TextureRect

@export var run_in_editor = false;
@export var reset : bool :
	get: return false
	set(_value):
		reset = false
		texture = tex_height_init
		tex_flux = tex_flux_init
		var og_image := texture.get_image()
		og_image.convert(image_format)
		read_data_height = og_image.get_data();
		
		var flux_image := tex_flux.get_image()
		flux_image.convert(image_format)
		read_data_flux = flux_image.get_data()
	
@export var tex_height_init: Texture2D:
	get:
		return tex_height_init
	set(value):
		tex_height_init = value;

@export var tex_flux_init: Texture2D:
	get:
		return tex_flux_init
	set(value):
		tex_flux_init = value;
		
@export var tex_flux : Texture2D;

var rd: RenderingDevice
var flux_shader_file: RDShaderFile = preload("res://fluidsim/shader/flux.glsl")
var height_shader_file: RDShaderFile = preload("res://fluidsim/shader/pipes.glsl")

var shader_flux: RID
var shader_height: RID

var texture_read_height: RID
var texture_write_height: RID
var texture_read_flux: RID
var texture_write_flux: RID

var uniform_set_height: RID
var uniform_set_flux: RID

var pipeline_flux: RID
var pipeline_height: RID

var read_data_height: PackedByteArray
var write_data_height: PackedByteArray
var read_data_flux: PackedByteArray
var write_data_flux: PackedByteArray

var image_size: Vector2i
var image_format := Image.FORMAT_RGBA8


func _ready() -> void:
	init()
	
func init() -> void:
	# We will be using our own RenderingDevice to handle the compute commands
	rd = RenderingServer.create_local_rendering_device()
	if not rd:
		set_process(false)
		print("Compute shaders are not available")
		return

	# Create shader and pipeline
	var height_spirv := height_shader_file.get_spirv()
	shader_height = rd.shader_create_from_spirv(height_spirv)
	pipeline_height = rd.compute_pipeline_create(shader_height)
	
	var flux_spirv := flux_shader_file.get_spirv()
	shader_flux = rd.shader_create_from_spirv(flux_spirv)
	pipeline_flux = rd.compute_pipeline_create(shader_flux)
	
	
	var og_image := texture.get_image()
	og_image.convert(image_format)
	# Data for compute shaders has to come as an array of bytes
	# Initialize read data
	read_data_height = og_image.get_data()
	
	var flux_image := tex_flux.get_image()
	flux_image.convert(image_format)
	read_data_flux = flux_image.get_data()
	
	image_size = og_image.get_size()
	assert(image_size == flux_image.get_size())
	

	var tex_read_format := RDTextureFormat.new()
	tex_read_format.width = image_size.x
	tex_read_format.height = image_size.y
	tex_read_format.depth = 4
	tex_read_format.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	tex_read_format.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
		| RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
	)
	var tex_view_height := RDTextureView.new()
	texture_read_height = rd.texture_create(tex_read_format, tex_view_height, [read_data_height])
	
	var tex_view_flux := RDTextureView.new()
	texture_read_flux = rd.texture_create(tex_read_format, tex_view_flux, [read_data_flux])
	

	# Create uniform set using the read texture
	var read_uniform_height := RDUniform.new()
	read_uniform_height.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	read_uniform_height.binding = 0
	read_uniform_height.add_id(texture_read_height)
	
	var read_uniform_flux := RDUniform.new()
	read_uniform_flux.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	read_uniform_flux.binding = 1
	read_uniform_flux.add_id(texture_read_flux)
	

	# Initialize write data
	write_data_height = PackedByteArray()
	write_data_height.resize(read_data_height.size())
	
	write_data_flux = PackedByteArray()
	write_data_flux.resize(read_data_flux.size())
	

	var tex_write_format := RDTextureFormat.new()
	tex_write_format.width = image_size.x
	tex_write_format.height = image_size.y
	tex_write_format.depth = 4
	tex_write_format.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	tex_write_format.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
		| RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
		| RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	)
	texture_write_height = rd.texture_create(tex_write_format, tex_view_height, [write_data_height])
	texture_write_flux = rd.texture_create(tex_write_format, tex_view_flux, [write_data_flux])

	# Create uniform set using the write texture
	var write_uniform_height := RDUniform.new()
	write_uniform_height.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	write_uniform_height.binding = 2
	write_uniform_height.add_id(texture_write_height)
	
	var write_uniform_flux := RDUniform.new()
	write_uniform_flux.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	write_uniform_flux.binding = 3
	write_uniform_flux.add_id(texture_write_flux)

	uniform_set_height = rd.uniform_set_create(
		[read_uniform_height, write_uniform_height, read_uniform_flux, write_uniform_flux],
		shader_height, 0)
	uniform_set_flux = rd.uniform_set_create(
		[read_uniform_height, write_uniform_height, read_uniform_flux, write_uniform_flux],
		shader_flux, 0)

func _process(_delta: float) -> void:
	if (not Engine.is_editor_hint() || run_in_editor):
		compute()


func compute() -> void:
	rd.texture_update(texture_read_height, 0, read_data_height)
	rd.texture_update(texture_read_flux, 0, read_data_flux)
	# Start compute list to start recording our compute commands
	var compute_list := rd.compute_list_begin()
	# Bind the pipeline, this tells the GPU what shader to use
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline_flux)
	# Binds the uniform set with the data we want to give our shader
	rd.compute_list_bind_uniform_set(compute_list, uniform_set_flux, 0)
	rd.compute_list_dispatch(compute_list, image_size.x, image_size.y, 1)
	rd.compute_list_end()  # Tell the GPU we are done with this compute task
	rd.submit()  # Force the GPU to start our commands
	rd.sync()  # Force the CPU to wait for the GPU to finish with the recorded commands
	
	compute_list = rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline_height)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set_height, 0)
	rd.compute_list_dispatch(compute_list, image_size.x, image_size.y, 1)
	rd.compute_list_end()
	rd.submit()
	rd.sync()
	

	# Now we can grab our data from the texture
	read_data_height = rd.texture_get_data(texture_write_height, 0)
	read_data_flux = rd.texture_get_data(texture_write_flux, 0)
	var image := Image.create_from_data(image_size.x, image_size.y, false, image_format, read_data_height)
	texture = ImageTexture.create_from_image(image)
