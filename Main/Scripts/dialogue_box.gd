extends CanvasLayer

@onready var name_label: RichTextLabel = $DialogueControl/NameBox/MarginContainer/NameLabel
@onready var text_label: RichTextLabel = $DialogueControl/MainBox/MarginContainer/HBoxContainer/TextLabel
@onready var dialogue_control: Control = $DialogueControl
@onready var portrait: TextureRect = get_node_or_null("Portrait") as TextureRect
@onready var next_indicator: Label = find_child("NextIndicator", true, false) as Label

const DIALOGUE_NEXT_SOUND: AudioStream = preload("res://Sons/SoundSelectButton.wav")
@export_range(-40.0, 6.0, 1.0) var dialogue_sound_volume_db: float = -12.0
@export var text_speed: float = 0.03
@export var dialogue_layer: int = 20

var current_sequence: Array = []
var text_database: Dictionary = {}
var current_index: int = 0
var is_typing: bool = false
var tween: Tween
var indicator_tween: Tween
var _dialogue_sound_player: AudioStreamPlayer

func _ready() -> void:
	layer = dialogue_layer
	visible = true  # CanvasLayer também precisa estar visível.
	_dialogue_sound_player = AudioStreamPlayer.new()
	_dialogue_sound_player.name = "DialogueNextSFX"
	_dialogue_sound_player.stream = DIALOGUE_NEXT_SOUND
	_dialogue_sound_player.volume_db = dialogue_sound_volume_db
	add_child(_dialogue_sound_player)
	dialogue_control.hide()
	if portrait:
		portrait.hide()
	if next_indicator:
		next_indicator.hide()

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

func start_dialogue_filtered(prefix: String, csv_path: String) -> void:
	stop_indicator_animation()
	if tween and tween.is_running():
		tween.kill()
	is_typing = false
	text_database = load_csv_data(csv_path)
	var full_sequence: Array = load_json_data("res://Assets/Dialogues/dialogues.json")
	current_sequence.clear()
	for entry in full_sequence:
		if entry is Dictionary and str(entry.get("id", "")).begins_with(prefix):
			current_sequence.append(entry)
	current_index = 0
	print("[DIALOGO] Prefixo=", prefix, " | entradas JSON=", current_sequence.size(), " | entradas CSV=", text_database.size())
	if current_sequence.is_empty():
		push_warning("Nenhum diálogo encontrado: " + prefix)
		finish_dialogue()
		return
	# Se a primeira fala não existir, avança para a primeira válida.
	if not _seek_valid_line():
		push_error("Nenhum ID do diálogo '" + prefix + "' está presente no CSV.")
		finish_dialogue()
		return
	visible = true
	dialogue_control.show()
	dialogue_control.modulate.a = 1.0
	print("[DIALOGO] Caixa exibida. DialogueControl visible=", dialogue_control.is_visible_in_tree(), " layer=", layer)
	display_current_line()

func _seek_valid_line() -> bool:
	while current_index < current_sequence.size():
		var id: String = str(current_sequence[current_index].get("id", ""))
		if text_database.has(id):
			return true
		push_warning("ID não encontrado no CSV: " + id)
		current_index += 1
	return false

func load_csv_data(file_path: String) -> Dictionary:
	var db: Dictionary = {}
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("Não foi possível abrir CSV: " + file_path)
		return db
	var is_header: bool = true
	while not file.eof_reached():
		var columns: PackedStringArray = file.get_csv_line()
		if is_header:
			is_header = false
			continue
		if columns.size() >= 3:
			var id: String = columns[0].strip_edges().trim_prefix("\ufeff")
			if id.is_empty():
				continue
			db[id] = {"name": columns[1].strip_edges(), "text": columns[2].strip_edges()}
	return db

func load_json_data(file_path: String) -> Array:
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("Não foi possível abrir JSON: " + file_path)
		return []
	var json: JSON = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("Erro ao ler JSON: " + json.get_error_message())
		return []
	if json.data is Array:
		return json.data
	push_error("JSON precisa conter uma lista: " + file_path)
	return []

func display_current_line() -> void:
	stop_indicator_animation()
	if not _seek_valid_line():
		finish_dialogue()
		return
	var entry: Dictionary = current_sequence[current_index]
	var id: String = str(entry.get("id", ""))
	var portrait_path: String = str(entry.get("portrait", ""))
	name_label.text = str(text_database[id]["name"])
	var line_text: String = str(text_database[id]["text"])
	if portrait:
		if not portrait_path.is_empty() and ResourceLoader.exists(portrait_path):
			portrait.texture = load(portrait_path)
			portrait.show()
		else:
			portrait.hide()
	text_label.text = line_text
	text_label.visible_characters = 0
	is_typing = true
	if tween:
		tween.kill()
	tween = create_tween()
	var total_time: float = maxf(0.01, text_label.get_total_character_count() * text_speed)
	tween.tween_property(text_label, "visible_characters", text_label.get_total_character_count(), total_time)
	tween.finished.connect(_on_typing_finished)
	print("[DIALOGO] Mostrando ID=", id, " | caixa visível=", dialogue_control.is_visible_in_tree())

func _on_typing_finished() -> void:
	is_typing = false
	start_indicator_animation()

func finish_typing_instantly() -> void:
	if tween:
		tween.kill()
	text_label.visible_characters = -1
	_on_typing_finished()

func advance_dialogue() -> void:
	current_index += 1
	if current_index < current_sequence.size():
		display_current_line()
	else:
		finish_dialogue()

func finish_dialogue() -> void:
	stop_indicator_animation()
	if tween and tween.is_running():
		tween.kill()
	is_typing = false
	dialogue_control.hide()
	if portrait:
		portrait.hide()

func start_indicator_animation() -> void:
	if not next_indicator:
		return
	next_indicator.show()
	if indicator_tween:
		indicator_tween.kill()
	indicator_tween = create_tween().set_loops()
	indicator_tween.tween_property(next_indicator, "position:y", 5.0, 0.4).as_relative().set_trans(Tween.TRANS_SINE)
	indicator_tween.tween_property(next_indicator, "position:y", -5.0, 0.4).as_relative().set_trans(Tween.TRANS_SINE)

func stop_indicator_animation() -> void:
	if indicator_tween:
		indicator_tween.kill()
	if next_indicator:
		next_indicator.hide()
