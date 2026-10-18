extends CanvasLayer

# --- REFERÊNCIAS DOS NÓS ---
@onready var name_label: RichTextLabel = $DialogueControl/NameBox/MarginContainer/NameLabel
@onready var text_label: RichTextLabel = $DialogueControl/MainBox/MarginContainer/HBoxContainer/TextLabel
@onready var portrait: TextureRect = $Portrait
@onready var dialogue_control: Control = $DialogueControl
@onready var next_indicator: Label = $DialogueControl/MainBox/NextIndicator

# --- VARIÁVEIS DE CONFIGURAÇÃO ---
@export var text_speed: float = 0.03 # Velocidade da digitação

var current_sequence: Array = []
var text_database: Dictionary = {}
var current_index: int = 0
var is_typing: bool = false
var tween: Tween
var indicator_tween: Tween

func _ready() -> void:
	# Oculta por padrão
	dialogue_control.visible = false
	portrait.visible = false
	if next_indicator:
		next_indicator.visible = false

func _input(event: InputEvent) -> void:
	if not dialogue_control.visible:
		return

	var is_click: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	var is_space: bool = event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_select")

	if is_click or is_space:
		get_viewport().set_input_as_handled()
		
		if is_typing:
			finish_typing_instantly()
		else:
			advance_dialogue()

## Inicializa um diálogo filtrando os IDs pelo prefixo
func start_dialogue_filtered(prefix: String, csv_path: String) -> void:
	text_database = load_csv_data(csv_path)
	var full_sequence = load_json_data("res://Assets/Dialogues/dialogues.json")
	
	current_sequence = []
	for entry in full_sequence:
		if entry["id"].begins_with(prefix):
			current_sequence.append(entry)
			
	current_index = 0
	
	if current_sequence.size() > 0:
		dialogue_control.visible = true
		display_current_line()
	else:
		printerr("Nenhum diálogo encontrado com o prefixo: ", prefix)

## Leitor do CSV
func load_csv_data(file_path: String) -> Dictionary:
	var db: Dictionary = {}
	if not FileAccess.file_exists(file_path):
		printerr("Arquivo CSV não encontrado: ", file_path)
		return db

	var file = FileAccess.open(file_path, FileAccess.READ)
	var is_header: bool = true
	
	while not file.eof_reached():
		var line: PackedStringArray = file.get_csv_line()
		if is_header:
			is_header = false
			continue
		
		if line.size() >= 3:
			db[line[0].strip_edges()] = {"name": line[1].strip_edges(), "text": line[2].strip_edges()}
			
	return db

## Leitor do JSON
func load_json_data(file_path: String) -> Array:
	if not FileAccess.file_exists(file_path):
		printerr("Arquivo JSON não encontrado: ", file_path)
		return []

	var file = FileAccess.open(file_path, FileAccess.READ)
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK:
		return json.data
	return []

## Exibe a fala atual na tela
func display_current_line() -> void:
	stop_indicator_animation()

	var entry = current_sequence[current_index]
	var id = entry["id"]
	var portrait_path = entry.get("portrait", "")

	if not text_database.has(id):
		advance_dialogue()
		return

	name_label.text = text_database[id]["name"]
	var line_text = text_database[id]["text"]

	# Atualiza o Portrait (Sprite centralizado de corpo inteiro por trás da caixa de texto)
	if portrait_path != "" and ResourceLoader.exists(portrait_path):
		portrait.texture = load(portrait_path)
		portrait.visible = true
	else:
		portrait.visible = false

	# Animação de digitação
	text_label.text = line_text
	text_label.visible_characters = 0
	is_typing = true

	if tween:
		tween.kill()

	tween = create_tween()
	var total_time = line_text.length() * text_speed
	tween.tween_property(text_label, "visible_characters", line_text.length(), total_time)
	tween.finished.connect(_on_typing_finished)

func _on_typing_finished() -> void:
	is_typing = false
	start_indicator_animation()

func finish_typing_instantly() -> void:
	if tween:
		tween.kill()
	text_label.visible_characters = text_label.text.length()
	_on_typing_finished()

func advance_dialogue() -> void:
	current_index += 1
	if current_index < current_sequence.size():
		display_current_line()
	else:
		stop_indicator_animation()
		dialogue_control.visible = false
		portrait.visible = false # Fecha o sprite da sombra ao encerrar a conversa

func start_indicator_animation() -> void:
	if not next_indicator:
		return
		
	next_indicator.visible = true
	if indicator_tween:
		indicator_tween.kill()

	indicator_tween = create_tween().set_loops()
	indicator_tween.tween_property(next_indicator, "position:y", 5.0, 0.4).as_relative().set_trans(Tween.TRANS_SINE)
	indicator_tween.tween_property(next_indicator, "position:y", -5.0, 0.4).as_relative().set_trans(Tween.TRANS_SINE)

func stop_indicator_animation() -> void:
	if indicator_tween:
		indicator_tween.kill()
	if next_indicator:
		next_indicator.visible = false
