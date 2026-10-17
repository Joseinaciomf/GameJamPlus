extends Control

# Referência à caixa de diálogo instanciada na cena
@onready var dialogue_box = $DialogueBox

# Referências aos botões/hotspots do quarto (Com 'S' maiúsculo combinando com a cena)
@onready var btn_janela: Button = $HotSpots/ObjetoJanela
@onready var btn_cama: Button = $HotSpots/ObjetoCama
@onready var btn_contrato: Button = $HotSpots/ObjetoContrato

func _ready() -> void:
	# Conecta os sinais com verificação de segurança
	if btn_janela:
		btn_janela.pressed.connect(_on_click_janela)
	else:
		printerr("Erro: Botão ObjetoJanela não foi encontrado em $HotSpots")

	if btn_cama:
		btn_cama.pressed.connect(_on_click_cama)
	else:
		printerr("Erro: Botão ObjetoCama não foi encontrado em $HotSpots")

	if btn_contrato:
		btn_contrato.pressed.connect(_on_click_contrato)
	else:
		printerr("Erro: Botão ObjetoContrato não foi encontrado em $HotSpots")

func _on_click_janela() -> void:
	print("Clicou na janela")
	if dialogue_box:
		dialogue_box.start_dialogue("res://Assets/Dialogues/dialogues.json", "res://Assets/Dialogues/Dialogues.csv")

func _on_click_cama() -> void:
	print("Clicou na cama")
	if dialogue_box:
		dialogue_box.start_dialogue("res://Assets/Dialogues/dialogues.json", "res://Assets/Dialogues/Dialogues.csv")

func _on_click_contrato() -> void:
	print("Clicou no contrato")
	if dialogue_box:
		dialogue_box.start_dialogue("res://Assets/Dialogues/dialogues.json", "res://Assets/Dialogues/Dialogues.csv")
