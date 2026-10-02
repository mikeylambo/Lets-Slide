class_name LobbyScreen
extends Control

## Online play: host or join a lobby, pick a course and round length, race.
## Direct IP / LAN today; the session is transport-agnostic for Steam later.

var net: NetSession
var _name: LineEdit
var _address: LineEdit
var _status: Label
var _players: VBoxContainer
var _host_box: VBoxContainer
var _connect_box: HBoxContainer
var _course: OptionButton
var _length: OptionButton
var _courses: Array[CourseData] = []
const LENGTHS = [[120.0, "2 MIN"], [180.0, "3 MIN"], [300.0, "5 MIN"], [600.0, "10 MIN"]]

func _ready() -> void:
	net = Main.instance.net
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UiKit.backdrop())
	var margin = MarginContainer.new(); margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]: margin.add_theme_constant_override("margin_" + side, 90)
	margin.add_theme_constant_override("margin_top", 50); margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)
	var col = VBoxContainer.new(); col.add_theme_constant_override("separation", 10); margin.add_child(col)
	col.add_child(UiKit.title("ONLINE", "time attack · everyone rides at once · riders pass through each other"))

	_connect_box = HBoxContainer.new(); _connect_box.add_theme_constant_override("separation", 10); col.add_child(_connect_box)
	_name = LineEdit.new(); _name.text = str(Game.profile.get("name", "SLIDER")); _name.max_length = 16
	_name.custom_minimum_size = Vector2(220, 44); _name.placeholder_text = "Your name"
	_connect_box.add_child(_name)
	var host = UiKit.button("HOST", true); host.custom_minimum_size = Vector2(160, 44)
	host.pressed.connect(func(): _remember_name(); net.host(NetSession.DEFAULT_PORT, _name.text))
	_connect_box.add_child(host)
	_address = LineEdit.new(); _address.placeholder_text = "Host address (e.g. 192.168.1.20)"
	_address.custom_minimum_size = Vector2(340, 44)
	_connect_box.add_child(_address)
	var join = UiKit.button("JOIN"); join.custom_minimum_size = Vector2(140, 44)
	join.pressed.connect(func():
		_remember_name()
		var parts = _address.text.strip_edges().split(":")
		var port = int(parts[1]) if parts.size() > 1 else NetSession.DEFAULT_PORT
		net.join(parts[0] if parts[0] != "" else "127.0.0.1", port, _name.text))
	_connect_box.add_child(join)

	_status = UiKit.label("Host to invite friends on your network (port %d), or join their address." % NetSession.DEFAULT_PORT, UiKit.BODY, UiKit.TEXT_DIM)
	col.add_child(_status)
	col.add_child(UiKit.label("RIDERS", UiKit.H3, UiKit.LINE))
	_players = VBoxContainer.new(); col.add_child(_players)

	_host_box = VBoxContainer.new(); _host_box.add_theme_constant_override("separation", 8); col.add_child(_host_box)
	_host_box.add_child(UiKit.label("ROUND", UiKit.H3, UiKit.LINE))
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 10); _host_box.add_child(row)
	_course = OptionButton.new(); _course.custom_minimum_size = Vector2(420, 44); row.add_child(_course)
	for c in Courses.all():
		if Game.course_unlocked(c): _courses.append(c)
	for c in CustomCourses.all():
		if CourseCodec.is_verified(c): _courses.append(c)
	for c in _courses: _course.add_item(("★ " if c.id.begins_with("c_") else "") + c.title)
	_length = OptionButton.new(); _length.custom_minimum_size = Vector2(160, 44); row.add_child(_length)
	for l in LENGTHS: _length.add_item(l[1])
	_length.select(1)
	var start = UiKit.button("START ROUND", true); start.custom_minimum_size = Vector2(220, 44)
	start.pressed.connect(func(): net.start_round(_courses[_course.selected], LENGTHS[_length.selected][0]))
	row.add_child(start)

	col.add_child(UiKit.spacer(6))
	var back = UiKit.button("LEAVE"); back.pressed.connect(func(): net.leave(); Main.instance.show_menu()); col.add_child(back)
	net.lobby_changed.connect(_refresh)
	net.status.connect(func(t): _status.text = t)
	_refresh()
	host.grab_focus()

func _remember_name() -> void:
	Game.profile["name"] = NetSession._clean_name(_name.text)
	Game.save_profile()

func _refresh() -> void:
	if not is_instance_valid(_players): return
	for c in _players.get_children(): c.queue_free()
	var connected = net.online()
	_connect_box.visible = not connected
	_host_box.visible = connected and net.is_host()
	for id in net.players.keys():
		var p: Dictionary = net.players[id]
		var dot = NetSession.COLORS[int(p.get("color", 0)) % NetSession.COLORS.size()]
		_players.add_child(UiKit.row(str(p["name"]) + ("  (host)" if int(id) == 1 else ""), "READY", dot))
	if connected and not net.is_host():
		_status.text = "Connected. The host starts the round."
