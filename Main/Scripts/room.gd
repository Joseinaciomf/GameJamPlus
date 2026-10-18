extends Control

# Referência à caixa de diálogo instanciada
@onready var dialogue_box = $DialogueBox

# Referência direta do contêiner de botões
@onready var hotspots_container = $HotSpots

# Caminho da cena da Batalha de Cartas e da Tela de Dicas
@export_file("*.tscn") var card_battle_scene_path: String = "res://Main/Scenes/card_game.tscn"
@export_file("*.tscn") var tips_scene_path: String = "res://Main/Scenes/tips_screen.tscn"

var is_intro_dialogue_finished: bool = false
var waiting_for_door_battle: bool = false
var was_dialogue_active: bool = false

# Trava de segurança para impedir cliques nos hotspots enquanto as dicas estão abertas
var is_tips_active: bool = false

func _ready() -> void:
	# Conecta dinamicamente todos os botões existentes em HotSpots
	for child in hotspots_container.get_children():
		if child is Button:
			child.pressed.connect(_on_hotspot_pressed.bind(child.name))

	# Instancia a tela de dicas de forma modular (apenas botão flutuante ?)
	spawn_tips_screen()

	# Dispara o diálogo da Sombra logo no início da cena do quarto
	trigger_intro_shadow()

func _process(_delta: float) -> void:
	if not dialogue_box:
		return
		
	var is_dialogue_visible = dialogue_box.get_node("DialogueControl").visible
	
	if is_dialogue_visible:
		was_dialogue_active = true
	elif was_dialogue_active and not is_dialogue_visible:
		was_dialogue_active = false
		
		# Se a introdução da Sombra terminou, libera o jogador
		if not is_intro_dialogue_finished:
			is_intro_dialogue_finished = true
			print("Diálogo inicial da Sombra finalizado. Jogador livre.")
		
		# Se o diálogo da porta terminou, muda para o card game
		elif waiting_for_door_battle:
			waiting_for_door_battle = false
			start_card_battle()

func spawn_tips_screen() -> void:
	if ResourceLoader.exists(tips_scene_path):
		var tips_instance = load(tips_scene_path).instantiate()
		if tips_instance.has_signal("tips_toggled"):
			tips_instance.tips_toggled.connect(_on_tips_toggled)
		add_child(tips_instance)
	else:
		printerr("Cena de dicas não encontrada em: ", tips_scene_path)

func _on_tips_toggled(is_open: bool) -> void:
	is_tips_active = is_open

## Manipulador central de cliques dos hotspots
func _on_hotspot_pressed(button_name: String) -> void:
	if is_tips_active:
		return
	if dialogue_box and dialogue_box.get_node("DialogueControl").visible:
		return

	# Impede interações enquanto o diálogo inicial da Sombra estiver rolando
	if not is_intro_dialogue_finished:
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
			trigger_door_encounter()
		"ObjetoJanela":
			play_dialogue_prefix("OBJ_JANELA")
		"ObjetoQuadro":
			play_dialogue_prefix("OBJ_QUADRO")

## Dispara o diálogo inicial da Sombra ao entrar no quarto
func trigger_intro_shadow() -> void:
	if dialogue_box:
		dialogue_box.start_dialogue_filtered("Sombra", "res://Assets/Dialogues/Dialogues.csv")

## Dispara o diálogo da porta que antecede o card game
func trigger_door_encounter() -> void:
	print("Interagindo com a porta...")
	if dialogue_box:
		dialogue_box.start_dialogue_filtered("OBJ_PORTA", "res://Assets/Dialogues/Dialogues.csv")
		waiting_for_door_battle = true

func play_dialogue_prefix(prefix: String) -> void:
	if dialogue_box:
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
