extends Node2D

# --- Nós ---
@onready var Mao: Node2D = $Mao
@onready var MaoInimigo: Node2D = $MaoInimigo

const CARD_SCENE: PackedScene = preload("res://Main/Scenes/carta.tscn")
const ATTACK_TEXTURE: Texture2D = preload("res://Assets/Carta de Ataque.png")
const DEFENSE_TEXTURE: Texture2D = preload("res://Assets/Carta de Defesa.png")
const COUNTER_TEXTURE: Texture2D = preload("res://Assets/Carta de Counter.png")

# Sons de cada tipo de carta (jogador e inimigo).
const SOM_ATAQUE: AudioStream = preload("res://Sons/CardAttack.wav")
const SOM_DEFESA: AudioStream = preload("res://Sons/CardDefen.wav")
const SOM_COUNTER: AudioStream = preload("res://Sons/CardEffectImpact.wav")

# Reprodutor de efeitos criado automaticamente ao iniciar a cena.
var card_sfx: AudioStreamPlayer

func tocar_som_carta(tipo: String) -> void:
	if card_sfx == null:
		return
	match tipo:
		"Ataque":
			card_sfx.stream = SOM_ATAQUE
		"Defesa":
			card_sfx.stream = SOM_DEFESA
		"Counter":
			card_sfx.stream = SOM_COUNTER
		_:
			return
	card_sfx.play()


# Arraste a imagem do "modelo de costas" aqui, no Inspector do nó CardGame.
@export var enemy_back_texture: Texture2D

# Sprites dos decks: arraste os nós DeckJogador e DeckInimigo para cá (Inspector do CardGame).
@export var deck_jogador: Sprite2D
@export var deck_inimigo: Sprite2D

const HAND_SPREAD: float = 290.0
const FAN_HEIGHT: float = 24.0
const MAX_ROTATION: float = 0.20
const CARD_SIZE: Vector2 = Vector2(128, 192)

# Compra de cartas (voo do deck até a mão)
const FAN_TIME: float = 0.22       # reorganização normal do leque
const DEAL_TIME: float = 0.45      # duração do voo do deck até a mão
const DEAL_STAGGER: float = 0.12   # intervalo entre uma carta e a próxima

# Tempos do fluxo de jogada (segundos)
const PLAYER_PREVIEW_TIME: float = 1.0  # tempo que a carta do jogador fica visível
const ENEMY_PREVIEW_TIME: float = 1.3   # tempo que a carta do inimigo fica visível

# Preview de carta (direita = hover do jogador, esquerda = carta jogada pelo inimigo)
const PREVIEW_SCALE: float = 2
const PREVIEW_MARGIN: float = 60.0
const PREVIEW_SLIDE: float = 60.0
const PREVIEW_TIME: float = 0.3
const PREVIEW_FADE_OUT: float = 0.2

var deck: Array[CardData] = []
var enemy_deck: Array[CardData] = []

# Noite em que esta partida de cartas está acontecendo (lida do Global.gd).
var noite_da_partida: int = 1

# Na primeira vez que o jogador joga um Counter, o inimigo é forçado a usar um Ataque.
var _primeiro_counter_usado: bool = false

# Textura normal dos decks (guardada no início; trocada por "Modelo de Costas" na última carta)
var _deck_texture_jogador: Texture2D
var _deck_texture_inimigo: Texture2D

var _preview_layer: CanvasLayer
var _preview_card: Control


func _ready() -> void:
	randomize()

	# O nó é criado por código: não precisa editar card_game.tscn.
	card_sfx = AudioStreamPlayer.new()
	card_sfx.name = "CardSFX"
	card_sfx.volume_db = -5.0
	add_child(card_sfx)

	GlobalCard.vida_mudou.connect(_on_vida_mudou)
	GlobalCard.turno_mudou.connect(_on_turno_mudou)
	GlobalCard.escudo_mudou.connect(_on_escudo_mudou)
	GlobalCard.counter_mudou.connect(_on_counter_mudou)
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

	# As mãos ficam sempre desenhadas por cima dos decks.
	Mao.z_index = 5
	MaoInimigo.z_index = 5

	if deck_jogador != null:
		_deck_texture_jogador = deck_jogador.texture
	if deck_inimigo != null:
		_deck_texture_inimigo = deck_inimigo.texture

	deck = _build_player_deck()
	enemy_deck = _build_enemy_deck()
	_deal_initial_hands()


