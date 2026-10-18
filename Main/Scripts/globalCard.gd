extends Node

# Sinais úteis para debug e para a interface futura.
signal vida_mudou(lado: int, atual: int, maximo: int)
signal escudo_mudou(lado: int, valor: int)
signal counter_mudou(lado: int, dano_refletido: int)
signal turno_mudou(numero_turno: int, lado_da_vez: int)

enum Lado { JOGADOR, INIMIGO }

const VIDA_MAXIMA: int = 20

var is_dragging_card: bool = false

# true enquanto uma rodada (jogada do jogador + jogada do inimigo + compras)
# está acontecendo. Impede o jogador de jogar outra carta no meio.
var acao_em_andamento: bool = false

# --- TURNOS ---
var numero_turno: int = 1                  # contador de turnos (1, 2, 3...)
var turno_atual: Lado = Lado.JOGADOR       # de quem é a vez agora

# --- VIDA / ESCUDO ---
var vida_jogador: int = VIDA_MAXIMA
var vida_inimigo: int = VIDA_MAXIMA
var escudo_jogador: int = 0
var escudo_inimigo: int = 0

# --- COUNTER ---
# 0 = sem counter ativo. Maior que 0 = o próximo ataque recebido é anulado
# e o atacante leva esse valor de dano.
var counter_jogador: int = 0
var counter_inimigo: int = 0


func oponente(lado: int) -> int:
	return Lado.INIMIGO if lado == Lado.JOGADOR else Lado.JOGADOR


# ---------------- AÇÕES (usadas pelos efeitos das cartas) ----------------

# Ataque: se o alvo tem counter, o ataque é anulado e o atacante leva o dano do counter.
func atacar(atacante: int, dano: int) -> void:
	var alvo: int = oponente(atacante)
	var refletido: int = counter_jogador if alvo == Lado.JOGADOR else counter_inimigo

	if refletido > 0:
		_definir_counter(alvo, 0)  # o counter é consumido
		print("[COUNTER] Ataque anulado! %s leva %d de dano." % [_nome(atacante), refletido])
		receber_dano(atacante, refletido)
		return

	receber_dano(alvo, dano)


func ganhar_escudo(lado: int, valor: int) -> void:
	var atual: int = escudo_jogador if lado == Lado.JOGADOR else escudo_inimigo
	_definir_escudo(lado, atual + valor)


func ativar_counter(lado: int, dano_refletido: int) -> void:
	_definir_counter(lado, dano_refletido)


# Chamado no fim da resposta do inimigo: se o counter não foi usado, ele some.
func expirar_counter(lado: int) -> void:
	var atual: int = counter_jogador if lado == Lado.JOGADOR else counter_inimigo
	if atual > 0:
		_definir_counter(lado, 0)
		print("[COUNTER] %s: o counter expirou sem efeito." % _nome(lado))


# Dano direto: o escudo absorve primeiro, o resto vai para a vida.
func receber_dano(lado: int, valor: int) -> void:
	var restante: int = valor
	var escudo: int = escudo_jogador if lado == Lado.JOGADOR else escudo_inimigo
	var absorvido: int = mini(escudo, restante)

	if absorvido > 0:
		_definir_escudo(lado, escudo - absorvido)
		restante -= absorvido

	if restante > 0:
		_alterar_vida(lado, -restante)


func curar(lado: int, valor: int) -> void:
	_alterar_vida(lado, valor)


# ---------------- INTERNO ----------------

func _alterar_vida(lado: int, delta: int) -> void:
	if lado == Lado.JOGADOR:
		vida_jogador = clampi(vida_jogador + delta, 0, VIDA_MAXIMA)
		vida_mudou.emit(lado, vida_jogador, VIDA_MAXIMA)
	else:
		vida_inimigo = clampi(vida_inimigo + delta, 0, VIDA_MAXIMA)
		vida_mudou.emit(lado, vida_inimigo, VIDA_MAXIMA)


func _definir_escudo(lado: int, valor: int) -> void:
	if lado == Lado.JOGADOR:
		escudo_jogador = maxi(valor, 0)
		escudo_mudou.emit(lado, escudo_jogador)
	else:
		escudo_inimigo = maxi(valor, 0)
		escudo_mudou.emit(lado, escudo_inimigo)


func _definir_counter(lado: int, valor: int) -> void:
	if lado == Lado.JOGADOR:
		counter_jogador = valor
		counter_mudou.emit(lado, counter_jogador)
	else:
		counter_inimigo = valor
		counter_mudou.emit(lado, counter_inimigo)


func _nome(lado: int) -> String:
	return "Jogador" if lado == Lado.JOGADOR else "Inimigo"


func proximo_turno() -> void:
	if turno_atual == Lado.JOGADOR:
		turno_atual = Lado.INIMIGO
	else:
		turno_atual = Lado.JOGADOR
		numero_turno += 1  # só conta um turno novo quando volta pro jogador
	turno_mudou.emit(numero_turno, turno_atual)


# Reinicia só a partida de cartas (vida, escudo, counter e turnos).
func reiniciar_partida() -> void:
	numero_turno = 1
	turno_atual = Lado.JOGADOR
	acao_em_andamento = false
	vida_jogador = VIDA_MAXIMA
	vida_inimigo = VIDA_MAXIMA
	escudo_jogador = 0
	escudo_inimigo = 0
	counter_jogador = 0
	counter_inimigo = 0
	vida_mudou.emit(Lado.JOGADOR, vida_jogador, VIDA_MAXIMA)
	vida_mudou.emit(Lado.INIMIGO, vida_inimigo, VIDA_MAXIMA)
	escudo_mudou.emit(Lado.JOGADOR, 0)
	escudo_mudou.emit(Lado.INIMIGO, 0)
	counter_mudou.emit(Lado.JOGADOR, 0)
	counter_mudou.emit(Lado.INIMIGO, 0)
	turno_mudou.emit(numero_turno, turno_atual)
