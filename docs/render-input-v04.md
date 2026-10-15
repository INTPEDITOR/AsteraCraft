# v0.4 rendering and input review

The gameplay viewport uses 32 world pixels per tile. Its default zoom is 1.75: at 1440×900 this shows approximately 25.7×10.75 tiles inside the logical camera viewport. Each unit reads `visual_extent` from its definition. Sprites, building artwork, construction artwork, vehicle parts, portraits and resource artwork retain their original pixel aspect ratio.

## Registered unit artwork

`assets/motion_cache` contains 39 clean derived atlases. Each has nine stored directions and ten rows: the six authored source actions and four derived intermediate walking poses. Mirroring produces 16 visible directions. The eight walking phases contain alpha blends of existing registered poses; they are not eight newly authored poses or 32 authored directions.

Registration measures the thick body core and preserves a common source-space root through alpha trimming. Ground units retain the idle foot-to-body offset for each direction across all actions, preventing weapons and firing effects from moving the pivot. Air units use a stable body offset. Detached owl ornaments are assigned to their own body rather than discarded. The original owl unit 3 source contains ten bodies per row; the cache selects nine actual bodies rather than cutting the image into incorrect nominal columns. Four merged source firing poses use a clean wind-up fallback.

Additional generated artwork is registered through `data/aux_sprites_v04.json`: four directional medic healing poses, green-to-orange brood growth, separate chassis/turret layers for hyrax units 5/6/12, hyrax pilots, faction rally beacons, eight blue catalyst plume frames and citrus projectiles. Vehicle sockets and turret bases use separately calibrated uniform scales. Aircraft cockpit mounts are measured for all nine stored facings. Unit 6 already contains its own hyrax driver, so a second driver is not overlaid.

Brood growth advances once with authoritative morph progress. Medic healing uses the new posture and a medical beam, without gunfire effects. Construction uses the 117 building-specific cached stages from `ACConstructionVisual`; completed buildings use the existing bounded light animation.

## Input and world geometry

Attack and rally targeting consume one battlefield or minimap click before GUI dispatch. Producing buildings also accept ground/minimap right-click rally commands. Unknown physical key codes fall back to the logical key code, including the native Windows path that previously swallowed A/R. Build commands pass the Shift queue flag, and remote commands accept brood morph/cancel and queue indices.

Terrain inversion intersects the actual 16-pixel terrain triangles. Where a cliff projects over another surface, the greatest world-y intersection is selected, matching terrain draw order. The world has a real clipping parent, an outer black mask and the terrain boundary mask. Terrain extends behind transparent HUD cutouts and under the top resource icons.

The mouse enters Godot confined mode during a focused battle, uses faction cursor artwork, and returns to visible mode for menus, lost focus, minimization and exit. The logical viewport also clamps and warps an out-of-bounds pointer to keep it out of letterbox space.

Raw catalyst artwork is hidden from the start of refinery construction. A completed refinery emits a small plume from its outlet instead of stacking the ground resource and a large flame over the building.

## Verification

- `view_input_v04_test.gd`: 7,045 checks passed after final cache import; covers A/R ground targeting, minimap targeting, right-click building rally, all 3,510 cached frame roots/scales, auxiliary artwork, and exact terrain inversion. Maximum projected inverse error was 0.00049 pixels; five overlapping samples correctly chose the front surface.
- `ui_test.gd`: 86 checks passed on the actual OpenGL renderer. The combat fixture explicitly excludes attached brood entities from F2 army counts.
- `battle_v04_preview.gd`: nine integration checks passed and three faction start/roster captures plus a refinery capture were inspected. Roster captures are staged art-review fixtures; start captures use the real starting state.
- Native Windows key/mouse delivery confirmed A-ground, R-ground and A-minimap commands and exposed the unknown-physical-key issue. Exact native clip bounds could not be certified: the managed desktop returned the entire desktop from `GetClipCursor`, and unrelated desktop input interrupted the final automated run. This is distinct from the passing Godot input regressions; native confinement still requires a normal desktop smoke check.

Known source limits remain: most movement/attack directions use the original 16 visual facings; owl unit 3 has repeated source orientations; vehicle part sheets provide directional poses rather than newly authored track cycles. These limitations are not described as completed 32-direction animation.