# Distribui as mãos iniciais: as cartas saem dos decks, uma a uma, e montam o leque.
func _deal_initial_hands() -> void:
	GlobalCard.acao_em_andamento = true  # bloqueia cliques durante a distribuição

	var player_hand: Array[CardData] = _take_starting_hand(deck, 3, 1, 1)
	var enemy_hand: Array[CardData] = _take_starting_hand(enemy_deck, 3, 2, 0)  # inimigo não tem Counter
	var total: int = maxi(player_hand.size(), enemy_hand.size())

	for i in range(total):
		var delay: float = i * DEAL_STAGGER
		if i < player_hand.size():
			var card: Control = _add_card_to_hand(player_hand[i])
			_start_at_deck(card, Mao, deck_jogador, delay)
		if i < enemy_hand.size():
			var enemy_card: Control = _add_enemy_card_to_hand(enemy_hand[i])
			_start_at_deck(enemy_card, MaoInimigo, deck_inimigo, delay + DEAL_STAGGER / 2.0)

	arrange_hand()
	arrange_enemy_hand()
	_refresh_decks()

	await get_tree().create_timer(total * DEAL_STAGGER + DEAL_TIME + 0.1).timeout
	GlobalCard.acao_em_andamento = false


# ---------------- DECKS ----------------

func _build_deck_from(ataques: int, defesas: int, counters: int) -> Array[CardData]:
	var new_deck: Array[CardData] = []

	for i in range(ataques):
		new_deck.append(_make_card_data("Carta de Ataque", "Causa 6 de dano ao adversário.", "Ataque", ATTACK_TEXTURE))
	for i in range(defesas):
		new_deck.append(_make_card_data("Carta de Defesa", "Cria 4 pontos de escudo para o usuário.", "Defesa", DEFENSE_TEXTURE))
	for i in range(counters):
		new_deck.append(_make_card_data("Carta de Counter", "Se sofrer um ataque, retorna 10 de dano ao adversário.", "Counter", COUNTER_TEXTURE))

	new_deck.shuffle()
	return new_deck


func _build_player_deck() -> Array[CardData]:
	return _build_deck_from(10, 7, 3)


# O inimigo NÃO tem cartas de Counter (exclusivas do jogador).
# Ponto de entrada para o inimigo mudar conforme a noite (noite_da_partida).
func _build_enemy_deck() -> Array[CardData]:
	return _build_deck_from(10, 10, 0)


func _make_card_data(card_name: String, card_description: String, card_type: String, texture: Texture2D) -> CardData:
	var data: CardData = CardData.new()
	data.card_name = card_name
	data.card_description = card_description
	data.card_type = card_type
	data.card_texture = texture
	return data


func _take_starting_hand(source_deck: Array[CardData], ataques: int, defesas: int, counters: int) -> Array[CardData]:
	var starting_hand: Array[CardData] = []
	_take_cards_of_type(source_deck, "Ataque", ataques, starting_hand)
	_take_cards_of_type(source_deck, "Defesa", defesas, starting_hand)
	_take_cards_of_type(source_deck, "Counter", counters, starting_hand)
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
# 1) jogador usa uma carta: ela aparece à direita (breve) e o efeito é aplicado
# 2) assim que ela some, é a vez do inimigo: uma carta da mão dele aparece à
#    esquerda e o efeito é aplicado
# 3) assim que ela some, ambos compram uma carta aleatória do próprio deck
# Enquanto isso o jogador não consegue jogar (GlobalCard.acao_em_andamento).
#
# Counter: só vale durante a resposta do inimigo NESTA rodada. Se o inimigo não
# usar um Ataque, o counter expira sem fazer nada (carta de "sorte").
# Exceção: na primeira vez que o jogador joga um Counter, o inimigo é forçado
# a usar um Ataque.

