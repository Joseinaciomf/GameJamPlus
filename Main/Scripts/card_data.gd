
extends Resource
class_name CardData

@export var card_name: String = ""
@export_multiline var card_description: String = ""
@export_enum("Ataque", "Defesa", "Counter")
var card_type: String = "Ataque"
@export var card_texture: Texture2D
