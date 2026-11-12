extends Node3D

var speed: float = 25.0
var max_speed: float = 65.0
var steer_angle: float = 0.0
var score: int = 0
var is_game_over: bool = false
var use_tilt: bool = true

var player_car: MeshInstance3D
var camera: Camera3D
var enemies: Array[MeshInstance3D] = []
var road_lines: Array[MeshInstance3D] = []
var spawn_timer: float = 0.0

var score_label: Label
var mode_btn: Button
var game_over_panel: Control
var steering_wheel: ColorRect

func _ready() -> void:
	setup_environment()
	setup_player()
	setup_ui()

func setup_environment() -> void:
	var env = WorldEnvironment.new()
	var environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.08, 0.12, 0.2)
	env.environment = environment
	add_child(env)

	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 30, 0)
	add_child(light)

	var road = MeshInstance3D.new()
	var road_mesh = BoxMesh.new()
	road_mesh.size = Vector3(14, 0.2, 400)
	var road_mat = StandardMaterial3D.new()
	road_mat.albedo_color = Color(0.15, 0.15, 0.18)
	road.mesh = road_mesh
	road.material_override = road_mat
	road.position = Vector3(0, -0.1, -150)
	add_child(road)

	for i in range(20):
		var line = MeshInstance3D.new()
		var line_mesh = BoxMesh.new()
		line_mesh.size = Vector3(0.3, 0.25, 4)
		line.mesh = line_mesh
		line.position = Vector3(0, 0, -i * 15)
		add_child(line)
		road_lines.append(line)

func setup_player() -> void:
	player_car = MeshInstance3D.new()
	var body_mesh = BoxMesh.new()
	body_mesh.size = Vector3(1.8, 0.7, 3.8)
	var body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.0, 0.75, 1.0)
	player_car.mesh = body_mesh
	player_car.material_override = body_mat
	player_car.position = Vector3(0, 0.4, 0)
	add_child(player_car)

	camera = Camera3D.new()
	camera.position = Vector3(0, 3.5, 7.5)
	camera.rotation_degrees = Vector3(-18, 0, 0)
	add_child(camera)

func setup_ui() -> void:
	var canvas = CanvasLayer.new()
	add_child(canvas)

	score_label = Label.new()
	score_label.position = Vector2(30, 20)
	score_label.add_theme_font_size_override("font_size", 36)
	canvas.add_child(score_label)

	mode_btn = Button.new()
	mode_btn.text = "Control: TILT (Tap to Switch)"
	mode_btn.position = Vector2(30, 80)
	mode_btn.size = Vector2(320, 60)
	mode_btn.pressed.connect(_on_mode_toggle)
	canvas.add_child(mode_btn)

	steering_wheel = ColorRect.new()
	steering_wheel.color = Color(1, 1, 1, 0.35)
	steering_wheel.size = Vector2(200, 200)
	steering_wheel.position = Vector2(60, 460)
	steering_wheel.visible = false
	canvas.add_child(steering_wheel)

	game_over_panel = Control.new()
	game_over_panel.visible = false
	canvas.add_child(game_over_panel)

	var restart_btn = Button.new()
	restart_btn.text = "CRASHED! TAP TO RESTART"
	restart_btn.position = Vector2(440, 300)
	restart_btn.size = Vector2(400, 100)
	restart_btn.pressed.connect(_restart_game)
	game_over_panel.add_child(restart_btn)

func _on_mode_toggle() -> void:
	use_tilt = !use_tilt
	steering_wheel.visible = !use_tilt
	steer_angle = 0.0
	mode_btn.text = "Control: TILT (Tap to Switch)" if use_tilt else "Control: STEERING (Tap to Switch)"

func _input(event: InputEvent) -> void:
	if not use_tilt:
		if event is InputEventScreenTouch or event is InputEventScreenDrag:
			var wheel_center = steering_wheel.position + steering_wheel.size / 2
			if event.position.distance_to(wheel_center) < 180:
				steer_angle = clamp((event.position.x - wheel_center.x) / 80.0, -1.0, 1.0)
			if event is InputEventScreenTouch and not event.pressed:
				steer_angle = 0.0

func _process(delta: float) -> void:
	if is_game_over:
		return

	speed = min(speed + delta * 1.5, max_speed)
	score += int(speed * delta)
	score_label.text = "SCORE: " + str(score) + " | SPEED: " + str(int(speed * 3)) + " KM/H"

	if use_tilt:
		var accel = Input.get_accelerometer()
		steer_angle = clamp(accel.x / 4.0, -1.0, 1.0)
		if Input.is_action_pressed("ui_left"): steer_angle = -1.0
		elif Input.is_action_pressed("ui_right"): steer_angle = 1.0

	player_car.position.x = clamp(player_car.position.x + steer_angle * 18.0 * delta, -5.5, 5.5)
	player_car.rotation_degrees.y = -steer_angle * 15.0
	camera.position.x = lerp(camera.position.x, player_car.position.x * 0.6, delta * 5.0)

	for line in road_lines:
		line.position.z += speed * delta
		if line.position.z > 10:
			line.position.z -= 300

	spawn_timer += delta
	if spawn_timer > max(0.6, 2.0 - (speed / 45.0)):
		spawn_timer = 0.0
		spawn_enemy()

	for i in range(enemies.size() - 1, -1, -1):
		var enemy = enemies[i]
		enemy.position.z += (speed * 0.7) * delta

		if abs(enemy.position.z - player_car.position.z) < 3.4 and abs(enemy.position.x - player_car.position.x) < 1.6:
			is_game_over = true
			game_over_panel.visible = true

		if enemy.position.z > 15:
			enemy.queue_free()
			enemies.remove_at(i)

func spawn_enemy() -> void:
	var enemy = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = Vector3(1.8, 0.8, 3.8)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.2, 0.2)
	enemy.mesh = mesh
	enemy.material_override = mat
	var lanes = [-4.0, 0.0, 4.0]
	enemy.position = Vector3(lanes[randi() % lanes.size()], 0.4, -140)
	add_child(enemy)
	enemies.append(enemy)

func _restart_game() -> void:
	for enemy in enemies:
		enemy.queue_free()
	enemies.clear()
	score = 0

	speed = 25.0
	player_car.position.x = 0
	is_game_over = false
	game_over_panel.visible = false
