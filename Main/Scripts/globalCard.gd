extends Node

# Sinais úteis para debug e para a interface futura.
signal vida_mudou(lado: int, atual: int, maximo: int)
signal turno_mudou(numero_turno: int, lado_da_vez: int)

enum Lado { JOGADOR, INIMIGO }

const VIDA_MAXIMA: int = 20

var is_dragging_card: bool = false

# --- TURNOS ---
var numero_turno: int = 1                  # contador de turnos (1, 2, 3...)
var turno_atual: Lado = Lado.JOGADOR       # de quem é a vez agora

# --- VIDA ---
var vida_jogador: int = VIDA_MAXIMA
var vida_inimigo: int = VIDA_MAXIMA


func receber_dano(lado: Lado, valor: int) -> void:
	_alterar_vida(lado, -valor)


func curar(lado: Lado, valor: int) -> void:
	_alterar_vida(lado, valor)


func _alterar_vida(lado: Lado, delta: int) -> void:
	if lado == Lado.JOGADOR:
		vida_jogador = clampi(vida_jogador + delta, 0, VIDA_MAXIMA)
		vida_mudou.emit(lado, vida_jogador, VIDA_MAXIMA)
	else:
		vida_inimigo = clampi(vida_inimigo + delta, 0, VIDA_MAXIMA)
		vida_mudou.emit(lado, vida_inimigo, VIDA_MAXIMA)


func proximo_turno() -> void:
	if turno_atual == Lado.JOGADOR:
		turno_atual = Lado.INIMIGO
	else:
		turno_atual = Lado.JOGADOR
		numero_turno += 1  # só conta um turno novo quando volta pro jogador
	turno_mudou.emit(numero_turno, turno_atual)


# Reinicia só a partida de cartas (vida e turnos).
func reiniciar_partida() -> void:
	numero_turno = 1
	turno_atual = Lado.JOGADOR
	vida_jogador = VIDA_MAXIMA
	vida_inimigo = VIDA_MAXIMA
	vida_mudou.emit(Lado.JOGADOR, vida_jogador, VIDA_MAXIMA)
	vida_mudou.emit(Lado.INIMIGO, vida_inimigo, VIDA_MAXIMA)
	turno_mudou.emit(numero_turno, turno_atual)
