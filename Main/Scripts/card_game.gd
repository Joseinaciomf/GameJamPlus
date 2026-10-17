extends Node2D

# --- Nós ---
@onready var Mao: Node2D = $Mao
@onready var MaoInimigo: Node2D = $MaoInimigo

const CARD_SCENE: PackedScene = preload("res://Main/Scenes/carta.tscn")
const ATTACK_TEXTURE: Texture2D = preload("res://Assets/Carta de Ataque.png")
const DEFENSE_TEXTURE: Texture2D = preload("res://Assets/Carta de Defesa.png")
const COUNTER_TEXTURE: Texture2D = preload("res://Assets/Carta de Counter.png")

# Arraste a imagem do "modelo de costas" aqui, no Inspector do nó CardGame.
@export var enemy_back_texture: Texture2D

const HAND_SPREAD: float = 290.0
const FAN_HEIGHT: float = 24.0
const MAX_ROTATION: float = 0.20

# Tempos do fluxo de jogada (segundos)
const ENEMY_PLAY_DELAY: float = 1.3   # jogador joga -> inimigo joga
const DRAW_DELAY: float = 1.3         # inimigo joga -> ambos compram

# Preview da carta (lado direito da tela)
const PREVIEW_SCALE: float = 2.0
const PREVIEW_MARGIN_RIGHT: float = 60.0
const PREVIEW_SLIDE: float = 60.0
const PREVIEW_TIME: float = 0.3

var deck: Array[CardData] = []
var enemy_deck: Array[CardData] = []

# Noite em que esta partida de cartas está acontecendo (lida do Global.gd).
var noite_da_partida: int = 1

var _preview_layer: CanvasLayer
var _preview_card: Control
var _preview_tween: Tween


func _ready() -> void:
	randomize()

	GlobalCard.vida_mudou.connect(_on_vida_mudou)
	GlobalCard.turno_mudou.connect(_on_turno_mudou)
	_on_vida_mudou(GlobalCard.Lado.JOGADOR, GlobalCard.vida_jogador, GlobalCard.VIDA_MAXIMA)
	_on_vida_mudou(GlobalCard.Lado.INIMIGO, GlobalCard.vida_inimigo, GlobalCard.VIDA_MAXIMA)
	_on_turno_mudou(GlobalCard.numero_turno, GlobalCard.turno_atual)

	# Cada partida de cartas sabe em que noite está.
	noite_da_partida = Global.noite
	print("[NOITE] Partida de cartas na noite %d" % noite_da_partida)

	# Camada (por código) onde o preview aparece, fixa na tela.
	_preview_layer = CanvasLayer.new()
	_preview_layer.layer = 10
	add_child(_preview_layer)

	# Jogador
	deck = _build_deck()
	for data in _take_starting_hand(deck):
		_add_card_to_hand(data)
	arrange_hand()

	# Inimigo
	enemy_deck = _build_enemy_deck()
	for data in _take_starting_hand(enemy_deck):
		_add_enemy_card_to_hand(data)
	arrange_enemy_hand()


# ---------------- DECKS ----------------

func _build_deck() -> Array[CardData]:
	var new_deck: Array[CardData] = []

	for i in range(10):
		new_deck.append(_make_card_data("Carta de Ataque", "Uma carta do tipo ataque.", "Ataque", ATTACK_TEXTURE))
	for i in range(7):
		new_deck.append(_make_card_data("Carta de Defesa", "Uma carta do tipo defesa.", "Defesa", DEFENSE_TEXTURE))
	for i in range(3):
		new_deck.append(_make_card_data("Carta de Counter", "Uma carta do tipo counter.", "Counter", COUNTER_TEXTURE))

	new_deck.shuffle()
	return new_deck


# Ponto de entrada para o inimigo mudar conforme a noite (noite_da_partida).
# Por enquanto é igual ao deck do jogador.
func _build_enemy_deck() -> Array[CardData]:
	return _build_deck()


func _make_card_data(card_name: String, card_description: String, card_type: String, texture: Texture2D) -> CardData:
	var data: CardData = CardData.new()
	data.card_name = card_name
	data.card_description = card_description
	data.card_type = card_type
	data.card_texture = texture
	return data


