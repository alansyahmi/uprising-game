class_name MainMenu
extends Control

@onready var start_button: Button = $CenterContainer/VBoxContainer/ButtonsVBox/StartButton
@onready var controls_button: Button = $CenterContainer/VBoxContainer/ButtonsVBox/ControlsButton
@onready var quit_button: Button = $CenterContainer/VBoxContainer/ButtonsVBox/QuitButton
@onready var controls_panel: PanelContainer = $ControlsModal

func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	controls_button.pressed.connect(_on_controls_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	controls_panel.visible = false
	
	var close_btn = controls_panel.find_child("CloseButton", true, false) as Button
	if close_btn:
		close_btn.pressed.connect(func(): controls_panel.visible = false)

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://src/levels/test_arena/TestArena.tscn")

func _on_controls_pressed() -> void:
	controls_panel.visible = not controls_panel.visible

func _on_quit_pressed() -> void:
	get_tree().quit()
