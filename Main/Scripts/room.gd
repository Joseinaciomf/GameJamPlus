extends Control

# Referência à caixa de diálogo instanciada
@onready var dialogue_box = $DialogueBox

# Referência do contêiner de botões
@onready var hotspots_container = $HotSpots

# Caminho da cena da Batalha de Cartas e da Tela de Dicas
@export_file("*.tscn") var card_battle_scene_path: String = "res://Main/Scenes/card_game.tscn"
@export_file("*.tscn") var tips_scene_path: String = "res://Main/Scenes/tips_screen.tscn"

# Controle das anomalias encontradas
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

# Trava de segurança para impedir cliques nos hotspots enquanto as dicas estão abertas
var is_tips_active: bool = true

func _ready() -> void:
	# Conecta dinamicamente todos os botões existentes em HotSpots
	for child in hotspots_container.get_children():
		if child is Button:
			child.pressed.connect(_on_hotspot_pressed.bind(child.name))

	# Instancia a tela de dicas automaticamente no início da cena do quarto
	spawn_tips_screen()

func _process(_delta: float) -> void:
	if not dialogue_box:
		return
		
	var is_dialogue_visible = dialogue_box.get_node("DialogueControl").visible
	
	# Detecta o momento exato em que a caixa de diálogo fecha
	if is_dialogue_visible:
		was_dialogue_active = true
	elif was_dialogue_active and not is_dialogue_visible:
		was_dialogue_active = false
		
		# Se a última anomalia acabou de fechar, dispara o chefe
		if pending_boss_trigger:
			pending_boss_trigger = false
			trigger_boss_encounter()
		# Se o diálogo do chefe acabou de fechar, inicia a batalha de cartas
		elif waiting_for_boss_dialogue:
			waiting_for_boss_dialogue = false
			start_card_battle()

func spawn_tips_screen() -> void:
	if ResourceLoader.exists(tips_scene_path):
		var tips_instance = load(tips_scene_path).instantiate()
		# Conecta o sinal para saber quando o jogador abriu ou fechou o painel de dicas
		if tips_instance.has_signal("tips_toggled"):
			tips_instance.tips_toggled.connect(_on_tips_toggled)
		add_child(tips_instance)
	else:
		printerr("Cena de dicas não encontrada em: ", tips_scene_path)

func _on_tips_toggled(is_open: bool) -> void:
	is_tips_active = is_open

## Manipulador central de cliques dos hotspots
func _on_hotspot_pressed(button_name: String) -> void:
	# Bloqueia cliques se as dicas estiverem abertas ou se já houver diálogo aberto
	if is_tips_active:
		return
	if dialogue_box and dialogue_box.get_node("DialogueControl").visible:
		return

	match button_name:
		"ObjetoEspelho":
			play_dialogue_prefix("OBJ_ESPELHO")
		"ObjetoCama":
			play_dialogue_prefix("OBJ_CAMA")
		"ObjetoEscrivaninha":
			play_dialogue_prefix("OBJ_ESCRIVANINHA")
		"ObjetoGuardaRoupa":
			play_dialogue_prefix("OBJ_GUARDAROUPA")
		"ObjetoPorta":
			play_dialogue_prefix("OBJ_PORTA")
		"ObjetoJanela":
			register_anomaly("ANOMALIA_JANELA")
		"ObjetoRelogio":
			register_anomaly("ANOMALIA_RELOGIO")
		"ObjetoQuadro":
			register_anomaly("ANOMALIA_QUADRO")

## Registra a descoberta de uma anomalia
func register_anomaly(anomaly_prefix: String) -> void:
	if not anomalies_found.get(anomaly_prefix, false):
		anomalies_found[anomaly_prefix] = true
		print("Anomalia descoberta: ", anomaly_prefix)

	play_dialogue_prefix(anomaly_prefix)
	check_all_anomalies_found()

## Verifica se todas as 3 anomalias foram investigadas
func check_all_anomalies_found() -> void:
	var count: int = 0
	for key in anomalies_found:
		if anomalies_found[key]:
			count += 1

	if count >= total_anomalies_needed and not is_boss_triggered:
		is_boss_triggered = true
		pending_boss_trigger = true

## Dispara o diálogo de confronto com o Luto
func trigger_boss_encounter() -> void:
	print("Iniciando confronto com o Luto...")
	if dialogue_box:
		dialogue_box.start_dialogue_filtered("LUTO_BOSS", "res://Assets/Dialogues/Dialogues.csv")
		waiting_for_boss_dialogue = true

## Executa o diálogo filtrado baseado no prefixo do ID
func play_dialogue_prefix(prefix: String) -> void:
	if dialogue_box:
		dialogue_box.start_dialogue_filtered(prefix, "res://Assets/Dialogues/Dialogues.csv")

## Transiciona para a Batalha de Cartas
func start_card_battle() -> void:
	if ResourceLoader.exists(card_battle_scene_path):
		get_tree().change_scene_to_file(card_battle_scene_path)
	else:
		printerr("Cena de combate de cartas não encontrada em: ", card_battle_scene_path)