func _on_card_used(card: Control) -> void:
	if not is_instance_valid(card):
		return

	GlobalCard.acao_em_andamento = true
	_hide_preview(true)
	card.set_process_input(false)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_run_round(card)


func _run_round(player_card: Control) -> void:
	# Antes de jogar: foi um Counter pela primeira vez?
	var player_data: CardData = player_card.card_data
	var forcar_ataque: bool = false
	if player_data != null and player_data.card_type == "Counter" and not _primeiro_counter_usado:
		_primeiro_counter_usado = true
		forcar_ataque = true

	# 1) jogador
	await _play_card(player_card, GlobalCard.Lado.JOGADOR)

	# 2) inimigo
	GlobalCard.proximo_turno()  # vez do inimigo
	var enemy_card: Control = _pick_enemy_card(forcar_ataque)
	if enemy_card != null:
		await _play_card(enemy_card, GlobalCard.Lado.INIMIGO)
	else:
		print("[INIMIGO] Sem cartas na mão para jogar.")

	# O counter do jogador só valia para esta resposta do inimigo.
	GlobalCard.expirar_counter(GlobalCard.Lado.JOGADOR)

	# 3) compras (espera as cartas chegarem na mão antes de liberar o jogador)
	draw_card(1)
	draw_enemy_card(1)
	await get_tree().create_timer(DEAL_TIME + 0.1).timeout

	GlobalCard.proximo_turno()  # volta a vez do jogador
	GlobalCard.acao_em_andamento = false


# Escolhe a carta que o inimigo vai jogar (aleatória, ou obrigatoriamente Ataque).
func _pick_enemy_card(forcar_ataque: bool) -> Control:
	var candidates: Array[Control] = []
	for child in MaoInimigo.get_children():
		if not child.is_queued_for_deletion():
			candidates.append(child as Control)

	if forcar_ataque:
		var ataques: Array[Control] = []
		for c in candidates:
			if c.card_data != null and c.card_data.card_type == "Ataque":
				ataques.append(c)

		if not ataques.is_empty():
			return ataques.pick_random()

		# Sem Ataque na mão? Pega um do deck do inimigo e coloca na mão.
		for index in range(enemy_deck.size()):
			if enemy_deck[index].card_type == "Ataque":
				_add_enemy_card_to_hand(enemy_deck.pop_at(index))
				_refresh_decks()
				return MaoInimigo.get_child(MaoInimigo.get_child_count() - 1) as Control

	if candidates.is_empty():
		return null
	return candidates.pick_random()


# Joga uma carta: sai da mão, aparece ampliada (jogador = direita, inimigo = esquerda),
# aplica o efeito, fica visível um tempo e some. Só retorna quando a carta sumiu.
func _play_card(card: Control, lado: int) -> void:
	var is_player: bool = lado == GlobalCard.Lado.JOGADOR
	var data: CardData = card.card_data
	var hand: Node2D = Mao if is_player else MaoInimigo

	_discard_card(card, -90.0 if is_player else 90.0, hand)  # roda em paralelo

	var preview: Control = null
	if data != null:
		print("[%s] Jogou: %s" % ["JOGADOR" if is_player else "INIMIGO", data.card_name])
		preview = _spawn_preview(data, not is_player)
		tocar_som_carta(data.card_type)
		data.aplicar_efeito(lado)  # efeito definido no card_data.gd

	var hold: float = PLAYER_PREVIEW_TIME if is_player else ENEMY_PREVIEW_TIME
	await get_tree().create_timer(PREVIEW_TIME + hold).timeout
	if preview != null:
		await _fade_out_preview(preview).finished


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

func _add_card_to_hand(data: CardData) -> Control:
	var card: Control = CARD_SCENE.instantiate()
	card.card_data = data
	Mao.add_child(card)
	card.card_used.connect(_on_card_used)
	card.preview_requested.connect(_show_preview)
	card.preview_cancelled.connect(_on_preview_cancelled)
	return card


