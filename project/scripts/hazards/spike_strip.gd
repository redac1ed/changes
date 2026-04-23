extends TrapBase
class_name SpikeStrip

enum SpikeOrientation { FLOOR, CEILING, LEFT_WALL, RIGHT_WALL }

@export_category("Spike Settings")
@export var orientation: SpikeOrientation = SpikeOrientation.FLOOR
@export var spike_count: int = 0
@export var spike_height_ratio: float = 0.65
@export var gleam_speed: float = 2.0
@export var gleam_enabled: bool = true

var _gleam_position: float = 0.0
var _actual_spike_count: int = 0

func _trap_ready() -> void:
	trap_type = TrapType.SPIKE
	match orientation:
		SpikeOrientation.CEILING:
			rotation = PI
		SpikeOrientation.LEFT_WALL:
			rotation = PI / 2.0
		SpikeOrientation.RIGHT_WALL:
			rotation = -PI / 2.0
	_actual_spike_count = spike_count if spike_count > 0 else int(trap_size.x / 12.0)

func _trap_process(delta: float) -> void:
	if gleam_enabled:
		_gleam_position += gleam_speed * delta
		if _gleam_position > 1.0:
			_gleam_position -= 1.0
