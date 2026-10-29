extends RefCounted
## Finite role profiles; default guard values preserve the original key encounter.
const ROLES := ["hunter","bruiser","sentry"]
const DATA := {
	"guard": {"hp":60,"damage":12,"windup":0.65,"active":0.18,"recovery":0.75,"range":1.8},
	"hunter": {"hp":40,"damage":10,"windup":0.70,"active":0.35,"recovery":0.85,"range":4.0},
	"bruiser": {"hp":60,"damage":16,"windup":1.0,"active":0.22,"recovery":1.1,"range":1.8},
	"sentry": {"hp":30,"damage":8,"windup":0.9,"active":0.08,"recovery":1.2,"range":7.0},
}
static func profile(role: String) -> Dictionary:
	return DATA.get(role,DATA.guard).duplicate()
