extends RefCounted
## Pure cosmetic pose. Never writes controller/collision/weapon-pivot transforms.
static func sample(speed: float, phase: float, state: int, progress: float, side: float, recoil: float, dead: bool, output: Dictionary = {}) -> Dictionary:
	var stride := sin(phase)*clampf(speed/6.0,0,1)*0.55
	var lift := absf(sin(phase))*clampf(speed/6.0,0,1)*0.025
	var torso := Vector3(clampf(speed/6.0,0,1)*0.055,0,0)
	var right := -stride*0.55
	var left := stride*0.55
	var height := lift
	var cloth := clampf(speed/6.0,0,1)*0.14 + sin(phase*0.6)*0.025
	match state:
		1: # windup
			torso += Vector3(-0.06,0.2*side*progress,0)
			right = -0.65*progress
			left = -0.18*progress
		2: # active: stays inside the controller's existing hit window
			torso += Vector3(0.08,lerpf(0.2,-0.22,progress)*side,0)
			right = lerpf(-0.65,0.35,progress)
			left = -0.2
			cloth += 0.1
		3: # recovery
			torso += Vector3(0.08,-0.22*side,0)*(1-progress)
			right = 0.35*(1-progress)
		4: # low compact dodge, no root displacement or collider scaling
			torso = Vector3(0.55,0,0)
			height = -0.22
			right = -0.5
			left = -0.5
			stride = 0.55
			cloth = 0.3
	torso.x -= recoil*0.2
	if dead:
		torso = Vector3(0.55,0,0)
		height = -0.4
		stride = 0.55
		right = 0.2
		left = 0.2
	output["stride"] = stride
	output["torso"] = torso
	output["height"] = height
	output["right_arm"] = right
	output["left_arm"] = left
	output["cloth"] = cloth
	return output
