class_name PauseMenu
extends Control

signal resume_requested()
signal retry_requested()
signal exit_requested()

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(UiKit.backdrop(0.78))

	var col = VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.set_anchors_preset(Control.PRESET_CENTER)
	col.position = Vector2(-140, -160)
	col.custom_minimum_size = Vector2(280, 0)
	add_child(col)

	col.add_child(UiKit.label("PAUSED", UiKit.H2, UiKit.LINE))
	col.add_child(UiKit.rule())
	col.add_child(UiKit.spacer(10))

	var resume = UiKit.button("RESUME", true)
	resume.pressed.connect(func(): resume_requested.emit())
	col.add_child(resume)

	var retry = UiKit.button("RESTART RUN")
	retry.pressed.connect(func(): retry_requested.emit())
	col.add_child(retry)

	var lab = UiKit.button("MOVEMENT LAB")
	lab.pressed.connect(func(): Main.instance.open_lab())
	col.add_child(lab)

	var quit = UiKit.button("QUIT TO MENU")
	quit.pressed.connect(func(): exit_requested.emit())
	col.add_child(quit)

	resume.grab_focus()
