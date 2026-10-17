extends Control

signal card_used(card: Control)

@onready var carta: Sprite2D = $Carta

var is_hovered: bool = false
var is_used: bool = false
var _hover_tween: Tween

func _ready() -> void:
	custom_minimum_size = Vector2(128, 192)
	size = Vector2(128, 192)
	mouse_filter = Control.MOUSE_FILTER_STOP
	carta.position = size / 2.0

func _gui_input(event: InputEvent) -> void:
	if is_used:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		is_used = true
		accept_event()
		card_used.emit(self)

func _on_mouse_entered() -> void:
	if is_used:
		return
	is_hovered = true
	z_index = 100
	_animate_hover(Vector2(1.12, 1.12))

func _on_mouse_exited() -> void:
	is_hovered = false
	if is_used:
		return
	z_index = 0
	_animate_hover(Vector2.ONE)

func _animate_hover(target_scale: Vector2) -> void:
	if is_instance_valid(_hover_tween) and _hover_tween.is_running():
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.tween_property(carta, "scale", target_scale, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