func draw_card(amount: int = 1, _card_data = null) -> void:
	var drawn: int = 0
	for i in range(amount):
		var data: CardData = _pop_random(deck)
		if data == null:
			print("[DECK] Deck do jogador vazio.")
			break
		var card: Control = _add_card_to_hand(data)
		_start_at_deck(card, Mao, deck_jogador, i * DEAL_STAGGER)
		drawn += 1
	arrange_hand()
	_refresh_decks_after(maxi(drawn - 1, 0) * DEAL_STAGGER)


func arrange_hand() -> void:
	_arrange_fan(Mao, false)


# ---------------- MÃO DO INIMIGO ----------------

func _add_enemy_card_to_hand(data: CardData) -> Control:
	var card: Control = CARD_SCENE.instantiate()
	card.is_enemy = true
	card.back_texture = enemy_back_texture
	card.card_data = data  # guardado para as mecânicas futuras (o jogador não vê)
	MaoInimigo.add_child(card)
	return card


func draw_enemy_card(amount: int = 1) -> void:
	var drawn: int = 0
	for i in range(amount):
		var data: CardData = _pop_random(enemy_deck)
		if data == null:
			print("[DECK] Deck do inimigo vazio.")
			break
		var card: Control = _add_enemy_card_to_hand(data)
		_start_at_deck(card, MaoInimigo, deck_inimigo, i * DEAL_STAGGER)
		drawn += 1
	arrange_enemy_hand()
	_refresh_decks_after(maxi(drawn - 1, 0) * DEAL_STAGGER)


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

		# Cartas recém-compradas voam do deck (com atraso e um pouco mais devagar).
		var dealt: bool = card.has_meta("deal_delay")
		var delay: float = card.get_meta("deal_delay", 0.0)
		var duration: float = DEAL_TIME if dealt else FAN_TIME

		var tween: Tween = create_tween()
		tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(card, "position", Vector2(target_x, target_y), duration).set_delay(delay)
		tween.parallel().tween_property(card, "rotation", target_rotation, duration).set_delay(delay)
		if dealt:
			tween.parallel().tween_property(card, "modulate:a", 1.0, 0.15).set_delay(delay)
			card.remove_meta("deal_delay")
		card.z_index = index


# ---------------- SPRITES DOS DECKS ----------------

# Coloca a carta recém-criada em cima do deck (virada como o deck) e a deixa invisível
# até a hora dela sair (delay). O _arrange_fan faz o voo do deck até a mão.
func _start_at_deck(card: Control, hand: Node2D, deck_sprite: Sprite2D, delay: float) -> void:
	if deck_sprite == null:
		return  # sem sprite de deck configurado: a carta só desliza para o leque

	var rot: float = deck_sprite.global_rotation - hand.global_rotation
	var center: Vector2 = hand.to_local(deck_sprite.global_position)
	card.rotation = rot
	card.position = center - (CARD_SIZE / 2.0).rotated(rot)  # centro da carta = centro do deck
	card.modulate.a = 0.0
	card.set_meta("deal_delay", delay)


func _refresh_decks_after(delay: float) -> void:
	if delay <= 0.0:
		_refresh_decks()
	else:
		get_tree().create_timer(delay).timeout.connect(_refresh_decks)


func _refresh_decks() -> void:
	_update_deck_sprite(deck_jogador, _deck_texture_jogador, deck.size())
	_update_deck_sprite(deck_inimigo, _deck_texture_inimigo, enemy_deck.size())


# Mais de 1 carta: textura normal | 1 carta: "Modelo de Costas" | 0 cartas: some.
func _update_deck_sprite(sprite: Sprite2D, normal_texture: Texture2D, remaining: int) -> void:
	if sprite == null or not sprite.visible:
		return

	if remaining <= 0:
		var fade: Tween = create_tween()
		fade.tween_property(sprite, "modulate:a", 0.0, 0.25)
		fade.tween_callback(sprite.hide)
	elif remaining == 1 and enemy_back_texture != null:
		sprite.texture = enemy_back_texture
	elif normal_texture != null:
		sprite.texture = normal_texture


