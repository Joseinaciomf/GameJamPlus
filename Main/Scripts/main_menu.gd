extends Control

# --- PARALLAX COM O MOUSE ---
@export var intensidade: Array[float] = [8.0, 16.0, 28.0, 45.0, 70.0]
@export_range(0.5, 20.0, 0.1) var suavidade: float = 5.0
@export var inverter: bool = true

# --- AUDIO DO MENU ---
@export_range(-40.0, 0.0, 1.0) var volume_musica_db: float = -10.0
@export_range(0.0, 1.0, 0.01) var atraso_transicao: float = 0.22

const TOTAL_CAMADAS: int = 5
const MUSICA_MENU: String = "res://Sons/Abertura.wav"

var _camadas: Array[Node2D] = []
var _posicoes_base: Array[Vector2] = []
var _musica: AudioStreamPlayer
var _em_transicao: bool = false


func _ready() -> void:
	for numero in range(1, TOTAL_CAMADAS + 1):
		var camada: Node2D = get_node_or_null("Camada%d" % numero) as Node2D
		if camada == null:
			push_warning("main_menu: nó 'Camada%d' não encontrado." % numero)
		else:
			camada.z_index = -10 + numero
		_camadas.append(camada)
		_posicoes_base.append(camada.position if camada != null else Vector2.ZERO)

	_iniciar_musica()


func _iniciar_musica() -> void:
	if not ResourceLoader.exists(MUSICA_MENU):
		push_warning("main_menu: música não encontrada: " + MUSICA_MENU)
		return

	_musica = AudioStreamPlayer.new()
	_musica.name = "MusicaMenu"
	_musica.volume_db = volume_musica_db
	_musica.bus = "Master"
	add_child(_musica)

	var audio: AudioStream = load(MUSICA_MENU)
	# Faz a faixa WAV repetir sem mudar o arquivo importado no projeto.
	if audio is AudioStreamWAV:
		var audio_loop: AudioStreamWAV = audio.duplicate() as AudioStreamWAV
		audio_loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
		_musica.stream = audio_loop
	else:
		_musica.stream = audio

	_musica.play()


func _process(delta: float) -> void:
	var centro: Vector2 = get_viewport_rect().size / 2.0
	if centro.x <= 0.0 or centro.y <= 0.0:
		return
	var mouse: Vector2 = get_viewport().get_mouse_position()
	var deslocamento: Vector2 = ((mouse - centro) / centro).clamp(Vector2(-1, -1), Vector2(1, 1))
	var sentido: float = -1.0 if inverter else 1.0
	var peso: float = 1.0 - exp(-suavidade * delta)

	for i in range(_camadas.size()):
		var camada: Node2D = _camadas[i]
		if camada == null:
			continue
		var forca: float = intensidade[i] if i < intensidade.size() else 0.0
		var alvo: Vector2 = _posicoes_base[i] + deslocamento * forca * sentido
		camada.position = camada.position.lerp(alvo, peso)


func _trocar_cena(caminho: String) -> void:
	if _em_transicao:
		return
	_em_transicao = true
	# Dá tempo para o som de clique do HBox ser ouvido antes da troca.
	await get_tree().create_timer(atraso_transicao).timeout
	if not is_inside_tree():
		return
	if ResourceLoader.exists(caminho):
		get_tree().change_scene_to_file(caminho)
	else:
		push_error("main_menu: cena não encontrada: " + caminho)
		_em_transicao = false


func _on_exit_pressed() -> void:
	if _em_transicao:
		return
	_em_transicao = true
	await get_tree().create_timer(atraso_transicao).timeout
	get_tree().quit()


func _on_start_pressed() -> void:
	_trocar_cena("res://Main/Scenes/intro_story.tscn")


func _on_credits_pressed() -> void:
	_trocar_cena("res://Main/Scenes/credits.tscn")
