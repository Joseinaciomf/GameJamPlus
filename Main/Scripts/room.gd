extends Control

@onready var dialogue_box: CanvasLayer = $DialogueBox
@onready var hotspots_container: Node = $HotSpots

@export_file("*.tscn") var card_battle_scene_path: String = "res://Main/Scenes/card_game.tscn"
@export_file("*.tscn") var tips_scene_path: String = "res://Main/Scenes/tips_screen.tscn"

const MUSIC_ROOM: AudioStream = preload("res://Sons/GamePlayQ.wav")
const SOUND_RAIN: AudioStream = preload("res://Sons/Rain.wav")
const SOUND_SELECT: AudioStream = preload("res://Sons/Select.ogg")
const SOUND_ANOMALY: AudioStream = preload("res://Sons/CardEfeito.mp3")
const SOUND_BOSS: AudioStream = preload("res://Sons/SoundEnterFase.wav")

@export_range(-40.0, 6.0, 1.0) var music_volume_db: float = -12.0
@export_range(-40.0, 6.0, 1.0) var rain_volume_db: float = -20.0
@export_range(-40.0, 6.0, 1.0) var effects_volume_db: float = -6.0

var _music_player: AudioStreamPlayer
var _rain_player: AudioStreamPlayer
var _effects_player: AudioStreamPlayer
var _boss_player: AudioStreamPlayer

var anomalies_found: Dictionary = {
	"ANOMALIA_JANELA": false,
	"ANOMALIA_RELOGIO": false,
	"ANOMALIA_QUADRO": false
}
var total_anomalies_needed: int = 3
var is_boss_triggered: bool = false
var pending_boss_trigger: bool = false
var waiting_for_boss_dialogue: bool = false
var was_dialogue_active: bool = false
var is_tips_active: bool = false

func _ready() -> void:
	_configure_audio()
	if dialogue_box == null:
		push_error("Room: o nó DialogueBox não foi encontrado.")
		return
	# Evita que o CanvasLayer da caixa fique por trás do quarto.
	dialogue_box.visible = true
	dialogue_box.layer = 20
	for child in hotspots_container.get_children():
		if child is BaseButton:
			var button: BaseButton = child as BaseButton
			button.pressed.connect(_on_hotspot_pressed.bind(button.name))
	spawn_tips_screen()
	print("[ROOM] Preparado | DialogueBox=", dialogue_box.get_path(), " | dicas abertas=", is_tips_active)

