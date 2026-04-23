extends Node
class_name PlayerAbilityManager

enum AbilityType { NONE, BOOST, BRAKE, SHIELD, GHOST }

const BOOST_FORCE := 800.0
const BRAKE_FACTOR := 0.95
const SHIELD_DURATION := 5.0
const GHOST_DURATION := 3.0
var _player: RigidBody2D
var _active_ability: AbilityType = AbilityType.NONE
var _cooldowns: Dictionary = {}
var _timers: Dictionary = {}
signal ability_activated(type: AbilityType)
signal ability_ended(type: AbilityType)
signal cooldown_started(type: AbilityType, duration: float)

func setup(player_node: RigidBody2D) -> void:
	_player = player_node
	_reset_cooldowns()

func process_abilities(delta: float) -> void:
	_update_timers(delta)
	_handle_input()

func unlock_ability(type: AbilityType) -> void:
	pass

func activate_ability(type: AbilityType) -> bool:
	if _is_on_cooldown(type): return false
	match type:
		AbilityType.BOOST:
			_player.apply_central_impulse(_player.linear_velocity.normalized() * BOOST_FORCE)
			_start_cooldown(AbilityType.BOOST, 3.0)
			_spawn_boost_effect()
		AbilityType.BRAKE:
			_player.linear_velocity *= 0.1
			_start_cooldown(AbilityType.BRAKE, 2.0)
		AbilityType.SHIELD:
			_active_ability = AbilityType.SHIELD
			_timers[AbilityType.SHIELD] = SHIELD_DURATION
			_player.modulate = Color(0.5, 0.8, 1.0, 0.8)
			_start_cooldown(AbilityType.SHIELD, 10.0)
		AbilityType.GHOST:
			_active_ability = AbilityType.GHOST
			_timers[AbilityType.GHOST] = GHOST_DURATION
			_player.set_collision_mask_value(1, false)
			_player.modulate.a = 0.5
			_start_cooldown(AbilityType.GHOST, 15.0)
	ability_activated.emit(type)
	return true

func _handle_input() -> void:
	if Input.is_action_just_pressed("ability_1"):
		activate_ability(AbilityType.BOOST)
	elif Input.is_action_just_pressed("ability_2"):
		activate_ability(AbilityType.BRAKE)

func _update_timers(delta: float) -> void:

	for type in _cooldowns.keys():
		if _cooldowns[type] > 0:
			_cooldowns[type] -= delta

	for type in _timers.keys():
		if _timers[type] > 0:
			_timers[type] -= delta
			if _timers[type] <= 0:
				_end_ability(type)

func _end_ability(type: AbilityType) -> void:
	match type:
		AbilityType.SHIELD:
			_player.modulate = Color.WHITE
		AbilityType.GHOST:
			_player.set_collision_mask_value(1, true)
			_player.modulate.a = 1.0
	if _active_ability == type:
		_active_ability = AbilityType.NONE
	ability_ended.emit(type)

func _start_cooldown(type: AbilityType, duration: float) -> void:
	_cooldowns[type] = duration
	cooldown_started.emit(type, duration)

func _is_on_cooldown(type: AbilityType) -> bool:
	return _cooldowns.get(type, 0.0) > 0.0

func _reset_cooldowns() -> void:
	_cooldowns.clear()
	_timers.clear()

func _spawn_boost_effect() -> void:
	if ParticleManager:
		ParticleManager.play(ParticleManager.EffectType.EXPLOSION, _player.global_position, Color(0.2, 0.8, 1.0))
