extends RefCounted
## Derive art from the existing floor number; no additional save state.
const REGIONS := ["foundry","frost","overgrown_rail"]
static func for_floor(number: int) -> String:
	return REGIONS[posmod(maxi(number,1)-1,REGIONS.size())]
static func normalized(value: String) -> String:
	return value if value in REGIONS else "foundry"
