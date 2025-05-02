extends Node3D

# This script handles the game logic for a match-3 game.

@export_file("*.txt") var board_txt: String

@export var gems: Array[PackedScene] = []
@export var collision_body: PackedScene = null
@export var anim_time: float = 0.15

var board: Array = []
var board_gems: Array = []
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
				board_line.append(-1)
			else:
				board_line.append(int(c))

		if board_line.size() > 0:
			board.append(board_line)
			board_gems.append(Array())
			board_gems[board.size() - 1].resize(board_line.size())

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
			if gem_id == 0 or gem_id == -1:
				continue

			var gem = gems[gem_id].instantiate()
			set_gem_name(gem, gem_id)
			
			board_root.add_child(gem)
			set_gem_pos(gem, Vector2i(i, j))

			var collision_body_instance = collision_body.instantiate()
			board_root.add_child(collision_body_instance)
			collision_body_instance.position = get_3d_pos(Vector2i(i, j))
			collision_body_instance.name = "CollisionBody_" + str(i) + "_" + str(j)
			collision_body_instance.set_meta("gem_pos", Vector2i(i, j))

	$CameraHandle.position = Vector3((board_height - 2) / 2.0, 0, (board_width - 1) / 2.0)


func get_3d_pos(pos: Vector2i) -> Vector3:
	return Vector3(board.size() - pos.x, 0, pos.y)


func set_gem_pos(gem: Node3D, new_pos: Vector2i) -> void:
	gem.position = get_3d_pos(new_pos)
	gem.set_meta("gem_pos", new_pos)
	board_gems[new_pos.x][new_pos.y] = gem
	pass

func anim_gem_pos(gem: Node3D, new_pos: Vector2i) -> void:
	create_tween().tween_property(gem, "position", get_3d_pos(new_pos), anim_time)
	gem.set_meta("gem_pos", new_pos)
	board_gems[new_pos.x][new_pos.y] = gem
	pass

func set_gem_name(gem: Node3D, gem_id: int) -> void:
	gem.name = "Gem_" + str(gem_id) + "_"


enum InputState {IDLE, PICKED_1, PICKED_2, PROCESSING}
var input_state: InputState = InputState.IDLE
var first_gem_pos: Vector2i
var second_gem_pos: Vector2i

func _input(event):
	if input_state == InputState.PROCESSING:
		return

	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed and input_state == InputState.IDLE:
		process_input_pressed(event.position)
		return

	if (event is InputEventMouseButton or event is InputEventScreenTouch) and !event.pressed and input_state != InputState.IDLE:
		process_input_released(event.position)

	if (event is InputEventMouseMotion or event is InputEventScreenDrag) and input_state != InputState.IDLE:
		process_input_dragged(event.position)

	pass

func raypick_gem(input_position: Vector2) -> StaticBody3D:
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
			return find_gem_by_pos(result.collider.get_meta("gem_pos"))
		else:
			return null
	else:
		return null

func find_gem_by_pos(pos: Vector2i) -> Node3D:
	return board_gems[pos.x][pos.y]

func process_input_pressed(input_position: Vector2) -> void:
	var ray_pick_result = raypick_gem(input_position)
	if ray_pick_result:
		first_gem_pos = ray_pick_result.get_meta("gem_pos")
		input_state = InputState.PICKED_1
		return
	else:
		input_state = InputState.IDLE
		return

func process_input_dragged(input_position: Vector2) -> void:
	match input_state:
		InputState.IDLE:
			return
		InputState.PICKED_1:
			process_input_dragged_first(input_position)
			return
		InputState.PICKED_2:
			process_input_dragged_second(input_position)
			return
	pass

func are_gems_adjacent(pos1: Vector2i, pos2: Vector2i) -> bool:
	return (abs(pos1.x - pos2.x) == 1 and pos1.y == pos2.y) or (abs(pos1.y - pos2.y) == 1 and pos1.x == pos2.x)

func process_input_dragged_first(input_position: Vector2) -> void:
	var new_gem = raypick_gem(input_position)
	if !new_gem:
		return

	var new_gem_pos = new_gem.get_meta("gem_pos")
	if first_gem_pos == new_gem_pos:
		return
	if !are_gems_adjacent(first_gem_pos, new_gem_pos):
		return
	
	second_gem_pos = new_gem_pos
	input_state = InputState.PICKED_2

	var first_gem = find_gem_by_pos(first_gem_pos)
	anim_gem_pos(first_gem, second_gem_pos)
	anim_gem_pos(new_gem, first_gem_pos)

	pass

