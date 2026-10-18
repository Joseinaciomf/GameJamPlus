extends Resource
class_name CardData

# Valores dos efeitos (mude aqui para balancear)
const DANO_ATAQUE: int = 6      # Ataque: dano causado ao adversário
const ESCUDO_DEFESA: int = 4    # Defesa: pontos de escudo criados
const DANO_COUNTER: int = 10    # Counter: dano devolvido ao atacante

@export var card_name: String = ""
@export_multiline var card_description: String = ""
@export_enum("Ataque", "Defesa", "Counter")
var card_type: String = "Ataque"
@export var card_texture: Texture2D


# usuario = quem jogou a carta (GlobalCard.Lado.JOGADOR ou GlobalCard.Lado.INIMIGO)
func aplicar_efeito(usuario: int) -> void:
	match card_type:
		"Ataque":
			GlobalCard.atacar(usuario, DANO_ATAQUE)
		"Defesa":
			GlobalCard.ganhar_escudo(usuario, ESCUDO_DEFESA)
		"Counter":
			GlobalCard.ativar_counter(usuario, DANO_COUNTER)
