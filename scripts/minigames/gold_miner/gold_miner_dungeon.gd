class_name GoldMinerDungeon
extends Node3D

var torch_lights: Array[OmniLight3D] = []
var base_energies: Array[float] = []
var flicker_timers: Array[float] = []

func _ready() -> void:
	torch_lights.clear()
	base_energies.clear()
	flicker_timers.clear()

	# Quét các đèn đuốc OmniLight3D có sẵn trong scene
	for child in find_children("*", "OmniLight3D", true, false):
		var l = child as OmniLight3D
		if l and l.name.begins_with("Light_"):
			torch_lights.append(l)
			base_energies.append(l.light_energy)
			flicker_timers.append(randf() * 10.0)

func _process(delta: float) -> void:
	for i in range(torch_lights.size()):
		var light = torch_lights[i]
		if not is_instance_valid(light):
			continue
		flicker_timers[i] += delta * (6.0 + float(i % 3) * 2.5)
		var t = flicker_timers[i]
		var noise = sin(t) * 0.12 + sin(t * 2.1) * 0.08 + randf_range(-0.03, 0.03)
		light.light_energy = base_energies[i] * (1.0 + noise)
