extends CanvasLayer

# --- REFERÊNCIAS DOS NÓS ---
@onready var name_label: RichTextLabel = $DialogueControl/NameBox/MarginContainer/NameLabel
@onready var text_label: RichTextLabel = $DialogueControl/MainBox/MarginContainer/HBoxContainer/TextLabel
@onready var portrait: TextureRect = $Portrait
@onready var dialogue_control: Control = $DialogueControl
@onready var next_indicator: Label = $DialogueControl/MainBox/NextIndicator

# --- ÁUDIO DE AVANÇO DO DIÁLOGO ---
const DIALOGUE_NEXT_SOUND: AudioStream = preload("res://Sons/SoundSelectButton.wav")
@export_range(-40.0, 6.0, 1.0) var dialogue_sound_volume_db: float = -12.0
var _dialogue_sound_player: AudioStreamPlayer

# --- VARIÁVEIS DE CONFIGURAÇÃO ---
@export var text_speed: float = 0.03

var current_sequence: Array = []
var text_database: Dictionary = {}
var current_index: int = 0
var is_typing: bool = false
var tween: Tween
var indicator_tween: Tween

func _ready() -> void:
	_dialogue_sound_player = AudioStreamPlayer.new()
	_dialogue_sound_player.name = "DialogueNextSFX"
	_dialogue_sound_player.stream = DIALOGUE_NEXT_SOUND
	_dialogue_sound_player.volume_db = dialogue_sound_volume_db
	add_child(_dialogue_sound_player)

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
			_dialogue_sound_player.play()
			advance_dialogue()

# Inicializa um diálogo filtrando os IDs pelo prefixo
func start_dialogue_filtered(prefix: String, csv_path: String) -> void:
	text_database = load_csv_data(csv_path)
	var full_sequence: Array = load_json_data("res://Assets/Dialogues/dialogues.json")

	current_sequence = []
	for entry in full_sequence:
		if entry is Dictionary and str(entry.get("id", "")).begins_with(prefix):
			current_sequence.append(entry)

	current_index = 0
	if not current_sequence.is_empty():
		dialogue_control.visible = true
		display_current_line()
	else:
		printerr("Nenhum diálogo encontrado com o prefixo: ", prefix)

# Leitor do CSV
func load_csv_data(file_path: String) -> Dictionary:
	var db: Dictionary = {}
	if not FileAccess.file_exists(file_path):
		printerr("Arquivo CSV não encontrado: ", file_path)
		return db

	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		printerr("Não foi possível abrir CSV: ", file_path)
		return db

	var is_header: bool = true
	while not file.eof_reached():
		var line: PackedStringArray = file.get_csv_line()
		if is_header:
			is_header = false
			continue
		if line.size() >= 3:
			var id: String = line[0].strip_edges()
			var character_name: String = line[1].strip_edges()
			var content: String = line[2].strip_edges()
			db[id] = {"name": character_name, "text": content}
	return db

# Leitor do JSON
func load_json_data(file_path: String) -> Array:
	if not FileAccess.file_exists(file_path):
		printerr("Arquivo JSON não encontrado: ", file_path)
		return []

	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		printerr("Não foi possível abrir JSON: ", file_path)
		return []

	var json: JSON = JSON.new()
	var error: Error = json.parse(file.get_as_text())
	if error != OK:
		printerr("Erro ao ler JSON: ", json.get_error_message())
		return []
	if json.data is Array:
		return json.data
	printerr("O arquivo JSON precisa conter uma lista de diálogos: ", file_path)
	return []

# Exibe a fala atual na tela
func display_current_line() -> void:
	stop_indicator_animation()

	if current_index >= current_sequence.size():
		advance_dialogue()
		return

	var entry: Dictionary = current_sequence[current_index]
	var id: String = str(entry.get("id", ""))
	var portrait_path: String = str(entry.get("portrait", ""))

	if not text_database.has(id):
		printerr("ID não encontrado no CSV: ", id)
		advance_dialogue()
		return

	var name_text: String = str(text_database[id]["name"])
	var line_text: String = str(text_database[id]["text"])
	name_label.text = name_text

	# Mantém o retrato independente da caixa, conforme a versão da main.
	if portrait_path != "" and ResourceLoader.exists(portrait_path):
		portrait.texture = load(portrait_path)
		portrait.visible = true
	else:
		portrait.visible = false

	text_label.text = line_text
	text_label.visible_characters = 0
	is_typing = true

	if tween:
		tween.kill()

	tween = create_tween()
	var total_time: float = line_text.length() * text_speed
	tween.tween_property(text_label, "visible_characters", line_text.length(), total_time)
	tween.finished.connect(_on_typing_finished)

func _on_typing_finished() -> void:
	is_typing = false
	start_indicator_animation()

func finish_typing_instantly() -> void:
	if tween:
		tween.kill()
	text_label.visible_characters = text_label.get_total_character_count()
	_on_typing_finished()

func advance_dialogue() -> void:
	current_index += 1
	if current_index < current_sequence.size():
		display_current_line()
	else:
		stop_indicator_animation()
		dialogue_control.visible = false
		portrait.visible = false

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
