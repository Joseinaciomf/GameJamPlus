extends Node2D
@onready var Mao: Node2D = $Mao


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	draw_card(5, null)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
func draw_card(amount: int, card_data):
	for i in range(amount):
		var spacing: int = 80
		var card_scene: Control = load("res://Main/Scenes/cartaTeste.tscn").instantiate()
		card_scene.position.x = i * spacing
		Mao.add_child(card_scene)
