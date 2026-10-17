extends Control

# --- REFERÊNCIAS DOS NÓS ---
@onready var text_label: RichTextLabel = $MarginContainer/CenterContainer/TextLabel
@onready var skip_label: Label = $SkipLabel

# --- CONFIGURAÇÕES ---
@export var text_speed: float = 0.03 # Velocidade da digitação
## Prefixo do ID no JSON/CSV que esta cena vai carregar
@export var dialogue_prefix: String = "TRANS_N2"
## Caminho para a cena da Noite 2
@export_file("*.tscn") var next_scene_path: String = "res://Main/Scenes/room_night2.tscn"

var sequence_data: Array = []
var text_database: Dictionary = {}
var current_index: int = 0
var is_typing: bool = false
var tween: Tween

func _ready() -> void:
	skip_label.visible = false
	load_transition_data()
	
	if sequence_data.size() > 0:
		display_current_line()

func _input(event: InputEvent) -> void:
	var is_click: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	var is_space: bool = event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_select")

	if is_click or is_space:
		get_viewport().set_input_as_handled()
		
		if is_typing:
			finish_typing_instantly()
		else:
			advance_transition()

## Carrega os dados do CSV e filtra o JSON unificado pelo prefixo
func load_transition_data() -> void:
	text_database = load_csv_data("res://Assets/Dialogues/Dialogues.csv")
	var full_json = load_json_data("res://Assets/Dialogues/dialogues.json")
	
	sequence_data = []
	for entry in full_json:
		if entry["id"].begins_with(dialogue_prefix):
			sequence_data.append(entry)

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

## Exibe a linha atual de transição
func display_current_line() -> void:
	var entry = sequence_data[current_index]
	var id = entry["id"]

	if not text_database.has(id):
		advance_transition()
		return

	var raw_text = text_database[id]["text"]
	var line_text = "[center]" + raw_text + "[/center]"

	text_label.text = line_text
	text_label.visible_characters = 0
	is_typing = true
	skip_label.visible = false

	if tween:
		tween.kill()

	tween = create_tween()
	var total_time = raw_text.length() * text_speed
	tween.tween_property(text_label, "visible_characters", line_text.length(), total_time)
	tween.finished.connect(_on_typing_finished)

func _on_typing_finished() -> void:
	is_typing = false
	skip_label.visible = true

func finish_typing_instantly() -> void:
	if tween:
		tween.kill()
	text_label.visible_characters = text_label.text.length()
	_on_typing_finished()

## Avança para a próxima frase ou muda para a Noite 2
func advance_transition() -> void:
	current_index += 1
	if current_index < sequence_data.size():
		display_current_line()
	else:
		change_to_night2()

func change_to_night2() -> void:
	if ResourceLoader.exists(next_scene_path):
		get_tree().change_scene_to_file(next_scene_path)
	else:
		printerr("Cena da Noite 2 não encontrada em: ", next_scene_path)
