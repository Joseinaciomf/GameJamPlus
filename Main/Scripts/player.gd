extends CharacterBody2D

# --- VARIÁVEIS EXPORTADAS (Ajustáveis no Inspector) ---
@export_group("Movimento Horizontal")
## Velocidade normal de caminhada em pixels por segundo.
@export var speed: float = 200.0
## Velocidade ao correr (sprint).
@export var sprint_speed: float = 350.0
## Taxa de aceleração ao começar a andar/mudar de direção.
@export var acceleration: float = 1200.0
## Taxa de desaceleração ao soltar as teclas de movimento.
@export var friction: float = 1000.0

@export_group("Pulo e Gravidade")
## Altura/Força do pulo (valor negativo pois o eixo Y no Godot aponta para baixo).
@export var jump_velocity: float = -400.0
## Multiplicador de gravidade aplicado quando o personagem está caindo (deixa o pulo mais dinâmico).
@export var fall_gravity_multiplier: float = 1.5

# Puxa a gravidade padrão configurada nas configurações do projeto Godot
var default_gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

# Referência aos nós filhos (Ajuste a classe se usar AnimatedSprite2D)
@onready var sprite: Sprite2D = $Sprite2D

func _physics_process(delta: float) -> void:
	# 1. Aplicação da Gravidade
	apply_gravity(delta)

	# 2. Mecânica de Pulo
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity

	# 3. Movimentação Horizontal e Corrida (Sprint)
	handle_horizontal_movement(delta)

	# 4. Virar o Sprite para a direção correta
	flip_sprite()

	# 5. Aplica a movimentação e gerencia colisões com o mapa
	move_and_slide()

## Função responsável por calcular a gravidade
func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		var current_gravity = default_gravity
		# Se estiver caindo (velocidade Y positiva), aplica gravidade maior para queda mais firme
		if velocity.y > 0:
			current_gravity *= fall_gravity_multiplier
		
		velocity.y += current_gravity * delta

## Função responsável por calcular andar, correr, aceleração e desaceleração
func handle_horizontal_movement(delta: float) -> void:
	# Retorna -1 (esquerda), 1 (direita) ou 0 (parado)
	var direction: float = Input.get_axis("move_left", "move_right")
	
	# Define a velocidade alvo dependendo de estar segurando a tecla de corrida
	var target_speed: float = sprint_speed if Input.is_action_pressed("sprint") else speed

	if direction != 0:
		# Acelera progressivamente em direção à velocidade desejada
		velocity.x = move_toward(velocity.x, direction * target_speed, acceleration * delta)
	else:
		# Desacelera até parar quando nenhum botão é pressionado
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

## Inverte o sprite horizontalmente de acordo com a direção do movimento
func flip_sprite() -> void:
	if velocity.x > 0:
		sprite.flip_h = false
	elif velocity.x < 0:
		sprite.flip_h = true
