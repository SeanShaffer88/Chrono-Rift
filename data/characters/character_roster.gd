extends RefCounted
## Original identities; one shared combat controller, separate owned weapons.
const HEROES = {
	"melee_hero": {"name": "Infiltrator", "description": "Green cap · sword · back shield", "starter": preload("res://data/weapons/trail_sword.tres")},
	"swordsman": {"name": "Shadowblade", "description": "Silver hair · broad greatsword", "starter": preload("res://data/weapons/duskblade.tres")},
	"riftwarden": {"name": "Riftwarden", "description": "Ivory mask · red energy sword", "starter": preload("res://data/weapons/rift_chain.tres")},
}
