extends CanvasLayer
class_name MenuManager

## ═══════════════════════════════════════════════════════════════════════════════
## MenuManager — Centralized UI Navigation Controller
## ═══════════════════════════════════════════════════════════════════════════════
##
## Manages the stack of UI menus, transitions, and focus handling.
## Ensures only one menu is active at a time and handles back-navigation.
##
## Usage:
##   MenuManager.push_menu("settings")
##   MenuManager.pop_menu()

# ─── Signals ─────────────────────────────────────────────────────────────────
signal menu_opened(menu_name: String)
signal menu_closed(menu_name: String)

# ─── Configuration ───────────────────────────────────────────────────────────
const TRANSITION_DURATION := 0.3

# ─── State ───────────────────────────────────────────────────────────────────
var _menu_stack: Array[Control] = []
var _registered_menus: Dictionary = {}
var _overlay: ColorRect

# ─── Lifecycle ──────────────────────────────────────────────────────────────

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	
	_create_overlay()
	_register_menus()
	
	# Listen for cancel action (ESC)
	set_process_input(true)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _menu_stack.size() > 0:
			pop_menu()
			get_viewport().set_input_as_handled()


# ─── Public API ─────────────────────────────────────────────────────────────

func register_menu(name: String, node: Control) -> void:
	if not node: return
	_registered_menus[name] = node
	node.visible = false
	if node.get_parent() != self:
		node.reparent(self)


func push_menu(name: String, params: Dictionary = {}) -> void:
	if not _registered_menus.has(name):
		push_error("[MenuManager] Menu not found: %s" % name)
		return
	
	var menu = _registered_menus[name]
	
	# If menu already in stack, pop until we reach it
	if menu in _menu_stack:
		while _menu_stack.back() != menu:
			pop_menu()
		return
	
	# Hide previous menu if exists
	if _menu_stack.size() > 0:
		_animate_out(_menu_stack.back())
	
	_menu_stack.append(menu)
	_animate_in(menu)
	
	if menu.has_method("on_open"):
		menu.on_open(params)
	
	# Show overlay if stack was empty
	if _menu_stack.size() == 1:
		_fade_overlay(true)
		get_tree().paused = true
	
	menu_opened.emit(name)


func pop_menu() -> void:
	if _menu_stack.is_empty():
		return
	
	var menu = _menu_stack.pop_back()
	_animate_out(menu)
	
	if menu.has_method("on_close"):
		menu.on_close()
	
	menu_closed.emit(menu.name)
	
	# Show previous menu if exists
	if _menu_stack.size() > 0:
		var prev = _menu_stack.back()
		_animate_in(prev)
		if prev.has_method("on_focus"):
			prev.on_focus()
	else:
		_fade_overlay(false)
		get_tree().paused = false


func clear_menus() -> void:
	while not _menu_stack.is_empty():
		pop_menu()


# ─── Internal: UI Construction ──────────────────────────────────────────────

func _create_overlay() -> void:
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.7)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false
	add_child(_overlay)
	move_child(_overlay, 0)


func _register_menus() -> void:
	# In a real scenario, we might instantiate scenes here
	# For now, we assume children are added manually or via scene
	pass


# ─── Internal: Animation ────────────────────────────────────────────────────

func _animate_in(menu: Control) -> void:
	menu.visible = true
	menu.modulate.a = 0.0
	menu.scale = Vector2(0.95, 0.95)
	menu.pivot_offset = menu.size / 2
	
	var tw = create_tween().set_parallel(true)
	tw.tween_property(menu, "modulate:a", 1.0, TRANSITION_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(menu, "scale", Vector2.ONE, TRANSITION_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	# Focus first button
	var focus_target = _find_first_focusable(menu)
	if focus_target:
		focus_target.grab_focus()


func _animate_out(menu: Control) -> void:
	var tw = create_tween().set_parallel(true)
	tw.tween_property(menu, "modulate:a", 0.0, TRANSITION_DURATION * 0.8)
	tw.tween_property(menu, "scale", Vector2(1.05, 1.05), TRANSITION_DURATION * 0.8)
	tw.tween_callback(func(): menu.visible = false)


func _fade_overlay(show: bool) -> void:
	if show:
		_overlay.visible = true
		var tw = create_tween()
		tw.tween_property(_overlay, "color:a", 0.7, TRANSITION_DURATION)
	else:
		var tw = create_tween()
		tw.tween_property(_overlay, "color:a", 0.0, TRANSITION_DURATION)
		tw.tween_callback(func(): _overlay.visible = false)


func _find_first_focusable(node: Node) -> Control:
	if node is Control and node.focus_mode != Control.FOCUS_NONE:
		return node
	for child in node.get_children():
		var result = _find_first_focusable(child)
		if result: return result
	return null
