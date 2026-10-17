extends Node2D

@onready var Mao: Node2D = $Mao

const CARD_SCENE: PackedScene = preload("res://Main/Scenes/carta.tscn")
const ATTACK_TEXTURE: Texture2D = preload("res://Assets/Carta de Ataque.png")
const DEFENSE_TEXTURE: Texture2D = preload("res://Assets/Carta de Defesa.png")
const COUNTER_TEXTURE: Texture2D = preload("res://Assets/Carta de Counter.png")

const HAND_SPREAD: float = 290.0
const FAN_HEIGHT: float = 24.0
const MAX_ROTATION: float = 0.20

var deck: Array[CardData] = []


func _ready() -> void:
	_build_deck()
	_deal_starting_hand()
	arrange_hand()


func _build_deck() -> void:
	deck.clear()

	for i in range(10):
		deck.append(_make_card_data("Carta de Ataque", "Uma carta do tipo ataque.", "Ataque", ATTACK_TEXTURE))
	for i in range(7):
		deck.append(_make_card_data("Carta de Defesa", "Uma carta do tipo defesa.", "Defesa", DEFENSE_TEXTURE))
	for i in range(3):
		deck.append(_make_card_data("Carta de Counter", "Uma carta do tipo counter.", "Counter", COUNTER_TEXTURE))

	deck.shuffle()


func _make_card_data(card_name: String, card_description: String, card_type: String, texture: Texture2D) -> CardData:
	var data: CardData = CardData.new()
	data.card_name = card_name
	data.card_description = card_description
	data.card_type = card_type
	data.card_texture = texture
	return data


func _deal_starting_hand() -> void:
	var starting_hand: Array[CardData] = []
	_take_cards_of_type("Ataque", 3, starting_hand)
	_take_cards_of_type("Defesa", 1, starting_hand)
	_take_cards_of_type("Counter", 1, starting_hand)
	starting_hand.shuffle()

	for data in starting_hand:
		_add_card_to_hand(data)


func _take_cards_of_type(card_type: String, amount: int, destination: Array[CardData]) -> void:
	for i in range(amount):
		for index in range(deck.size()):
			if deck[index].card_type == card_type:
				destination.append(deck.pop_at(index))
				break


func _add_card_to_hand(data: CardData) -> void:
	var card: Control = CARD_SCENE.instantiate()
	card.card_data = data
	Mao.add_child(card)
	card.card_used.connect(_on_card_used)


func draw_card(amount: int = 1, _card_data = null) -> void:
	for i in range(mini(amount, deck.size())):
		var data: CardData = deck.pop_back()
		_add_card_to_hand(data)
	arrange_hand()


func _on_card_used(card: Control) -> void:
	if not is_instance_valid(card):
		return

	card.set_process_input(false)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(card, "position:y", card.position.y - 90.0, 0.18)
	tween.tween_property(card, "modulate:a", 0.0, 0.18)
	await tween.finished
	card.queue_free()
	await get_tree().process_frame
	arrange_hand()


func arrange_hand() -> void:
	var cards: Array[Node] = Mao.get_children()
	var count: int = cards.size()
	if count == 0:
		return

	for index in range(count):
		var card: Control = cards[index] as Control
		if card == null:
			continue

		var ratio: float = 0.5 if count == 1 else float(index) / float(count - 1)
		var target_x: float = ratio * HAND_SPREAD
		var target_y: float = -sin(ratio * PI) * FAN_HEIGHT
		var target_rotation: float = 0.0 if count == 1 else lerpf(-MAX_ROTATION, MAX_ROTATION, ratio)

		var tween: Tween = create_tween()
		tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(card, "position", Vector2(target_x, target_y), 0.22)
		tween.parallel().tween_property(card, "rotation", target_rotation, 0.22)
		card.z_index = index
