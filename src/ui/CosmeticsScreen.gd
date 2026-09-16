class_name CosmeticsScreen
extends Control

const ITEMS = [
	["core", "CORE", "Standard rider"],
	["prism", "PRISM", "5 medals"],
	["afterimage", "AFTERIMAGE", "10 medals"],
	["voidglass", "VOIDGLASS", "15 medals"],
	["invert_core", "INVERT CORE", "20 medals"],
	["author_white", "AUTHOR WHITE", "25 medals"],
]

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(UiKit.backdrop())
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 90)
	margin.add_theme_constant_override("margin_top", 60)
	add_child(margin)
	var col = VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)
	col.add_child(UiKit.title("RIDER", "cosmetics only · physics never changes"))

	var unlocked: Array = Game.profile["cosmetics"].get("unlocked", ["core"])
	var equipped = str(Game.profile["cosmetics"].get("equipped", "core"))
	var first: Button = null
	for item in ITEMS:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 20)
		col.add_child(row)
		var id = str(item[0])
		var available = id in unlocked
		var swatch = ColorRect.new()
		swatch.custom_minimum_size = Vector2(54, 40)
		swatch.color = Game.cosmetic_palette(id)["board"]
		row.add_child(swatch)
		var txt = VBoxContainer.new()
		txt.custom_minimum_size = Vector2(340, 0)
		row.add_child(txt)
		txt.add_child(UiKit.label(str(item[1]), UiKit.H3, UiKit.TEXT if available else UiKit.TEXT_DIM))
		txt.add_child(UiKit.label("EQUIPPED" if id == equipped else str(item[2]), UiKit.BODY, UiKit.GOOD if id == equipped else UiKit.TEXT_DIM))
		var button = UiKit.button("EQUIP" if available else "LOCKED", available and id != equipped)
		button.disabled = not available or id == equipped
		button.pressed.connect(_equip.bind(id))
		row.add_child(button)
		if first == null and not button.disabled:
			first = button

	var back = UiKit.button("BACK")
	back.pressed.connect(func(): Main.instance.show_menu())
	col.add_child(back)
	if first != null:
		first.grab_focus()
	else:
		back.grab_focus()

func _equip(id: String) -> void:
	Game.equip_cosmetic(id)
	Main.instance.show_cosmetics()
