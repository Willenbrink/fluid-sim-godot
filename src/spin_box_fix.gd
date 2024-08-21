# See https://old.reddit.com/r/godot/comments/jcqj6f/how_to_release_focus_out_of_a_spin_box_after/
extends SpinBox
@onready var line = get_line_edit()

func _ready():         
	connect("value_changed", _on_SpinBox_value_changed)

func _on_text_entered(new_text):        
	line.release_focus()

func _on_SpinBox_value_changed(value):        
	line.release_focus()
