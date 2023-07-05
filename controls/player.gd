extends RigidBody3D

@export var trans_accel = 5.0
@export var rot_accel = 0.1

func _physics_process(delta):
	
	var trans_mag = trans_accel * 100 * delta
	var rot_mag = rot_accel * 100 * delta
	
	if Input.is_action_pressed("move_right"):
		apply_central_force(global_transform.basis.x * trans_mag)
	if Input.is_action_pressed("move_left"):
		apply_central_force(global_transform.basis.x * -trans_mag)
	if Input.is_action_pressed("move_backward"):
		apply_central_force(global_transform.basis.z * trans_mag)
	if Input.is_action_pressed("move_forward"):
		apply_central_force(global_transform.basis.z * -trans_mag)
	if Input.is_action_pressed("move_up"):
		apply_central_force(global_transform.basis.y * trans_mag)
	if Input.is_action_pressed("move_down"):
		apply_central_force(global_transform.basis.y * -trans_mag)
		
	if Input.is_action_pressed("rotate_right"):
		apply_torque(global_transform.basis.y * -rot_mag)
	if Input.is_action_pressed("rotate_left"):
		apply_torque(global_transform.basis.y * rot_mag)
