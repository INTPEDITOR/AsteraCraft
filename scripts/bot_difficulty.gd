extends RefCounted
## AI operating goals only. Human supply, prices, income and vision are unchanged.
const APM=[50,100,150,200,250,300]
const SUPPLY=[50,80,120,160,180,200]
const WORKERS_PER_BASE=[8,12,16,16,16,16]

static func supply_target(level: int) -> int:
	return SUPPLY[clampi(level,0,5)]

static func workers(level: int,patch_slots: int,bases: int) -> int:
	return mini(patch_slots,WORKERS_PER_BASE[clampi(level,0,5)]*bases)
