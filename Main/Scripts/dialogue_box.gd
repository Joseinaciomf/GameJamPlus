extends CanvasLayer

# --- REFERÊNCIAS DOS NÓS ---
@onready var name_label: Label = $DialogueControl/NameBox/MarginContainer/NameLabel
@onready var text_label: RichTextLabel = $DialogueControl/MainBox/MarginContainer/HBoxContainer/TextLabel
@onready var portrait: TextureRect = $DialogueControl/MainBox/MarginContainer/HBoxContainer/Portrait
@onready var dialogue_control: Control = $DialogueControl

# --- VARIÁVEIS DE CONFIGURAÇÃO ---
@export var text_speed: float = 0.03 # Velocidade da digitação do texto (em segundos por caractere)

var current_sequence: Array = []
var text_database: Dictionary = {}
var current_index: int = 0
var is_typing: bool = false
var tween: Tween

func _ready() -> void:
	# Oculta a caixa de diálogo por padrão
	dialogue_control.visible = false

func _input(event: InputEvent) -> void:
	if not dialogue_control.visible:
		return

	# Avança o diálogo com a tecla de confirmação (Ex: Espaço, E, Enter ou Clique do Mouse)
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("click"):
		if is_typing:
			# Se ainda está digitando, completa o texto instantaneamente
			finish_typing_instantly()
		else:
			# Se já terminou de digitar, passa para a próxima fala
			advance_dialogue()

## Inicializa um diálogo carregando o CSV e a sequência do JSON
func start_dialogue(json_path: String, csv_path: String) -> void:
	text_database = load_csv_data(csv_path)
	current_sequence = load_json_data(json_path)
	current_index = 0
	
	if current_sequence.size() > 0:
		dialogue_control.visible = true
		display_current_line()

## Leitor nativo do arquivo CSV
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
			var id = line[0].strip_edges()
			var name = line[1].strip_edges()
			var text = line[2].strip_edges()
			db[id] = {"name": name, "text": text}
			
	return db

## Leitor nativo do arquivo JSON
func load_json_data(file_path: String) -> Array:
	if not FileAccess.file_exists(file_path):
		printerr("Arquivo JSON não encontrado: ", file_path)
		return []

	var file = FileAccess.open(file_path, FileAccess.READ)
	var json_string = file.get_as_text()
	var json = JSON.new()
	var error = json.parse(json_string)
	
	if error == OK:
		return json.data
	else:
		printerr("Erro ao ler JSON: ", json.get_error_message())
		return []

## Exibe a fala atual na tela
func display_current_line() -> void:
	var entry = current_sequence[current_index]
	var id = entry["id"]
	var portrait_path = entry.get("portrait", "")

	if not text_database.has(id):
		printerr("ID não encontrado no CSV: ", id)
		advance_dialogue()
		return

	var name_text = text_database[id]["name"]
	var line_text = text_database[id]["text"]

	# Atualiza o Nome
	name_label.text = name_text
	
	# Atualiza a Foto/Portrait
	if portrait_path != "" and ResourceLoader.exists(portrait_path):
		portrait.texture = load(portrait_path)
		portrait.visible = true
	else:
		portrait.visible = false # Oculta a caixa da imagem caso não haja portrait para essa fala

	# Animação do Texto estilo "Máquina de Escrever"
	text_label.text = line_text
	text_label.visible_characters = 0
	is_typing = true

	if tween:
		tween.kill()

	tween = create_tween()
	var total_time = line_text.length() * text_speed
	tween.tween_property(text_label, "visible_characters", line_text.length(), total_time)
	tween.finished.connect(func(): is_typing = false)

## Completa a linha atual sem esperar a animação
func finish_typing_instantly() -> void:
	if tween:
		tween.kill()
	text_label.visible_characters = text_label.text.length()
	is_typing = false

## Avança para a próxima fala ou fecha a caixa
func advance_dialogue() -> void:
	current_index += 1
	if current_index < current_sequence.size():
		display_current_line()
	else:
		dialogue_control.visible = false # Fim do diálogo
