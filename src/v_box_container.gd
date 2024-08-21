extends VBoxContainer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
func _input(event: InputEvent):
	if event is InputEventMouseButton and event.is_pressed() and event.button_index == 1:
		var evLocal = make_input_local(event)
		if !Rect2(Vector2(0,0), size).has_point(evLocal.position):
			print("Release!")
			release_focus()
