extends RefCounted
## Original identities; one shared combat controller, separate owned weapons.
const HEROES = {
	"melee_hero": {"name": "Adventurer", "description": "Teal scarf · leather", "starter": preload("res://data/weapons/battle_wrench.tres")},
	"swordsman": {"name": "Swordsman", "description": "Silver hair · dark coat", "starter": preload("res://data/weapons/duskblade.tres")},
	"riftwarden": {"name": "Riftwarden", "description": "Ivory mask · crimson cape", "starter": preload("res://data/weapons/rift_chain.tres")},
}
