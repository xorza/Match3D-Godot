extends Node3D


@export_file("*.txt") var board_txt: String

@export var gems: Array[PackedScene] = []
@export var collision_body: PackedScene = null

var board: Array = []



func _ready() -> void:
	load_board_from_txt()
	instantiate_gems()
	
	pass
	
func load_board_from_txt()->void:
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
	var board_node = Node3D.new()
	board_node.name = "Board"
	add_child(board_node)

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
			gem.position = Vector3(board_height - i, 0, j)
			gem.set_meta("gem_id", gem_id)
			gem.set_meta("gem_pos", Vector2(i, j))
			board_node.add_child(gem)

			var collision_body_instance = collision_body.instantiate()
			collision_body_instance.position = Vector3(board_height - i, 0, j)
			collision_body_instance.set_meta("gem_id", gem_id)
			collision_body_instance.set_meta("gem_pos", Vector2(i, j))
			board_node.add_child(collision_body_instance)

	$CameraHandle.position = Vector3((board_height - 1) / 2.0, 0, (board_width - 1) / 2.0)

enum InputState {IDLE, PICKED_1}
var input_state: InputState = InputState.IDLE

func _input(event):
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed and input_state == InputState.IDLE:
		process_input_pressed(event.position)
		return

	if (event is InputEventMouseButton or event is InputEventScreenTouch) and !event.pressed and input_state == InputState.PICKED_1:
		process_input_released(event.position)

	if (event is InputEventMouseMotion or event is InputEventScreenDrag) and input_state == InputState.PICKED_1:
		print("Dragging: ", event.position)

	
	pass


func process_input_pressed(input_position: Vector2) -> void:
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
		var collider = result.collider
		if collider.has_meta("gem_id"):
			var gem_id = collider.get_meta("gem_id")
			var gem_pos = collider.get_meta("gem_pos")
			print("Gem ID: ", gem_id, " at position: ", gem_pos)
			input_state = InputState.PICKED_1
			return
		else:
			input_state = InputState.IDLE
			return
	else:
		input_state = InputState.IDLE
		return

func process_input_released(input_position: Vector2) -> void:
	input_state = InputState.IDLE
	pass
