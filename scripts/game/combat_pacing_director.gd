extends Node
class_name CombatPacingDirector

const NORMAL_ATTACK_SLOTS := 2
const BOSS_SUPPORT_ATTACK_SLOTS := 1
const HIGH_RISK_GAP := 0.65

var boss_mode := false
var _clock := 0.0
var _last_high_risk_attack := -99.0
var _support_suspended_until := -1.0
var _owners: Dictionary = {}


func _process(delta: float) -> void:
	if not get_tree().paused:
		_clock += delta
	_cleanup_invalid_owners()


func request_attack(owner: Node, high_risk: bool) -> bool:
	_cleanup_invalid_owners()
	if boss_mode and _clock < _support_suspended_until:
		return false
	var limit := BOSS_SUPPORT_ATTACK_SLOTS if boss_mode else NORMAL_ATTACK_SLOTS
	if _owners.size() >= limit:
		return false
	if high_risk and _clock - _last_high_risk_attack < HIGH_RISK_GAP:
		return false
	_owners[owner.get_instance_id()] = weakref(owner)
	if high_risk:
		_last_high_risk_attack = _clock
	return true


func release_attack(owner: Node) -> void:
	if owner != null:
		_owners.erase(owner.get_instance_id())


func set_boss_mode(enabled: bool) -> void:
	boss_mode = enabled
	_cleanup_invalid_owners()


func suspend_boss_support(duration: float) -> void:
	if boss_mode:
		_support_suspended_until = maxf(_support_suspended_until, _clock + maxf(duration, 0.0))


func active_attack_count() -> int:
	_cleanup_invalid_owners()
	return _owners.size()


func _cleanup_invalid_owners() -> void:
	for instance_id in _owners.keys():
		var reference: WeakRef = _owners[instance_id]
		if reference.get_ref() == null:
			_owners.erase(instance_id)
