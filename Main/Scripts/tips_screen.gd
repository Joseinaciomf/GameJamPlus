extends Control

# Sinal emitido quando o painel de dicas é aberto ou fechado
signal tips_toggled(is_open: bool)

@onready var center_container: CenterContainer = $CenterContainer
@onready var btn_entendi: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BtnEntendi
@onready var btn_abrir_dicas: TextureButton = $BtnAbrirDicas

# Começa como falso para o painel vir fechado por padrão
var is_panel_open: bool = false

func _ready() -> void:
	if btn_entendi:
		btn_entendi.pressed.connect(_on_btn_entendi_pressed)
	
	if btn_abrir_dicas:
		btn_abrir_dicas.pressed.connect(_on_btn_abrir_dicas_pressed)
	
	# Estado inicial: Esconde o painel de dicas e deixa o botão "?" visível
	if center_container:
		center_container.visible = false
	if btn_abrir_dicas:
		btn_abrir_dicas.visible = true
		
	# Garante que os cliques no quarto estejam liberados desde o início
	tips_toggled.emit(false)

func _on_btn_entendi_pressed() -> void:
	close_tips_panel()

func _on_btn_abrir_dicas_pressed() -> void:
	if is_panel_open:
		close_tips_panel()
	else:
		open_tips_panel()

func open_tips_panel() -> void:
	is_panel_open = true
	center_container.visible = true
	btn_abrir_dicas.visible = false
	tips_toggled.emit(true) # Bloqueia cliques nos objetos do quarto enquanto lê as dicas

func close_tips_panel() -> void:
	is_panel_open = false
	center_container.visible = false
	btn_abrir_dicas.visible = true # Mostra o botão "?" no canto
	tips_toggled.emit(false) # Libera cliques nos objetos do quarto
