extends CharacterBody3D

# Constantes para corrida
const faster_run_speed = 37.0
const run_speed = 15.6
const walk_speed = 4.0

# Segundos para ativar a corrida
const trigger_run = 5
const trigger_faster_run = 10

# Variável para contar quanto tempo o jogador está correndo
var running_time = 0

# Constante para pulo
const jump_velocity = 4.5

# Constante para sensibilidade do olhar
const sensitivity = 0.005

# Velocidade do jogador atual, só é usado quando o jogo está rodando
var current_speed = 0

# Constantes para o FOV
const BASE_FOV = 80
const FOV_CHANGE = 1.3

# Constantes para a cabeça mexer ao andar
const BOB_FREQ = 2.0
const BOB_AMP = 0.08
var t_bob = 0.0

var t_target = 0

# Gravidades

# Gravidade normal, sem o jogador estar escalando ou realizando wallrun
var normal_gravity = 9.8

#
var wallrun_gravity = 6.5

# POSIÇÕES
var vault_last_pos = null
var vault_first_pos = null

# BOLEANAS
var wallrunning = false
var vaulting = false
var enable_gravity = true

# Objetos da camera e cabeça
@onready var head = $PlayerHead
@onready var camera = $PlayerHead/PlayerCamera

# Objetos para o raycast
@onready var vaultRaycast = $PlayerHead/PlayerTriggers/VaultRaycast
@onready var climbRaycast = $PlayerHead/PlayerTriggers/ClimbRaycast
@onready var vaultPositioner = $PlayerHead/VaultRaycastPositioner/VaultPositioner

func _ready():
	# Deixar o mouse travado ao iniciar o jogo
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event):
	
	# Se o evento que acontecer for um movimento de mouse
	if event is InputEventMouseMotion:
		
		# Rotacionar cabeça e camera
		head.rotate_y(-event.relative.x * sensitivity)
		camera.rotate_x(-event.relative.y * sensitivity)
		
		# Limitar a camera para um valor minimo ou máximo
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90), deg_to_rad(60))

func _calculate_auto_running(delta):
	# Iniciar corrida automática
	# O jogador correrá automaticamente após andar por alguns segundos
	# Primeiro, verificar se o jogador está pressionando para frente e não parou
	if Input.is_action_pressed("forward") and velocity.x:
		
		# Aumentar o tempo que o jogador está andando/correndo
		running_time += delta # delta conta em segundos
		
	# Se não isso significa que o jogador parou de correr
	else:
		
		# Retornar o running time para 0
		running_time = 0
	
	#print(running_time)

func _apply_gravity(delta):
	# Se não estiver no chão
	if not is_on_floor() and enable_gravity:
		# Se o jogador NÃO estiver em wallrun
		if not wallrunning:
			# Adiconar gravidade normalmente
			velocity.y -= normal_gravity * delta
		else:
			# Adicionar gravidade de wallrun
			velocity.y -= wallrun_gravity * delta

func _auto_running():
	# Verificar se o tempo de correr passou dos triggers
	if (running_time > trigger_faster_run):
		current_speed = faster_run_speed
		
	elif (running_time > trigger_run):
		current_speed = run_speed
		
	else:
		current_speed = walk_speed

func _dash_input():
	
	# Caso jogador pressione dash e tempo de corrida for menor que o trigger de corrida
	var dash_input = Input.is_action_just_pressed("dash")
	if dash_input and running_time < trigger_run and is_on_floor():
		# Quando o jogador apertar, o running time
		# Irá direto para o trigger de correr, fa-
		# zendo o jogador correr instantaneamente
		running_time = trigger_run

func _headbob(time):
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP
	return pos

func _change_fov(delta):
	# Limitar o valor de velocidade para realizar o calculo
	var velocity_clamp = clamp(velocity.length(), 0.5, faster_run_speed * 3)
	
	# Calcular o FOV a ser colocado
	var target_fov = BASE_FOV + FOV_CHANGE * velocity_clamp
	
	# Suavizar a mudança do FOV com o lerp
	camera.fov = lerp(camera.fov, target_fov, delta * 8.0)