func _take_starting_hand(source_deck: Array[CardData]) -> Array[CardData]:
	var starting_hand: Array[CardData] = []
	_take_cards_of_type(source_deck, "Ataque", 3, starting_hand)
	_take_cards_of_type(source_deck, "Defesa", 1, starting_hand)
	_take_cards_of_type(source_deck, "Counter", 1, starting_hand)
	starting_hand.shuffle()
	return starting_hand


func _take_cards_of_type(source_deck: Array[CardData], card_type: String, amount: int, destination: Array[CardData]) -> void:
	for i in range(amount):
		for index in range(source_deck.size()):
			if source_deck[index].card_type == card_type:
				destination.append(source_deck.pop_at(index))
				break


# Tira uma carta totalmente aleatória do deck (ou null se estiver vazio).
func _pop_random(source_deck: Array[CardData]) -> CardData:
	if source_deck.is_empty():
		return null
	return source_deck.pop_at(randi() % source_deck.size())


# ---------------- FLUXO DE JOGADA ----------------
# 1) jogador usa uma carta
# 2) +1.3s: inimigo usa uma carta aleatória da mão dele
# 3) +1.3s: ambos compram uma carta aleatória do próprio deck
# Durante isso a vez fica com o inimigo, então o jogador não consegue jogar.

func _on_card_used(card: Control) -> void:
	if not is_instance_valid(card):
		return

	_hide_preview(true)
	card.set_process_input(false)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# TODO (depois): aplicar o efeito da carta do jogador aqui.
	_discard_card(card, -90.0, Mao)  # roda em paralelo, sem esperar
	_run_round()


func _run_round() -> void:
	GlobalCard.proximo_turno()  # vez do inimigo (bloqueia o jogador)

	await get_tree().create_timer(ENEMY_PLAY_DELAY).timeout
	_enemy_play_random_card()

	await get_tree().create_timer(DRAW_DELAY).timeout
	draw_card(1)
	draw_enemy_card(1)

	GlobalCard.proximo_turno()  # volta a vez do jogador


func _enemy_play_random_card() -> void:
	var candidates: Array[Node] = []
	for child in MaoInimigo.get_children():
		if not child.is_queued_for_deletion():
			candidates.append(child)

	if candidates.is_empty():
		print("[INIMIGO] Sem cartas na mão para jogar.")
		return

	var card: Control = candidates.pick_random() as Control
	# TODO (depois): aplicar o efeito da carta do inimigo (card.card_data) aqui.
	if card.card_data != null:
		print("[INIMIGO] Jogou: %s" % card.card_data.card_name)
	_discard_card(card, 90.0, MaoInimigo)


# Anima a carta saindo da mão, remove e reorganiza o leque.
func _discard_card(card: Control, offset_y: float, hand: Node2D) -> void:
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(card, "position:y", card.position.y + offset_y, 0.18)
	tween.tween_property(card, "modulate:a", 0.0, 0.18)
	await tween.finished
	card.queue_free()
	await get_tree().process_frame
	_arrange_fan(hand, hand == MaoInimigo)


# ---------------- MÃO DO JOGADOR ----------------

func _add_card_to_hand(data: CardData) -> void:
	var card: Control = CARD_SCENE.instantiate()
	card.card_data = data
	Mao.add_child(card)
	card.card_used.connect(_on_card_used)
	card.preview_requested.connect(_show_preview)
	card.preview_cancelled.connect(_on_preview_cancelled)


func draw_card(amount: int = 1, _card_data = null) -> void:
	for i in range(amount):
		var data: CardData = _pop_random(deck)
		if data == null:
			print("[DECK] Deck do jogador vazio.")
			break
		_add_card_to_hand(data)
	arrange_hand()


func arrange_hand() -> void:
	_arrange_fan(Mao, false)


# ---------------- MÃO DO INIMIGO ----------------

func _add_enemy_card_to_hand(data: CardData) -> void:
	var card: Control = CARD_SCENE.instantiate()
	card.is_enemy = true
	card.back_texture = enemy_back_texture
	card.card_data = data  # guardado para as mecânicas futuras (o jogador não vê)
	MaoInimigo.add_child(card)


func draw_enemy_card(amount: int = 1) -> void:
	for i in range(amount):
		var data: CardData = _pop_random(enemy_deck)
		if data == null:
			print("[DECK] Deck do inimigo vazio.")
			break
		_add_enemy_card_to_hand(data)
	arrange_enemy_hand()


