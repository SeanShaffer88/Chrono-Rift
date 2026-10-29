extends Node
## Global signal hub. Emitters must guard with `if is_instance_valid(EventBus):`
## so scenes also run in test harnesses where autoloads are not in the tree yet.

# --- Combat & Character ---
signal player_damaged(current_hp: int, max_hp: int)
signal character_swapped(character_id: String)
signal soft_lock_target_changed(target: Node3D)

# --- Inventory & Weapons ---
signal weapon_equipped(weapon_data: Resource)
signal weapon_durability_changed(current: float, max_durability: float, is_broken: bool)
signal weapon_broken(weapon_data: Resource)
signal weapon_built_up(old_weapon: Resource, new_weapon: Resource)

# --- Survival ---
signal thirst_changed(current: float, max_thirst: float)

# --- Dungeon & Atla ---
signal atla_collected(atla_id: String, piece_id: String)
signal dungeon_gate_unlocked()
signal floor_cleared()

# --- Georama ---
signal georama_piece_placed(piece_id: String, grid_coord: Vector3i)
signal georama_piece_removed(piece_id: String, grid_coord: Vector3i)
signal georama_satisfaction_updated(piece_id: String, percentage: float)
signal town_restoration_completed()
