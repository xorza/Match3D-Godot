extends Node3D

# This script handles the game logic for a match-3 game.

@export_file("*.txt") var board_txt: String

@export var gems: Array[PackedScene] = []
@export var collision_body: PackedScene = null

var board: Array = []
var board_root: Node3D = null


func _ready() -> void:
	load_board_from_txt()
	instantiate_gems()
	
	pass
	
func load_board_from_txt() -> void:
	var file = FileAccess.open(board_txt, FileAccess.READ)
	if file == null:
		print("Failed to open file")
		return

	while not file.eof_reached():
		var line = file.get_line()
		var board_line: Array = []
		for i in range(line.length()):
			var c = line[i]
			if c == "X" or c == "x":
				board_line.append(0)
			else:
				board_line.append(int(c))

		board.append(board_line)

	file.close()

func instantiate_gems() -> void:
	board_root = Node3D.new()
	board_root.name = "Board"
	add_child(board_root)

	var board_width = 0
	var board_height = board.size()
	for i in range(board_height):
		for j in range(board[i].size()):
			if board[i].size() > board_width:
				board_width = board[i].size()

			var gem_id = board[i][j]
			if gem_id == 0:
				continue

			var gem = gems[gem_id].instantiate()
			gem.name = "Gem_" + str(i) + "_" + str(j)
			gem.set_meta("gem_pos", Vector2i(i, j))
			board_root.add_child(gem)
			set_gem_position(gem, Vector2i(i, j))

			var collision_body_instance = collision_body.instantiate()
			collision_body_instance.name = "CollisionBody_" + str(i) + "_" + str(j)
			collision_body_instance.set_meta("gem_pos", Vector2i(i, j))
			board_root.add_child(collision_body_instance)
			set_gem_position(collision_body_instance, Vector2i(i, j))

	$CameraHandle.position = Vector3((board_height - 1) / 2.0, 0, (board_width - 1) / 2.0)

func set_gem_position(gem: Node3D, new_pos: Vector2i) -> void:
	var board_height = board.size()
	gem.position = Vector3(board_height - new_pos.x, 0, new_pos.y)


enum InputState {IDLE, PICKED_1}
var input_state: InputState = InputState.IDLE
var first_gem_picked: Node3D
var second_gem_picked: Node3D

func _input(event):
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed and input_state == InputState.IDLE:
		process_input_pressed(event.position)
		return

	if (event is InputEventMouseButton or event is InputEventScreenTouch) and !event.pressed and input_state == InputState.PICKED_1:
		process_input_released(event.position)

	if (event is InputEventMouseMotion or event is InputEventScreenDrag) and input_state == InputState.PICKED_1:
		process_input_dragged(event.position)

	
	pass

func raypick(input_position: Vector2) -> StaticBody3D:
	var camera = get_viewport().get_camera_3d()
	if camera == null:
		print("Camera not found")
		return

	var from = camera.project_ray_origin(input_position)
	var to = from + camera.project_ray_normal(input_position) * 1000

	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)

	var result = space_state.intersect_ray(query)
	if result:
		if result.collider.has_meta("gem_pos"):
			return result.collider
		else:
			return null
	else:
		return null

func find_gem_by_pos(pos: Vector2i) -> Node3D:
	var gem_name = "Gem_" + str(pos.x) + "_" + str(pos.y)
	var gem = board_root.get_node(gem_name)
	return gem

func process_input_pressed(input_position: Vector2) -> void:
	var ray_pick_result = raypick(input_position)
	if ray_pick_result:
		var gem_pos = ray_pick_result.get_meta("gem_pos")
		first_gem_picked = find_gem_by_pos(gem_pos)
		input_state = InputState.PICKED_1
		return
	else:
		input_state = InputState.IDLE
		return

func process_input_dragged(input_position: Vector2) -> void:
	var ray_pick_result = raypick(input_position)
	if !ray_pick_result:
		return

	var gem_pos = ray_pick_result.get_meta("gem_pos")
	var gem = find_gem_by_pos(gem_pos)

	if first_gem_picked == gem or second_gem_picked == gem:
		return

	if second_gem_picked:
		set_gem_position(gem, gem.get_meta("gem_pos"))
	second_gem_picked = gem
		
	var temp_pos = first_gem_picked.position
	first_gem_picked.position = second_gem_picked.position
	second_gem_picked.position = temp_pos

	pass

func process_input_released(input_position: Vector2) -> void:
	input_state = InputState.IDLE
	first_gem_picked = null
	second_gem_picked = null
	pass
