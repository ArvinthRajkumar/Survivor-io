class_name Layers
extends RefCounted
## Central definition of the 2D physics layer bit values used by the whole game.
## Keeping them here avoids magic numbers scattered through scenes and scripts.

const PLAYER: int = 1 << 0        # 1
const ENEMY: int = 1 << 1         # 2
const PLAYER_ATTACK: int = 1 << 2 # 4
const ENEMY_ATTACK: int = 1 << 3  # 8
const PICKUP: int = 1 << 4        # 16
const HAZARD: int = 1 << 5        # 32
const WORLD: int = 1 << 6         # 64
