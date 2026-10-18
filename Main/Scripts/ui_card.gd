extends Control

# Formato dos textos (mude aqui se quiser outro visual).
# Vida recebe (atual, máximo). Escudo recebe só o número.
const FORMATO_VIDA: String = "%d / %d"
const FORMATO_ESCUDO: String = "%d"

# RichTextLabels da cena de UI (achados pelo nome, em qualquer lugar da árvore).
var _vida_jogador: RichTextLabel
var _escudo_jogador: RichTextLabel
var _vida_inimigo: RichTextLabel
var _escudo_inimigo: RichTextLabel


func _ready() -> void:
	_vida_jogador = _achar_label("VidaPlayer")
	_escudo_jogador = _achar_label("EscudoPlayerNum")
	_vida_inimigo = _achar_label("VidaInimigo")
	_escudo_inimigo = _achar_label("EscudoInimigoNum")

	# Atualiza sozinho sempre que o GlobalCard mudar um valor.
	GlobalCard.vida_mudou.connect(_on_vida_mudou)
	GlobalCard.escudo_mudou.connect(_on_escudo_mudou)

	# Mostra os valores atuais logo ao carregar a UI.
	_on_vida_mudou(GlobalCard.Lado.JOGADOR, GlobalCard.vida_jogador, GlobalCard.VIDA_MAXIMA)
	_on_vida_mudou(GlobalCard.Lado.INIMIGO, GlobalCard.vida_inimigo, GlobalCard.VIDA_MAXIMA)
	_on_escudo_mudou(GlobalCard.Lado.JOGADOR, GlobalCard.escudo_jogador)
	_on_escudo_mudou(GlobalCard.Lado.INIMIGO, GlobalCard.escudo_inimigo)


func _achar_label(nome: String) -> RichTextLabel:
	var label: RichTextLabel = find_child(nome, true, false) as RichTextLabel
	if label == null:
		push_warning("ui_card: RichTextLabel '%s' não encontrado na cena de UI." % nome)
	return label


func _on_vida_mudou(lado: int, atual: int, maximo: int) -> void:
	var label: RichTextLabel = _vida_jogador if lado == GlobalCard.Lado.JOGADOR else _vida_inimigo
	if label != null:
		label.text = FORMATO_VIDA % [atual, maximo]


func _on_escudo_mudou(lado: int, valor: int) -> void:
	var label: RichTextLabel = _escudo_jogador if lado == GlobalCard.Lado.JOGADOR else _escudo_inimigo
	if label != null:
		label.text = FORMATO_ESCUDO % valor