func _player_move(delta, direction):
	
	# Movimentos de parkour acontecem em prioridade, caso o jogador não esteja
	# em nenhum movimento de parkour, será feito o movimento normal
	## MOVIMENTOS DE PARKOUR
	# Se o jogador estiver em vault
	if (vaulting):
		
		# Caso a posição do vault seja nulo
		if vault_last_pos == null:
			# Parar o vault
			vaulting = false
			return
		
		# Movimentar suavemente
		print("VAULTING")
		
		# TODO - resolver
		t_target += 1 * delta
		global_position = lerp(vault_first_pos, vault_last_pos, t_target)
		$PlayerCollider.disabled = true
		enable_gravity = false
		
		if (position == vault_last_pos):
			enable_gravity = true
			$PlayerCollider.disabled = false
			vaulting = false
		
		
		# Terminar a função antes, para evitar o jogador de andar enquanto realiza o vault
		return
	
	## MOVIMENTOS NORMAIS
	# Se jogador estiver no chão
	if is_on_floor():
		
		# Caso o jogador esteja se movendo
		if direction:
			
			# Ajustar a velocidade do jogador para a velocidade 
			velocity.x = direction.x * current_speed
			velocity.z = direction.z * current_speed
		else:
			# Caso o contrário, o jogador terá a velocidade zerada
			velocity.x = 0
			velocity.z = 0
	
	else:
		# Se o jogador estiver no ar, o movimento vai ter mais inercia
		velocity.x = lerp(velocity.x, direction.x * current_speed, delta * 1.5)
		velocity.z = lerp(velocity.z, direction.z * current_speed, delta * 1.5)


func _up_movement_input():
	# Caso o pressione o botão de ações pra cima
	if Input.is_action_just_pressed("up_movement"):
		
		# Verificar raycasts
		var vault = vaultRaycast._get_raycast_collision()
		var climb = climbRaycast._get_raycast_collision()
		
		# Se o player estiver no chão
		var floor = is_on_floor()
		
		# Algumas ações para cima só serão ativadas quando o jogador estiver
		# Pressionando up_movement enquanto anda para frente, esse método evita
		# movimentos não desejados.
		var forward = Input.is_action_pressed("forward")
		
		# Fazer verificações
		
		# Se estiver no chão
		if (floor):
			
			# Se estiver andando para frente
			if (forward):
				
				# Para realizar vault
				if (vault and not climb):
					
					# Iniciar vault
					vaulting = true
					
					# Definir uma posição que o jogador terminará o vault
					vault_last_pos = vaultPositioner._get_new_vault_pos()
					vault_first_pos = position
					
					# Evitar que um pulo normal seja dado
					return
		
		# TODO
		if (vault):
			print("VAULT")
		
		if (climb):
			print("CLIMB")
		
		# Iniciar um pulo normal, caso nenhuma outra condição seja satisfeita 
		# anteriormente, como wallrun, climb e vault, aumentando a velocidade de Y
		velocity.y = jump_velocity

func _physics_process(delta):
	
	# Aplicar gravidade ao jogador
	_apply_gravity(delta)

	# Verificar se o jogador pressionou o botão de movimentos para cima
	_up_movement_input()

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir = Input.get_vector("left", "right", "forward", "backward")
	var direction = (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# Calcular a corrida automatica
	_calculate_auto_running(delta)
	
	# Após calcular, aplicar a corrida automática
	_auto_running()
	
	# Aplicar o dash
	_dash_input()
	
	# Calcular o movimento
	_player_move(delta, direction)
	
	# Head bob
	t_bob += delta * velocity.length() * float(is_on_floor())
	camera.transform.origin = _headbob(t_bob)
	
	# FOV
	_change_fov(delta)
	
	move_and_slide()
