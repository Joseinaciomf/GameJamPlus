extends Node2D

@onready var Mao: Node2D = $Mao

const CARD_SCENE: PackedScene = preload("res://Main/Scenes/carta.tscn")
const HAND_SPREAD: float = 290.0
const FAN_HEIGHT: float = 24.0
const MAX_ROTATION: float = 0.20

func _ready() -> void:
	draw_card(5, null)
	arrange_hand()

func draw_card(amount: int, _card_data = null) -> void:
	for _i in range(amount):
		var card: Control = CARD_SCENE.instantiate()
		card.position = Vector2(HAND_SPREAD / 2.0, 70.0)
		Mao.add_child(card)
		card.card_used.connect(_on_card_used)

func _on_card_used(card: Control) -> void:
	if not is_instance_valid(card):
		return
	card.set_process_input(false)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(card, "position:y", card.position.y - 90.0, 0.18)
	tween.tween_property(card, "modulate:a", 0.0, 0.18)
	await tween.finished
	card.queue_free()
	await get_tree().process_frame
	arrange_hand()

func arrange_hand() -> void:
	var cards := Mao.get_children()
	var count := cards.size()
	if count == 0:
		return

	for index in range(count):
		var card := cards[index] as Control
		var ratio := 0.5 if count == 1 else float(index) / float(count - 1)
		var target_x := ratio * HAND_SPREAD
		# The middle cards sit lower; outer cards rise slightly to form a fan.
		var target_y := -sin(ratio * PI) * FAN_HEIGHT
		var target_rotation: float = 0.0 if count == 1 else lerpf(-MAX_ROTATION, MAX_ROTATION, ratio)
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(card, "position", Vector2(target_x, target_y), 0.22)
		tween.parallel().tween_property(card, "rotation", target_rotation, 0.22)
		card.z_index = index
