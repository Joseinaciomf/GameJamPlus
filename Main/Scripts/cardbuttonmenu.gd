extends HBoxContainer

# --- ANIMACOES DOS BOTOES ---
@export var hover_scale: Vector2 = Vector2(1.15, 1.15)
@export var duration: float = 0.12
@export var press_scale: Vector2 = Vector2(0.92, 0.92)

# --- EFEITOS SONOROS ---
@export_range(-40.0, 0.0, 1.0) var volume_sfx_db: float = -5.0
const SOM_HOVER: String = "res://Sons/SoundSelectButton.wav"
const SOM_CLIQUE: String = "res://Sons/Select.ogg"

var _tweens: Dictionary = {}
var _sfx_hover: AudioStreamPlayer
var _sfx_click: AudioStreamPlayer


func _ready() -> void:
	_sfx_hover = _criar_reprodutor("SomHover", SOM_HOVER)
	_sfx_click = _criar_reprodutor("SomClique", SOM_CLIQUE)

	for card in get_children():
		if card is TextureButton:
			_setup_card(card)


func _criar_reprodutor(nome: String, caminho: String) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.name = nome
	player.volume_db = volume_sfx_db
	player.bus = "Master"
	add_child(player)

	if ResourceLoader.exists(caminho):
		player.stream = load(caminho)
	else:
		push_warning("hbox_botoes: áudio não encontrado: " + caminho)
	return player


func _tocar(player: AudioStreamPlayer) -> void:
	if player != null and player.stream != null:
		player.play()


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
	var tween: Tween = create_tween()
	tween.tween_property(card, "scale", hover_scale if hovered else Vector2.ONE, duration) \
		.set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)
	_tweens[card] = tween
	if hovered:
		_tocar(_sfx_hover)


func _tween_card(card: TextureButton, target: Vector2, time: float, trans: Tween.TransitionType = Tween.TRANS_BACK) -> void:
	if _tweens.has(card) and _tweens[card]:
		_tweens[card].kill()
	var tween: Tween = create_tween()
	tween.tween_property(card, "scale", target, time) \
		.set_trans(trans) \
		.set_ease(Tween.EASE_OUT)
	_tweens[card] = tween


func _on_press(card: TextureButton) -> void:
	_tween_card(card, press_scale, 0.06, Tween.TRANS_QUAD)


func _on_release(card: TextureButton) -> void:
	var target: Vector2 = hover_scale if card.is_hovered() else Vector2.ONE
	_tween_card(card, target, 0.2)


func _on_click(card: TextureButton) -> void:
	_tocar(_sfx_click)
	var flash: Tween = create_tween()
	card.modulate = Color(1.6, 1.6, 1.6)
	flash.tween_property(card, "modulate", Color.WHITE, 0.25)
	print("clicou em ", card.name)
