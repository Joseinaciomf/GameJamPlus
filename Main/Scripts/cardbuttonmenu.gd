extends HBoxContainer

@export var hover_scale := Vector2(1.15, 1.15)
@export var duration := 0.12

var _tweens := {}

func _ready() -> void:
	for card in get_children():
		if card is TextureButton:
			_setup_card(card)

func _setup_card(card: TextureButton) -> void:
	card.pivot_offset = card.size / 2.0
	card.resized.connect(func(): card.pivot_offset = card.size / 2.0)
	card.mouse_entered.connect(_on_hover.bind(card, true))
	card.mouse_exited.connect(_on_hover.bind(card, false))
	card.focus_entered.connect(_on_hover.bind(card, true))
	card.focus_exited.connect(_on_hover.bind(card, false))
	card.button_down.connect(_on_press.bind(card))
	card.button_up.connect(_on_release.bind(card))
	card.pressed.connect(_on_click.bind(card))

func _on_hover(card: TextureButton, hovered: bool) -> void:
	card.z_index = 1 if hovered else 0
	if _tweens.has(card) and _tweens[card]:
		_tweens[card].kill()
	var tween := create_tween()
	tween.tween_property(card, "scale", hover_scale if hovered else Vector2.ONE, duration) \
		.set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)
	_tweens[card] = tween

@export var press_scale := Vector2(0.92, 0.92)

func _tween_card(card: TextureButton, target: Vector2, time: float, trans := Tween.TRANS_BACK) -> void:
	if _tweens.has(card) and _tweens[card]:
		_tweens[card].kill()
	var tween := create_tween()
	tween.tween_property(card, "scale", target, time) \
		.set_trans(trans) \
		.set_ease(Tween.EASE_OUT)
	_tweens[card] = tween

func _on_press(card: TextureButton) -> void:
	_tween_card(card, press_scale, 0.06, Tween.TRANS_QUAD)

func _on_release(card: TextureButton) -> void:
	var target := hover_scale if card.is_hovered() else Vector2.ONE
	_tween_card(card, target, 0.2)

func _on_click(card: TextureButton) -> void:
	# flash de brilho
	var flash := create_tween()
	card.modulate = Color(1.6, 1.6, 1.6)
	flash.tween_property(card, "modulate", Color.WHITE, 0.25)
	# aqui você coloca o que a carta faz de verdade (trocar de cena, etc.)
	print("clicou em ", card.name)
