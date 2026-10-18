extends Node

# HitStopManager handles game feel: frame freezes (hit-stop), time dilation, and screen shake.

signal screen_shake_requested(trauma: float)

var _is_time_dilated: bool = false
var _active_tween: Tween

func trigger_hit_stop(duration_sec: float = 0.06) -> void:
	if _is_time_dilated:
		return
	
	# Micro freeze via time_scale
	Engine.time_scale = 0.05
	# Wait in real-world time (ignore time_scale)
	await get_tree().create_timer(duration_sec * 0.05, true, false, true).timeout
	if not _is_time_dilated:
		Engine.time_scale = 1.0

func trigger_perfect_dodge_slowdown(slow_scale: float = 0.2, duration_sec: float = 0.5) -> void:
	_is_time_dilated = true
	Engine.time_scale = slow_scale
	screen_shake_requested.emit(0.4)
	
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
		
	# Wait in real-time
	await get_tree().create_timer(duration_sec * slow_scale, true, false, true).timeout
	
	# Smoothly ramp back up
	_active_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(Engine, "time_scale", 1.0, 0.15)
	await _active_tween.finished
	_is_time_dilated = false

func trigger_parry_freeze() -> void:
	trigger_hit_stop(0.12)
	screen_shake_requested.emit(0.8)
