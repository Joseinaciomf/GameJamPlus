extends Control

# --- PARALLAX COM O MOUSE ---
# Camadas: nós Sprite2D chamados Camada1, Camada2, Camada3, Camada4 e Camada5.
# 1 = fundo (mais distante, quase não se mexe) ... 5 = mais próxima (mexe mais).
# Intensidade = quantos pixels a camada se desloca quando o mouse vai até a borda da tela.
# A lista do Inspector tem 5 valores: o elemento 0 é da Camada1, o 1 da Camada2, e assim por diante.
@export var intensidade: Array[float] = [8.0, 16.0, 28.0, 45.0, 70.0]

# Quanto maior, mais rápido a camada alcança o mouse (menor = mais "flutuante").
@export_range(0.5, 20.0, 0.1) var suavidade: float = 5.0

# true = as camadas andam no sentido contrário ao mouse (efeito mais comum de profundidade).
@export var inverter: bool = true

const TOTAL_CAMADAS: int = 5

var _camadas: Array[Node2D] = []
var _posicoes_base: Array[Vector2] = []


func _ready() -> void:
	for numero in range(1, TOTAL_CAMADAS + 1):
		var camada: Node2D = get_node_or_null("Camada%d" % numero) as Node2D
		if camada == null:
			push_warning("main_menu: nó 'Camada%d' não encontrado." % numero)
		else:
			camada.z_index = -10 + numero  # sempre atrás dos botões, na ordem 1 -> 5
		_camadas.append(camada)  # mantém o índice mesmo se faltar uma camada
		_posicoes_base.append(camada.position if camada != null else Vector2.ZERO)


func _process(delta: float) -> void:
	var centro: Vector2 = get_viewport_rect().size / 2.0
	var mouse: Vector2 = get_viewport().get_mouse_position()

	# Posição do mouse em relação ao centro da tela: de (-1, -1) a (1, 1).
	var deslocamento: Vector2 = ((mouse - centro) / centro).clamp(Vector2(-1, -1), Vector2(1, 1))

	var sentido: float = -1.0 if inverter else 1.0
	var peso: float = 1.0 - exp(-suavidade * delta)  # suavização independente do FPS

	for i in range(_camadas.size()):
		var camada: Node2D = _camadas[i]
		if camada == null:
			continue

		var forca: float = intensidade[i] if i < intensidade.size() else 0.0
		var alvo: Vector2 = _posicoes_base[i] + deslocamento * forca * sentido
		camada.position = camada.position.lerp(alvo, peso)


func _on_exit_pressed() -> void:
	get_tree().quit()


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file('res://Main/Scenes/intro_story.tscn')


func _on_credits_pressed() -> void:
	get_tree().change_scene_to_file('res://Main/Scenes/credits.tscn')
