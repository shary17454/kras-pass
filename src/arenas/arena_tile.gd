class_name ArenaTile
extends StaticBody3D
## One floor tile. Used by the crumbling court, the paint grid and the colour
## floor — three very different games that all need "a square of floor with
## state", so it lives here once.

signal collapsed(tile: ArenaTile)

enum State { SOLID, WARNING, FALLING, GONE }

var grid_x := 0
var grid_z := 0
var base_color := Color.GRAY
var owner_slot := -1          ## paint games: who claimed it
var tag := ""                 ## colour games: which colour group this is
var state: State = State.SOLID
var crumbles := false
var crumble_delay := 0.9
var respawn_time := 6.0

var _mesh: MeshInstance3D
var _timer := 0.0
var _home_y := 0.0
var _size := 2.0


func build(size: float, thickness: float, color: Color) -> void:
	_size = size
	base_color = color
	_home_y = position.y
	_mesh = MeshFactory.box(Vector3(size * 0.94, thickness, size * 0.94), color)
	_mesh.position = Vector3(0, -thickness * 0.5, 0)
	add_child(_mesh)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size, thickness, size)
	shape.shape = box
	shape.position = Vector3(0, -thickness * 0.5, 0)
	add_child(shape)
	collision_layer = 1
	collision_mask = 0


func set_color(c: Color, emission := 0.0) -> void:
	base_color = c
	if _mesh != null and is_instance_valid(_mesh):
		_mesh.material_override = MeshFactory.toon(c, emission)


## Claim for a player. Returns true if the owner actually changed, so callers
## can score without re-checking.
func claim(slot: int, color: Color) -> bool:
	if owner_slot == slot:
		return false
	owner_slot = slot
	set_color(color, 0.35)
	return true


func touch() -> void:
	if not crumbles or state != State.SOLID:
		return
	state = State.WARNING
	_timer = crumble_delay


func force_collapse() -> void:
	if state == State.GONE or state == State.FALLING:
		return
	state = State.FALLING
	_timer = 0.0


func restore() -> void:
	state = State.SOLID
	_timer = 0.0
	position.y = _home_y
	visible = true
	set_collision_layer_value(1, true)
	if _mesh != null and is_instance_valid(_mesh):
		_mesh.scale = Vector3.ONE
		_mesh.material_override = MeshFactory.toon(base_color)


func is_standable() -> bool:
	return state == State.SOLID or state == State.WARNING


func tick(delta: float) -> void:
	match state:
		State.WARNING:
			_timer -= delta
			# Shake harder the closer it is to going, so the tell is readable
			# without a HUD element.
			var urgency := 1.0 - clampf(_timer / maxf(crumble_delay, 0.001), 0.0, 1.0)
			if _mesh != null and is_instance_valid(_mesh):
				_mesh.position.x = sin(Time.get_ticks_msec() * 0.04) * 0.06 * urgency
				_mesh.material_override = MeshFactory.toon(base_color.lerp(Color(1, 0.35, 0.3), urgency))
			if _timer <= 0.0:
				state = State.FALLING
				_timer = 0.0
				set_collision_layer_value(1, false)
				collapsed.emit(self)
				AudioManager.play_sfx("crate_break", global_position)
		State.FALLING:
			_timer += delta
			position.y -= (2.0 + _timer * 14.0) * delta
			if _mesh != null and is_instance_valid(_mesh):
				_mesh.position.x = 0.0
			if position.y < _home_y - 12.0:
				state = State.GONE
				visible = false
				_timer = 0.0
		State.GONE:
			if respawn_time > 0.0:
				_timer += delta
				if _timer >= respawn_time:
					restore()