func _make_audio_player(player_name: String, stream: AudioStream, volume: float, loop_audio: bool = false) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.name = player_name
	player.volume_db = volume
	var local_stream: AudioStream = stream.duplicate()
	if loop_audio:
		if local_stream is AudioStreamWAV:
			(local_stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		elif local_stream is AudioStreamOggVorbis:
			(local_stream as AudioStreamOggVorbis).loop = true
	player.stream = local_stream
	add_child(player)
	return player

func _configure_audio() -> void:
	_music_player = _make_audio_player("MusicRoom", MUSIC_ROOM, music_volume_db, true)
	_rain_player = _make_audio_player("RainAmbience", SOUND_RAIN, rain_volume_db, true)
	_effects_player = _make_audio_player("HotspotSFX", SOUND_SELECT, effects_volume_db)
	_boss_player = _make_audio_player("BossSFX", SOUND_BOSS, effects_volume_db)
	_music_player.play()
	_rain_player.play()

func _play_effect(stream: AudioStream) -> void:
	_effects_player.stream = stream
	_effects_player.play()

func _dialogue_visible() -> bool:
	if dialogue_box == null:
		return false
	var control: Control = dialogue_box.get_node_or_null("DialogueControl") as Control
	return control != null and control.visible

func _process(_delta: float) -> void:
	var is_dialogue_visible: bool = _dialogue_visible()
	if is_dialogue_visible:
		was_dialogue_active = true
	elif was_dialogue_active:
		was_dialogue_active = false
		if pending_boss_trigger:
			pending_boss_trigger = false
			trigger_boss_encounter()
		elif waiting_for_boss_dialogue:
			waiting_for_boss_dialogue = false
			start_card_battle()

func spawn_tips_screen() -> void:
	# Na ausência da cena/sinal, não deixa o quarto travado.
	is_tips_active = false
	if not ResourceLoader.exists(tips_scene_path):
		push_warning("Cena de dicas não encontrada: " + tips_scene_path)
		return
	var packed: PackedScene = load(tips_scene_path) as PackedScene
	if packed == null:
		return
	var tips_instance: Node = packed.instantiate()
	if tips_instance.has_signal("tips_toggled"):
		tips_instance.tips_toggled.connect(_on_tips_toggled)
	else:
		push_warning("A tela de dicas não emite tips_toggled; hotspots liberados.")
	add_child(tips_instance)
	# Caso o painel esteja aberto desde o início, informe isso pelo sinal
	# tips_toggled(true) no _ready() da própria tela de dicas.

func _on_tips_toggled(is_open: bool) -> void:
	is_tips_active = is_open
	print("[ROOM] Tela de dicas aberta=", is_open)

func _on_hotspot_pressed(button_name: String) -> void:
	print("[ROOM] Clique=", button_name, " | dicas=", is_tips_active, " | dialogo=", _dialogue_visible())
	if is_tips_active or _dialogue_visible():
		return
	match button_name:
		"ObjetoEspelho":
			_play_effect(SOUND_SELECT)
			play_dialogue_prefix("OBJ_ESPELHO")
		"ObjetoCama":
			_play_effect(SOUND_SELECT)
			play_dialogue_prefix("OBJ_CAMA")
		"ObjetoEscrivaninha":
			_play_effect(SOUND_SELECT)
			play_dialogue_prefix("OBJ_ESCRIVANINHA")
		"ObjetoGuardaRoupa":
			_play_effect(SOUND_SELECT)
			play_dialogue_prefix("OBJ_GUARDAROUPA")
		"ObjetoPorta":
			_play_effect(SOUND_SELECT)
			play_dialogue_prefix("OBJ_PORTA")
		"ObjetoJanela":
			register_anomaly("ANOMALIA_JANELA")
		"ObjetoRelogio":
			register_anomaly("ANOMALIA_RELOGIO")
		"ObjetoQuadro":
			register_anomaly("ANOMALIA_QUADRO")

func register_anomaly(anomaly_prefix: String) -> void:
	if not anomalies_found.get(anomaly_prefix, false):
		anomalies_found[anomaly_prefix] = true
		_play_effect(SOUND_ANOMALY)
		print("Anomalia descoberta: ", anomaly_prefix)
	else:
		_play_effect(SOUND_SELECT)
	play_dialogue_prefix(anomaly_prefix)
	check_all_anomalies_found()

func check_all_anomalies_found() -> void:
	var count: int = 0
	for key in anomalies_found:
		if anomalies_found[key]:
			count += 1
	if count >= total_anomalies_needed and not is_boss_triggered:
		is_boss_triggered = true
		pending_boss_trigger = true

func trigger_boss_encounter() -> void:
	print("Iniciando confronto com o Luto...")
	var fade: Tween = create_tween()
	fade.tween_property(_music_player, "volume_db", music_volume_db - 10.0, 0.7)
	_boss_player.play()
	waiting_for_boss_dialogue = true
	play_dialogue_prefix("LUTO_BOSS")

func play_dialogue_prefix(prefix: String) -> void:
	if dialogue_box == null:
		push_error("DialogueBox ausente ao tentar abrir: " + prefix)
		return
	print("[ROOM] Chamando diálogo: ", prefix)
	dialogue_box.start_dialogue_filtered(prefix, "res://Assets/Dialogues/Dialogues.csv")

func start_card_battle() -> void:
	print("[ROOM] Tentando iniciar batalha de cartas...")
	print("[ROOM] Caminho da cena: ", card_battle_scene_path)

	if card_battle_scene_path.is_empty():
		push_error("[ROOM] O caminho da batalha está vazio!")
		return

	if not ResourceLoader.exists(card_battle_scene_path):
		push_error("[ROOM] Cena não encontrada: " + card_battle_scene_path)
		return

	var battle_scene: PackedScene = ResourceLoader.load(
		card_battle_scene_path, "PackedScene"
	) as PackedScene

	if battle_scene == null:
		push_error("[ROOM] Não foi possível carregar a cena de cartas.")
		return

	var test_instance: Node = battle_scene.instantiate()

	if test_instance == null:
		push_error("[ROOM] A cena de cartas não pôde ser instanciada. Verifique as dependências da cena.")
		return

	test_instance.free()

	var error: Error = get_tree().change_scene_to_packed(battle_scene)

	if error != OK:
		push_error("[ROOM] Erro ao mudar para a cena de cartas: " + error_string(error))
	else:
		print("[ROOM] Transição para a batalha solicitada.")