func process_input_dragged_second(input_position: Vector2) -> void:
	var new_gem = raypick_gem(input_position)
	if !new_gem:
		return

	var new_gem_pos = new_gem.get_meta("gem_pos")
	if first_gem_pos == new_gem_pos:
		return
	if second_gem_pos == new_gem_pos:
		return
	if !are_gems_adjacent(first_gem_pos, new_gem_pos):
		return

	var prev_second_gem = find_gem_by_pos(second_gem_pos)
	anim_gem_pos(prev_second_gem, second_gem_pos)

	second_gem_pos = new_gem_pos
	input_state = InputState.PICKED_2

	var first_gem = find_gem_by_pos(first_gem_pos)
	anim_gem_pos(first_gem, second_gem_pos)
	anim_gem_pos(new_gem, first_gem_pos)

	pass

func process_input_released(_input_position: Vector2) -> void:
	if input_state == InputState.PICKED_1:
		input_state = InputState.IDLE
		return

	if input_state == InputState.PICKED_2:
		# var first_gem = find_gem_by_pos(first_gem_pos)
		# var second_gem = find_gem_by_pos(second_gem_pos)
		var first_gem_id = board[first_gem_pos.x][first_gem_pos.y]
		board[first_gem_pos.x][first_gem_pos.y] = board[second_gem_pos.x][second_gem_pos.y]
		board[second_gem_pos.x][second_gem_pos.y] = first_gem_id

	input_state = InputState.IDLE

	process_board()

	pass


func process_board() -> void:
	input_state = InputState.PROCESSING

	var has_changes: bool = true
	while has_changes:
		has_changes = false

		var has_empty: bool = true
		while has_empty:
			has_empty = false

			# Move gems down
			for i in range(board.size() - 2, -1, -1):
				for j in range(board[i].size()):
					if board[i][j] < 1:
						continue

					if j < board[i + 1].size() and board[i + 1][j] == 0:
						board[i + 1][j] = board[i][j]
						board[i][j] = 0
						var gem = find_gem_by_pos(Vector2i(i, j))
						assert(gem != null)
						anim_gem_pos(gem, Vector2i(i + 1, j))
						has_empty = true
						continue

					if j > 0 and board[i + 1][j - 1] == 0:
						board[i + 1][j - 1] = board[i][j]
						board[i][j] = 0
						var gem = find_gem_by_pos(Vector2i(i, j))
						assert(gem != null)
						anim_gem_pos(gem, Vector2i(i + 1, j - 1))
						has_empty = true
						continue

					if j < board[i + 1].size() - 1 and board[i + 1][j + 1] == 0:
						board[i + 1][j + 1] = board[i][j]
						board[i][j] = 0
						var gem = find_gem_by_pos(Vector2i(i, j))
						assert(gem != null)
						anim_gem_pos(gem, Vector2i(i + 1, j + 1))
						has_empty = true
						continue

					pass
		
			# Spawn new gems in top row
			for j in range(board[0].size()):
				if board[0][j] != 0:
					continue
				var gem_id = randi() % (gems.size() - 1) + 1
				board[0][j] = gem_id
				var gem = gems[gem_id].instantiate()
				board_root.add_child(gem)
				gem.position = get_3d_pos(Vector2i(-1, j))
				anim_gem_pos(gem, Vector2i(0, j))
				set_gem_name(gem, gem_id)
				pass

			await get_tree().create_timer(anim_time).timeout
			pass


		# Find all matches
		var matched_pos: Array = []

		for i in range(board.size()):
			for j in range(board[i].size()):
				if board[i][j] == -1 or board[i][j] == 0:
					continue

				var gem_id = board[i][j]
				var count = 1
				for k in range(1, board.size() - i):
					if j < board[i + k].size() and board[i + k][j] == gem_id:
						count += 1
					else:
						break

				if count >= 3:
					has_changes = true
					for k in range(count):
						# board[i + k][j] = 0
						matched_pos.append(Vector2i(i + k, j))

				count = 1
				for k in range(1, board[i].size() - j):
					if board[i][j + k] == gem_id:
						count += 1
					else:
						break

				if count >= 3:
					has_changes = true
					for k in range(count):
						# board[i][j + k] = 0
						matched_pos.append(Vector2i(i, j + k))

		# Remove matched gems
		for i in range(matched_pos.size()):
			var pos = matched_pos[i]
			board[pos.x][pos.y] = 0
			var gem = find_gem_by_pos(pos)
			if gem:
				gem.queue_free()
				board_gems[pos.x][pos.y] = null
						

	input_state = InputState.IDLE
	pass
