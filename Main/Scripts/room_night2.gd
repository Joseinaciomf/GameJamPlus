extends Control

@onready var dialogue_box = $DialogueBox
@onready var hotspots_container = $HotSpots

@export_file("*.tscn") var card_battle_scene_path: String = "res://Main/Scenes/card_game.tscn"
@export_file("*.tscn") var tips_scene_path: String = "res://Main/Scenes/tips_screen.tscn"

# Controle das 3 novas anomalias da Noite 2
var anomalies_found: Dictionary = {
	"ANOMALIA_PORTA_ARMARIO": false,
	"ANOMALIA_PEGADAS": false,
	"ANOMALIA_TELA_COMPUTADOR": false
}

var total_anomalies_needed: int = 3
var is_boss_triggered: bool = false
var pending_boss_trigger: bool = false
var waiting_for_boss_dialogue: bool = false
var was_dialogue_active: bool = false

var is_tips_active: bool = false

func _ready() -> void:
	# Conecta todos os hotspots
	for child in hotspots_container.get_children():
		if child is Button:
			child.pressed.connect(_on_hotspot_pressed.bind(child.name))

	# Instancia as dicas na tela (porém mantendo o painel fechado e apenas o botão ? visível)
	spawn_tips_screen()

func _process(_delta: float) -> void:
	if not dialogue_box:
		return
		
	var is_dialogue_visible = dialogue_box.get_node("DialogueControl").visible
	
	if is_dialogue_visible:
		was_dialogue_active = true
	elif was_dialogue_active and not is_dialogue_visible:
		was_dialogue_active = false
		
		if pending_boss_trigger:
			pending_boss_trigger = false
			trigger_boss_encounter()
		elif waiting_for_boss_dialogue:
			waiting_for_boss_dialogue = false
			start_next_phase()

## Instancia a interface de dicas já com o painel fechar por padrão (apenas botão ? visível)
func spawn_tips_screen() -> void:
	if ResourceLoader.exists(tips_scene_path):
		var tips_instance = load(tips_scene_path).instantiate()
		if tips_instance.has_signal("tips_toggled"):
			tips_instance.tips_toggled.connect(_on_tips_toggled)
		add_child(tips_instance)
		
		# Fecha o painel central no início da Noite 2 e deixa apenas o botão ? no canto
		if tips_instance.has_method("close_tips_panel"):
			tips_instance.close_tips_panel()
	else:
		printerr("Cena de dicas não encontrada em: ", tips_scene_path)

func _on_tips_toggled(is_open: bool) -> void:
	is_tips_active = is_open

## Manipulador central de cliques dos hotspots da Noite 2
func _on_hotspot_pressed(button_name: String) -> void:
	if is_tips_active:
		return
	if dialogue_box and dialogue_box.get_node("DialogueControl").visible:
		return

	match button_name:
		"ObjetoEspelho":
			play_dialogue_prefix("OBJ_ESPELHO_N2")
		"ObjetoCama":
			play_dialogue_prefix("OBJ_CAMA_N2")
		"ObjetoEscrivaninha":
			play_dialogue_prefix("OBJ_ESCRIVANINHA_N2")
		"ObjetoGuardaRoupa":
			play_dialogue_prefix("OBJ_GUARDAROUPA_N2")
		"ObjetoPorta":
			play_dialogue_prefix("OBJ_PORTA_N2")
		"ObjetoPortaArmario":
			register_anomaly("ANOMALIA_PORTA_ARMARIO")
		"ObjetoPegadas":
			register_anomaly("ANOMALIA_PEGADAS")
		"ObjetoTelaComputador":
			register_anomaly("ANOMALIA_TELA_COMPUTADOR")

func register_anomaly(anomaly_prefix: String) -> void:
	if not anomalies_found.get(anomaly_prefix, false):
		anomalies_found[anomaly_prefix] = true
		print("Anomalia da Noite 2 descoberta: ", anomaly_prefix)

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
	print("Iniciando segundo confronto com o Luto...")
	if dialogue_box:
		dialogue_box.start_dialogue_filtered("LUTO_BOSS2", "res://Assets/Dialogues/Dialogues.csv")
		waiting_for_boss_dialogue = true

func play_dialogue_prefix(prefix: String) -> void:
	if dialogue_box:
		dialogue_box.start_dialogue_filtered(prefix, "res://Assets/Dialogues/Dialogues.csv")

## Muda para a próxima fase (Combate de Cartas Noite 2 ou Perseguição)
func start_next_phase() -> void:
	if ResourceLoader.exists(card_battle_scene_path):
		get_tree().change_scene_to_file(card_battle_scene_path)
	else:
		printerr("Cena da batalha de cartas não encontrada em: ", card_battle_scene_path)