func arrange_enemy_hand() -> void:
	_arrange_fan(MaoInimigo, true)


# ---------------- LEQUE (card fanning) ----------------
# mirrored = true inverte a curva e a inclinação, para o leque do inimigo
# "abrir" para baixo, de frente para o do jogador.

func _arrange_fan(hand: Node2D, mirrored: bool) -> void:
	var cards: Array[Node] = hand.get_children()
	var count: int = cards.size()
	if count == 0:
		return

	var side: float = -1.0 if mirrored else 1.0

	for index in range(count):
		var card: Control = cards[index] as Control
		if card == null:
			continue

		var ratio: float = 0.5 if count == 1 else float(index) / float(count - 1)
		var target_x: float = ratio * HAND_SPREAD
		var target_y: float = -sin(ratio * PI) * FAN_HEIGHT * side
		var target_rotation: float = 0.0 if count == 1 else lerpf(-MAX_ROTATION, MAX_ROTATION, ratio) * side

		var tween: Tween = create_tween()
		tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(card, "position", Vector2(target_x, target_y), 0.22)
		tween.parallel().tween_property(card, "rotation", target_rotation, 0.22)
		card.z_index = index


# ---------------- PREVIEW DA CARTA (lado direito) ----------------

func _show_preview(source: Control) -> void:
	if not is_instance_valid(source) or source.card_data == null:
		return

	_hide_preview(true)  # remove qualquer preview anterior na hora

	var preview: Control = CARD_SCENE.instantiate()
	preview.is_preview = true
	preview.card_data = source.card_data
	preview.scale = Vector2.ONE * PREVIEW_SCALE
	preview.modulate.a = 0.0
	_preview_layer.add_child(preview)

	var viewport_size: Vector2 = get_viewport_rect().size
	var target: Vector2 = Vector2(
		viewport_size.x - 128.0 * PREVIEW_SCALE - PREVIEW_MARGIN_RIGHT,
		viewport_size.y / 2.0 - 96.0 * PREVIEW_SCALE
	)
	preview.position = target + Vector2(PREVIEW_SLIDE, 0.0)  # começa mais à direita

	_preview_card = preview
	_preview_tween = create_tween()
	_preview_tween.set_parallel(true)
	_preview_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_preview_tween.tween_property(preview, "position", target, PREVIEW_TIME)
	_preview_tween.tween_property(preview, "modulate:a", 1.0, PREVIEW_TIME)


func _on_preview_cancelled(_source: Control) -> void:
	_hide_preview()


func _hide_preview(instant: bool = false) -> void:
	if _preview_tween != null and _preview_tween.is_valid():
		_preview_tween.kill()

	var old: Control = _preview_card
	_preview_card = null
	if not is_instance_valid(old):
		return

	if instant:
		old.queue_free()
		return

	var fade: Tween = create_tween()
	fade.tween_property(old, "modulate:a", 0.0, 0.12)
	fade.tween_callback(old.queue_free)


# ---------------- DEBUG (vida / turno no Output) ----------------

func _on_vida_mudou(lado: int, atual: int, maximo: int) -> void:
	var quem: String = "Jogador" if lado == GlobalCard.Lado.JOGADOR else "Inimigo"
	print("[VIDA] %s: %d / %d" % [quem, atual, maximo])


func _on_turno_mudou(numero_turno: int, lado_da_vez: int) -> void:
	var quem: String = "Jogador" if lado_da_vez == GlobalCard.Lado.JOGADOR else "Inimigo"
	print("[TURNO] Turno %d - vez do %s" % [numero_turno, quem])


# ---------------- TESTE TEMPORÁRIO (apague depois) ----------------
# 1 = jogador toma 3 de dano | 2 = inimigo toma 3 | 3 = soma 1 na noite do Global

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				GlobalCard.receber_dano(GlobalCard.Lado.JOGADOR, 3)
			KEY_2:
				GlobalCard.receber_dano(GlobalCard.Lado.INIMIGO, 3)
			KEY_3:
				Global.noite += 1
				print("[NOITE] Agora é a noite %d (a partida atual continua na noite %d)" % [Global.noite, noite_da_partida])
