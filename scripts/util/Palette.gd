class_name Palette
extends RefCounted
## Shared UI colours. Level-specific palettes live on LevelData resources.

const BG_DEEP := Color(0.035, 0.043, 0.078)
const BG_PANEL := Color(0.078, 0.094, 0.145, 0.94)
const BG_PANEL_SOLID := Color(0.078, 0.094, 0.145)
const TEXT := Color(0.90, 0.94, 1.0)
const TEXT_DIM := Color(0.58, 0.64, 0.76)
const ACCENT := Color(0.35, 0.90, 1.0)
const ACCENT_WARM := Color(1.0, 0.66, 0.28)
const DANGER := Color(1.0, 0.32, 0.38)
const HEALTH := Color(0.35, 0.92, 0.55)
const XP := Color(0.55, 0.72, 1.0)
const GOLD := Color(1.0, 0.83, 0.35)
const RESEARCH := Color(0.72, 0.55, 1.0)
const RARITY := {
	0: Color(0.72, 0.78, 0.88),   # common
	1: Color(0.40, 0.85, 1.00),   # rare
	2: Color(0.78, 0.52, 1.00),   # epic
	3: Color(1.00, 0.74, 0.30),   # legendary
}

static func rarity_color(rarity: int) -> Color:
	return RARITY.get(rarity, TEXT) as Color
