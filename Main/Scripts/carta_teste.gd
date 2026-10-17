extends Control
@onready var carta: Sprite2D = $Carta

var state: int = 0

func _process(_delta: float) -> void:
	if state == 1:
		position = Vector2(get_global_mouse_position().x + 23, get_global_mouse_position().y + 33)
		GlobalCard.is_dragging_card = true
		if Input.is_action_just_released("clicar"): #se soltar
			state = 0
			GlobalCard.is_dragging_card = false

func _on_gui_input(event: InputEvent) -> void:
	if state == 1: return #se ja ta no estado de arrastar
	if event.is_action_pressed("clicar"):
		state = 1

func _on_mouse_entered() -> void:
	card_is_focused(true)

func _on_mouse_exited() -> void:
	card_is_focused(false)

func card_is_focused(value: bool):
	if GlobalCard.is_dragging_card == true: 
		return
	if value:
		z_index = 10
		await tween_anim(0)
	else:
		z_index = 0
		await tween_anim(1)

func tween_anim(type: int):
	var t: Tween = create_tween()
	match type:
		0:
			t.tween_property($Carta, "scale", Vector2(1.2, 1.2), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		1:
			t.tween_property($Carta, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	await t.finished
