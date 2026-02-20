# M7MD-tool

QBCore developer/admin helper with a lightweight NUI.

## Features
- Give items with autocomplete from `qb-core/shared/items.lua`
- Remove items / clear inventory (with confirmation)
- Copy coordinates in multiple formats (vec3/vec4/vector3/vector4/JSON/snippets)
- Player admin tools: goto/bring, teleport to coords, give money, set job/gang, set metadata
- Zones builder: copy snippets for `qb-polyzone`, `qb-target`, and `ox_lib` zones
- Snippet generator (events/callbacks/commands/items/jobs)
- Optional debug overlay + copy player info + copy street name
- Event tester (disabled by default; whitelist only)

## Commands
- `/m7tool` open tool (defaults to Give Item)
- `/m7give` open Give Item tab
- `/m7coords` open Copy Coords tab
- `/dt` opens a quick menu (recommended)

## Permissions
Allowed if either:
- ACE: `IsPlayerAceAllowed(source, 'command.m7tool')`
- QBCore permission: any in `shared/config.lua` `Config.QBCorePerms` (god/admin/operator/etc)

## Install
1) Put resource in: `resources/[m7md]/M7MD-tool`
2) Enable it in `resources.cfg` by adding:
   - `ensure [m7md]`
3) Restart server (or `ensure M7MD-tool` in console).

## Notes
- All sensitive actions are validated server-side.
- Clipboard uses `ox_lib` (`lib.setClipboard`).

