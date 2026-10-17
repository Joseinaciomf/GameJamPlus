class_name FxButton
extends TextureButton

@export var hover_scale := Vector2(1.15, 1.15)
@export var press_scale := Vector2(0.92, 0.92)
@export var duration := 0.12

var _tween: Tween

func _ready() -> void:
	pivot_offset = size / 2.0
	resized.connect(func(): pivot_offset = size / 2.0)
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))
	focus_entered.connect(_on_hover.bind(true))
	focus_exited.connect(_on_hover.bind(false))
	button_down.connect(func(): _scale_to(press_scale, 0.06, Tween.TRANS_QUAD))
	button_up.connect(func(): _scale_to(hover_scale if is_hovered() else Vector2.ONE, 0.2))
	pressed.connect(_flash)

func _on_hover(hovered: bool) -> void:
	z_index = 1 if hovered else 0
	_scale_to(hover_scale if hovered else Vector2.ONE, duration)

func _scale_to(target: Vector2, time: float, trans := Tween.TRANS_BACK) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "scale", target, time) \
		.set_trans(trans).set_ease(Tween.EASE_OUT)

func _flash() -> void:
	modulate = Color(1.6, 1.6, 1.6)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.25)
