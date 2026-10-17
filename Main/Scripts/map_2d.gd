extends Node2D

@onready var spawn_point: Marker2D = $SpawnPoint
@onready var player: CharacterBody2D = $Player
@onready var death_zone: Area2D = $DeathZone

func _ready() -> void:
	# Posiciona o jogador no ponto de spawn assim que a cena inicia
	if player and spawn_point:
		player.global_position = spawn_point.global_position
		
	# Conecta o sinal de quando o jogador entra na zona de queda/morte
	if death_zone:
		death_zone.body_entered.connect(_on_death_zone_body_entered)

func _on_death_zone_body_entered(body: Node2D) -> void:
	# Verifica se quem caiu na área foi o Player
	if body == player:
		# Retorna para o spawn e zera a velocidade para evitar bugs de inércia
		player.global_position = spawn_point.global_position
		player.velocity = Vector2.ZERO
