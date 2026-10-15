# v0.4 gameplay state and command changes

## Starts

`config.spawn_slots` maps each owner index to one of the four map starts. A valid
array has the same length as `config.players`, distinct integer values from 0 to
3, and is applied unchanged. Integer-valued JSON numbers are accepted. The
server owns the finalized ladder/custom assignment.

When this array is absent or invalid, a separate RNG shuffles all four starts
from the match seed. An explicit `config.seed` makes this reproducible. If the
seed is omitted, `setup()` randomizes it for each local match and exposes the
chosen value as `core.match_seed`. `players[owner].spawn_slot` is retained in the
owner's snapshot; enemy assignments are removed from filtered snapshots.

## Production and citrus brood

The production limit is five entries total, including the current entry.
`{type: "cancel", id, queue_index}` cancels one entry, refunds its full cost and
releases its reserved population. Omitting `queue_index` cancels the last entry.
Invalid indices make no economic changes.

Research buttons and authority validation share `ACData.research_stats(race,
buildingKind)`. The designated laboratories are building 6 for rock hyraxes and
owls and building 5 for citrus. Only those buildings accept active research
commands. Passive technology prerequisites remain part of the existing tree.

`{type: "build", ids: [workerId, ...], kind, pos, queued: true}` appends a
construction plan to the first valid selected worker. A busy worker is never
silently replaced. Pending `unit.build_queue` entries contain `{kind,pos}` and
are checked and charged when activated, without creating distant scaffolds.
Rock hyrax workers wait for completion before their next site. Citrus workers
plant a seedling at close range and survive while it grows; owl workers release
a warp at close range. Both can then proceed to their next site. An invalid or
unaffordable pending site is skipped once with a notice. A new nonqueued order
clears waiting plans; cancelling an active scaffold advances the same worker;
death drops its uncharged future plans. Visible enemy workers do not expose
their hidden future sites in snapshots.

The original roster remains 13 units per race. Citrus additionally defines
technical unit kind 13 through `ACData.unit(1,13)`. It is a selectable, damageable
brood entity with zero population and `technical: true`. Its attached collision
layer (0) does not obstruct workers or armies. Technical entities must be excluded
from army counts and whole-army selection; their completed morphs are normal
units and count normally, even though their entity ID is preserved.

`scripts/citrus_brood.gd` controls the brood lifecycle. A completed citrus HQ or
nursery generates three idle brood entities. The HQ regenerates a missing idle
brood every 15 seconds and a nursery every 25 seconds. Each producer has a strict
idle cap of three. A morphing brood does not occupy an idle regeneration slot.

Commands are `{type: "morph", id: broodId, kind: unitKind}` and
`{type: "cancel_morph", id: broodId}`. The legacy HQ/nursery `train` command
selects an available idle brood. Every selected brood has its own concurrent
morph timer, cost and population reservation. The owning producer's `queue`
mirrors these timers as `{kind, left, total, brood: broodId}`; both command paths
enforce five active morphs per parent. Cancellation restores the same brood and
refunds once. Death releases its reservation once without a refund. A live egg
can finish after its producer is destroyed.

Brood state includes `brood_parent`, `brood_state` (`idle` or `morph`),
`morph_kind`, `morph_left`, `morph_total`, and `morph_rally`. Morph completion
preserves the ID and rebuilds the unit's actual collision body, hit points,
energy, action state and normal unit definition.

## Worker contact and mining

Only one worker actively harvests an As node at a time. A worker assigned to an
occupied node searches for the nearest available node within 20 tiles. Active
As workers may pass through other workers; soldiers, resources, buildings and
terrain retain their collision rules. Returning final cargo remains valid after
the field is exhausted.

Construction and As delivery use the actual body-to-building AABB gap, at most
0.35 tile. `body_footprint_gap(worker, building)`, `building_contact(...)`, and
`construction_reach(...)` expose this same rule. `building_approach` with a unit
argument selects an exterior position with a 0.15-tile body gap. Workers do not
walk through the building center. Idle allies yield along the whole short swept
approach corridor, including immediately adjacent blockers.

## Healing, energy and retreat

All units expose `energy` and `max_energy`. Noncasters have both set to zero;
the HUD hides their energy bars. Medic, mage and priest roles default to a
200-point capacity; a definition may override `max_energy` explicitly.

Healing snapshots include `healing`, `heal_target`, `heal_kind`, `heal_started`
and `heal_pulse`. A stationary healer uses action `heal`. Medic healing emits a
rate-limited `heal` effect with `heal_kind: "medic"`,
`projectile: "heal_medical"`, `target`, and the actual `amount`. Sap healing uses
`heal_kind: "sap"` / `heal_sap`. These events do not set the weapon `fired`
timestamp or emit a gunshot. Effects retain the standard owner/race/unit/from/to
fields and existing visibility filtering.

An unarmed mobile unit that takes damage can retreat four tiles opposite the
damage source. It uses ordinary bounded, collision-aware movement, a fixed
destination and a short cooldown. Fresh player orders immediately override the
retreat. Armed workers and attached brood entities are excluded. A trapped unit
stays in place without teleporting or repeatedly extending its destination.

Units also expose independent `body_direction` and `turret_direction` vectors.
Body direction preserves the last actual movement bearing. Turret direction
tracks the current valid weapon target, including during pursuit, and returns
to body direction when there is no target. Existing `facing` remains available
for units without a separately rendered turret.

Melee retains its configured center-based range and additionally permits a
strike when the attacker's and target's actual body edges are within 0.12 tile.
This prevents a large target's collision box from making melee contact
impossible. Melee pursuit approaches a valid exterior edge rather than trying
to walk to the target's center. Ranged weapon reach is unchanged by this rule.
A short final movement within a shared clearance cell is completed only after
the entire static body sweep passes terrain, building and resource checks.

## Validation

Focused regressions are `tests/gameplay_v04_test.gd`,
`tests/construction_queue_v04_test.gd`, `tests/melee_contact_v04_test.gd`, and
`tests/citrus_brood_v04_test.gd`; existing core, economy, collision, combat,
resource and citrus AI regressions remain applicable. The focused suite checks
the current balance-data attack range and collision spacing of every armed
ranged unit, rather than assuming previous speed/range constants.
