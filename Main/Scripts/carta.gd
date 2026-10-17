
extends Control

signal card_used(card: Control)

@export var card_data: CardData

@onready var carta: Sprite2D = $Carta
@onready var nome: RichTextLabel = $Nome
@onready var descricao: RichTextLabel = $Descrição

var is_hovered: bool = false
var base_card_scale: Vector2 = Vector2(1.25, 1.25)
var is_used: bool = false
var _hover_tween: Tween


func _ready() -> void:
	custom_minimum_size = Vector2(128, 192)
	size = Vector2(128, 192)
	mouse_filter = Control.MOUSE_FILTER_STOP

	carta.position = size / 2.0
	carta.scale = Vector2(1.25, 1.25)
	base_card_scale = Vector2(1.25, 1.25)

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
	if is_used:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			is_used = true
			accept_event()
			card_used.emit(self)


func _on_mouse_entered() -> void:
	if is_used:
		return

	is_hovered = true
	z_index = 100
	_animate_hover(1.3)


func _on_mouse_exited() -> void:
	is_hovered = false

	if is_used:
		return

	z_index = 0
	_animate_hover(1.0)


func _animate_hover(factor: float) -> void:
	if is_instance_valid(_hover_tween) and _hover_tween.is_running():
		_hover_tween.kill()

	_hover_tween = create_tween()
	_hover_tween.set_trans(Tween.TRANS_BACK)
	_hover_tween.set_ease(Tween.EASE_OUT)
	_hover_tween.set_parallel(true)

	# Anima cada elemento separadamente para evitar deslocar a carta inteira.
	_hover_tween.tween_property(
		carta,
		"scale",
		base_card_scale * factor,
		0.22
	)
	_hover_tween.tween_property(
		nome,
		"scale",
		Vector2.ONE * factor,
		0.22
	)
	_hover_tween.tween_property(
		descricao,
		"scale",
		Vector2.ONE * factor,
		0.22
	)
