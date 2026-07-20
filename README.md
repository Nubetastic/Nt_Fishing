# Nt_Fishing

Fishing for the RSG Framework with a timing-based NUI minigame, bait preferences, multiple difficulty levels, fish struggles, and an in-game fishing guide.

## Requirements

- `rsg-core`
- `rsg-inventory`
- `ox_lib`

## Installation

1. Place `Nt_Fishing` in your resources folder.
2. Ensure its dependencies start first, then add `ensure Nt_Fishing` to `server.cfg`.
3. Adjust timing, difficulty, Eagle Eye, tackle, and fish attraction settings in `config.lua` as needed.

## Usage

Equip a fishing rod, then use a bait or lure from your inventory. Cast normally and press **Space** while the marker is in the green zone; press **Esc** to cancel.

Natural bait is consumed after a fish bites. Lures are reusable unless the line snaps.

## Radial-menu guide

Add this entry to your radial-menu configuration in the appropriate menu section:

```lua
{
    id = 'fishing_guide',
    title = 'Fishing Guide',
    icon = 'fish-fins',
    type = 'client',
    event = 'Nt_Fishing:client:openFishingGuide',
    shouldClose = true
}
```