# ---------------- PREVIEW DE CARTAS ----------------
# left_side = false -> direita da tela (hover do jogador)
# left_side = true  -> esquerda da tela (carta jogada pelo inimigo)

func _spawn_preview(data: CardData, left_side: bool) -> Control:
	var preview: Control = CARD_SCENE.instantiate()
	preview.is_preview = true
	preview.card_data = data
	preview.scale = Vector2.ONE * PREVIEW_SCALE
	preview.modulate.a = 0.0
	_preview_layer.add_child(preview)

	var viewport_size: Vector2 = get_viewport_rect().size
	var target_y: float = viewport_size.y / 2.0 - 96.0 * PREVIEW_SCALE
	var target_x: float
	var slide: float
	if left_side:
		target_x = PREVIEW_MARGIN
		slide = -PREVIEW_SLIDE      # entra vindo da esquerda
	else:
		target_x = viewport_size.x - 128.0 * PREVIEW_SCALE - PREVIEW_MARGIN
		slide = PREVIEW_SLIDE       # entra vindo da direita

	var target: Vector2 = Vector2(target_x, target_y)
	preview.position = target + Vector2(slide, 0.0)

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(preview, "position", target, PREVIEW_TIME)
	tween.tween_property(preview, "modulate:a", 1.0, PREVIEW_TIME)
	preview.set_meta("tween", tween)
	return preview


# Faz o fade out e remove o preview. Retorna o Tween (dá para dar await em .finished).
func _fade_out_preview(preview: Control) -> Tween:
	var old_tween: Variant = preview.get_meta("tween", null)
	if old_tween != null and old_tween.is_valid():
		old_tween.kill()

	var fade: Tween = create_tween()
	fade.tween_property(preview, "modulate:a", 0.0, PREVIEW_FADE_OUT)
	fade.tween_callback(preview.queue_free)
	return fade


# --- preview do hover do jogador (direita) ---

func _show_preview(source: Control) -> void:
	if not is_instance_valid(source) or source.card_data == null:
		return

	# Sem preview de hover durante a rodada (a carta jogada ocupa o lado direito).
	if GlobalCard.turno_atual != GlobalCard.Lado.JOGADOR or GlobalCard.acao_em_andamento:
		return

	_hide_preview(true)  # remove qualquer preview anterior na hora
	_preview_card = _spawn_preview(source.card_data, false)


func _on_preview_cancelled(_source: Control) -> void:
	_hide_preview()


func _hide_preview(instant: bool = false) -> void:
	var old: Control = _preview_card
	_preview_card = null
	if not is_instance_valid(old):
		return

	if instant:
		old.queue_free()
	else:
		_fade_out_preview(old)


# ---------------- DEBUG (vida / turno no Output) ----------------

func _on_vida_mudou(lado: int, atual: int, maximo: int) -> void:
	var quem: String = "Jogador" if lado == GlobalCard.Lado.JOGADOR else "Inimigo"
	print("[VIDA] %s: %d / %d" % [quem, atual, maximo])


func _on_turno_mudou(numero_turno: int, lado_da_vez: int) -> void:
	var quem: String = "Jogador" if lado_da_vez == GlobalCard.Lado.JOGADOR else "Inimigo"
	print("[TURNO] Turno %d - vez do %s" % [numero_turno, quem])


func _on_escudo_mudou(lado: int, valor: int) -> void:
	var quem: String = "Jogador" if lado == GlobalCard.Lado.JOGADOR else "Inimigo"
	print("[ESCUDO] %s: %d" % [quem, valor])


func _on_counter_mudou(lado: int, dano_refletido: int) -> void:
	var quem: String = "Jogador" if lado == GlobalCard.Lado.JOGADOR else "Inimigo"
	if dano_refletido > 0:
		print("[COUNTER] %s armou um counter (devolve %d de dano)" % [quem, dano_refletido])
	else:
		print("[COUNTER] %s sem counter ativo" % quem)


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
