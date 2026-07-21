# Nt_Fishing

[![Watch the video](https://www.youtube.com/watch?v=qjWJmajmwZ8)](Showcase)

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

## Bait attraction and fish selection

Every fish species has an `attraction` value for every bait and lure in `Config.FishSpecies`. These values are **relative selection weights**, not percentages:

- `0` means that tackle can never select that species.
- A larger value makes the species more likely to be selected.
- The `preferred` list supplies the preferred-tackle labels shown in the fishing guide. The actual selection uses `attraction`.

For example, if the only eligible nearby fish have attraction weights of `100`, `50`, and `0` for the equipped tackle, their selection chances are approximately 66.7%, 33.3%, and 0%. The weights are recalculated from the fish present on each cast, so a value of `100` does not guarantee that species.

The default preferred tackle is:

| Fish | Preferred bait or lure |
| --- | --- |
| Bluegill | Cheese bait |
| Bullhead Catfish | Corn bait |
| Chain Pickerel | Corn bait |
| Channel Catfish | Crawfish lure (swamp) |
| Lake Sturgeon | Fish lure (lake) |
| Largemouth Bass | Crawfish bait |
| Longnose Gar | Crawfish lure (swamp) |
| Muskie | Fish lure (lake) |
| Northern Pike | Dragonfly lure (river) |
| Perch | Bread bait |
| Redfin Pickerel | Bread bait |
| Rock Bass | Cheese bait |
| Smallmouth Bass | Cricket bait |
| Sockeye Salmon | Dragonfly lure (river) |
| Steelhead Trout | Worm bait |

Other tackle can still catch a species whenever its configured attraction is greater than `0`. The in-game guide shows the full attraction matrix.

### How the nearby-fish scan works

When the cast reaches the bite/minigame stage, the script:

1. Uses the bobber position as the center of the scan, falling back to the hook position if needed.
2. Collects living ambient-population entities within `Config.FishScanRadius` (20 game units by default).
3. Keeps only entities whose fish model is listed in `Config.FishSpecies` and whose attraction for the equipped tackle is greater than `0`.
4. Adds each eligible fish entity to a weighted pool. Multiple spawned fish of the same species each receive that species' weight, so locally abundant species are naturally more likely.
5. Rolls once across the pool and locks in the selected fish entity, model, difficulty, and generated weight for that attempt.

If no configured, interested fish is in range, the cast ends with “No fish are interested in this tackle here.” A selected fish bites after a random delay between `Config.BiteDelayMin` and `Config.BiteDelayMax`. Winning the timing minigame awards the selected model's inventory item; failing snaps the line and awards no fish.

The server independently checks that the selected model is configured, its tackle attraction is above `0`, and the player has the tackle item before accepting an attempt.

### Tuning attraction

`Config.TackleOrder` defines the order of the 14 values passed to each species' `attraction({ ... })` entry. Keep all values in that order. The annotated reference and a copy-ready fish template are included directly above `Config.FishSpecies` in `config.lua`.

`Config.FishEagleEye.Range` is separate from `Config.FishScanRadius`: Eagle Eye controls how far configured fish are highlighted, while the scan radius controls which spawned fish can actually enter the catch pool.

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
