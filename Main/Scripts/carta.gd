extends Control

signal card_used(card: Control)
signal preview_requested(card: Control)  # mouse ficou tempo suficiente em cima
signal preview_cancelled(card: Control)  # mouse saiu antes / depois do preview

const PREVIEW_DELAY: float = 1.2

@export var card_data: CardData

# Definidos pelo card_game.gd ANTES do add_child (por isso o _ready já enxerga).
var is_enemy: bool = false          # true = carta do inimigo (só mostra o verso)
var is_preview: bool = false        # true = cópia ampliada mostrada no preview
var back_texture: Texture2D = null  # textura do "modelo de costas"

@onready var carta: Sprite2D = $Carta
@onready var nome: RichTextLabel = $Nome
@onready var descricao: RichTextLabel = $Descrição

var is_hovered: bool = false
var base_card_scale: Vector2 = Vector2(1.25, 1.25)
var is_used: bool = false
var _hover_tween: Tween
var _preview_timer: Timer


func _ready() -> void:
	custom_minimum_size = Vector2(128, 192)
	size = Vector2(128, 192)

	carta.position = size / 2.0
	carta.scale = Vector2(1.25, 1.25)
	base_card_scale = Vector2(1.25, 1.25)

	if is_enemy:
		# Carta do inimigo: sem mouse (sem hover/clique) e sem textos.
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		nome.visible = false
		descricao.visible = false
		if back_texture != null:
			carta.texture = back_texture
		return

	if is_preview:
		# Cópia para leitura: mostra tudo, mas não reage ao mouse.
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		atualizar_visual()
		return

	mouse_filter = Control.MOUSE_FILTER_STOP

	# Timer do preview (criado por código, não precisa mexer no Inspector).
	_preview_timer = Timer.new()
	_preview_timer.one_shot = true
	_preview_timer.wait_time = PREVIEW_DELAY
	_preview_timer.timeout.connect(_on_preview_timer_timeout)
	add_child(_preview_timer)

	atualizar_visual()


func atualizar_visual() -> void:
	if card_data == null:
		nome.text = ""
		descricao.text = ""
		return

	nome.text = card_data.card_name
	descricao.text = card_data.card_description

	if card_data.card_texture != null:
		carta.texture = card_data.card_texture


func _on_gui_input(event: InputEvent) -> void:
	if is_enemy or is_preview or is_used:
		return

	# Só dá para jogar uma carta na vez do jogador.
	if GlobalCard.turno_atual != GlobalCard.Lado.JOGADOR:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			is_used = true
			_preview_timer.stop()
			accept_event()
			card_used.emit(self)


func _on_mouse_entered() -> void:
	if is_enemy or is_preview or is_used:
		return

	is_hovered = true
	z_index = 100
	_animate_hover(1.3)
	_preview_timer.start()  # (re)começa a contar 1.2s


func _on_mouse_exited() -> void:
	if is_enemy or is_preview:
		return

	is_hovered = false
	_preview_timer.stop()
	preview_cancelled.emit(self)

	if is_used:
		return

	z_index = 0
	_animate_hover(1.0)


func _on_preview_timer_timeout() -> void:
	if is_hovered and not is_used:
		preview_requested.emit(self)


func _animate_hover(factor: float) -> void:
	if is_instance_valid(_hover_tween) and _hover_tween.is_running():
		_hover_tween.kill()

	_hover_tween = create_tween()
	_hover_tween.set_trans(Tween.TRANS_BACK)
	_hover_tween.set_ease(Tween.EASE_OUT)
	_hover_tween.set_parallel(true)

	# Anima cada elemento separadamente para evitar deslocar a carta inteira.
	_hover_tween.tween_property(carta, "scale", base_card_scale * factor, 0.22)
	_hover_tween.tween_property(nome, "scale", Vector2.ONE * factor, 0.22)
	_hover_tween.tween_property(descricao, "scale", Vector2.ONE * factor, 0.22)
