# BLDR-Drugs v2.9.0

Advanced drug dealing resource for QBCore with dynamic NPC sales, third-eye selling, robbery events, hot zones, evolution crafting, UI theme controls, and an in-game admin creator.

## Current Update Summary

These are the major systems currently present in the codebase:

- Robbery system with presets, peaceful handover, cash theft, item theft, and police dispatch
- Third-eye selling support for qb-target or ox_target
- NPC filtering to block shopkeepers, vehicle peds, mission peds, and robber models
- Hot zones that boost payout, XP, and success chance
- Evolution progression with unlockable recipes and crafting tables
- Admin creator that saves custom items, recipes, and crafting tables to MySQL
- UI color and gradient customization from commands and the NUI
- Sale telemetry, XP persistence, anti-spam rate limits, and server-side validation

## Player-Facing Updates

If you want a simple list of what players and customers will actually notice in-game, use this section.

### What Changed For Dealers

- Drug selling now feels more dynamic with roaming NPC customers and third-eye support
- Selling in hot zones gives better payouts, more XP, and a slightly better chance to close deals
- Players progress through dealer ranks and earn better multipliers as they gain XP
- Evolved drugs unlock through repeated sales and can be crafted into higher-value products
- The sale UI has cleaner notifications and customizable colors

### What Changed For Customers And NPC Buyers

- Shopkeepers, store clerks, mission NPCs, and vehicle NPCs are filtered out so only sensible buyers can be used
- Customer interactions are safer and more believable because the system blocks obvious non-buyers
- Some deals can now turn into robberies, which adds risk to otherwise successful sales
- Robber NPCs are pulled from a separate pool and are blocked from being normal customers

### Risk And Reward Changes

- Robberies can steal cash, steal product, and cancel the sale depending on config
- Police can receive robbery alerts when a deal goes bad
- Marked bills can be given instead of direct cash, depending on money settings
- XP, payouts, and sale outcomes are tracked more cleanly for balancing and progression

### Admin And Server Owner Benefits

- New drugs, recipes, and crafting tables can be added in-game with the admin creator
- Hot zones, robbery difficulty, target mode, and reward types can all be tuned from config
- SQL migrations are split by system so upgrades are easier to manage

## Changelog

### Hot Zones And Territory Update

- Added drug hot zones that reward players for selling in higher-risk areas
- Hot zones now increase payout, XP gain, and sale success chance
- Added default zone support for Forum Drive Turf, Davis Cut, and Rancho Projects
- Added optional hot zone map blips and enter/exit notifications
- Moved zone bonus checks server-side so payouts and XP boosts cannot be spoofed from the client

### Customer And NPC Buyer Improvements

- Added smarter NPC filtering so players cannot sell to store clerks, shopkeepers, mission NPCs, or NPCs in vehicles
- Added blacklist support for non-valid buyers to keep customer interactions believable
- Blocked robber models from being used as normal sale customers
- Improved customer selection so deals happen with more appropriate street NPCs

### Risk And Robbery Update

- Added robbery encounters that can trigger during successful deals
- Added robbery presets for easy, medium, hard, and custom balancing
- Added peaceful handover support so players can give up product instead of fighting
- Added optional cash theft, item theft, dispatch alerts, and sale cancellation on robbery
- Added robbery logging support in sale telemetry

### Progression And Rewards Update

- Added hot zone reward bonuses on top of the existing XP and dealer level progression
- Continued support for marked bills rewards and multiple money payout types
- Improved logging of payout type, unit price, sale multipliers, and robbery outcomes

### Admin And Configuration Update

- Added configurable hot zone definitions in `Config.HotZones`
- Added control over zone blips, notifications, and default multipliers
- Kept all zone tuning editable from config without requiring code changes
- Added supporting SQL upgrade path for newer telemetry columns when upgrading older installs

## Dependencies

Required:

- qb-core
- ox_lib
- oxmysql

Optional:

- qb-target
- ox_target
- es_extended only if you use `Config.Money.type = 'black_money'`

## Installation

1. Place the resource in your server resources folder.
2. Ensure the folder name matches `Config.ResourceName` if you change it. Default is `bldr-drugs`.
3. Run the SQL files that match the systems you use:
   - `sql/migration.sql` for core XP and sale logs
   - `sql/migration_evolution.sql` for evolution progression and unlocks
   - `sql/admin_creator.sql` for the admin creator item, recipe, and table storage
   - `sql/add_missing_columns.sql` only if you are upgrading an older install and need missing columns added safely
4. Add the resource to your server start order after dependencies.
5. Configure items, rewards, third-eye choice, hot zones, evolution, and creator permissions in `config.lua`.

Example `server.cfg` order:

```cfg
ensure oxmysql
ensure ox_lib
ensure qb-core
ensure qb-target
ensure bldr-drugs
```

If you use `ox_target` instead of `qb-target`, keep `ox_target` ensured and set `Config.ThirdEye.useQBTarget = false`.

## Core Features

### Selling Flow

- Dynamic NPC dealing with up to 15 active peds by default
- Token-based server validation for sell actions
- XP, rank title, and payout multipliers based on player progression
- Optional marked bills payout instead of direct money
- Sale cooldowns and per-minute rate limiting

### Third-Eye Selling

- Enabled by default in `Config.ThirdEye`
- Works with qb-target or ox_target
- Supports ped targeting out of the box
- Blacklisted zones can block selling in protected areas

### Robbery System

The robbery system is enabled by default and can interrupt otherwise successful sales.

Default behavior:

- Selected preset: `medium`
- Robbery chance: 15%
- Cash theft enabled
- Item theft enabled
- Peaceful handover enabled
- Dispatch enabled
- Sale cancelled when robbery triggers

Presets available:

- `easy`
- `medium`
- `hard`
- `custom`

Important config entries:

- `Config.Robbery.selectedPreset`
- `Config.Robbery.chance`
- `Config.Robbery.attackPlayer`
- `Config.Robbery.fightBackIfAttacked`
- `Config.Robbery.canStealCash`
- `Config.Robbery.canStealItems`
- `Config.Robbery.maxCashStolen`
- `Config.Robbery.dispatchEnabled`
- `Config.Robbery.cancelSaleOnRobbery`

### Hot Zones

Hot zones are enabled by default and are enforced server-side.

Default zones in `config.lua`:

- Forum Drive Turf
- Davis Cut
- Rancho Projects

Each zone can define:

- `priceMultiplier`
- `xpMultiplier`
- `successChanceBonus`
- `radius`
- `blip`

### Evolution System

Evolution is enabled by default and tracks player progress in MySQL.

Default unlock thresholds:

- Sell 25 `weed` to unlock `recipe_evo_weed_lvl1`
- Sell 20 `cocaine` to unlock `recipe_evo_cocaine_lvl1`
- Sell 15 `meth` to unlock `recipe_evo_meth_lvl1`

Default progress notifications:

- 75%
- 90%
- 95%

Default evolved products:

| Item | Label | Base Price | XP | Min Level |
|------|-------|------------|----|-----------|
| `evo_weed_chronic` | Chronic Kush | 68 | 6 | 1 |
| `evo_cocaine_pure` | Pure Colombian | 165 | 10 | 3 |
| `evo_meth_l1` | Blue Crystal | 235 | 12 | 4 |

Crafting notes:

- Available recipes come from both `Config.Evolution.recipes` and admin-created recipes
- Custom recipes are stored in `bldr_drug_recipes`
- Crafting tables come from admin-created table entries and synced creator data
- Crafted evolved items currently still receive purity metadata in the item info

### Admin Creator

The admin creator is enabled by default.

It allows admins to create and persist:

- Custom sellable drug items
- Custom crafting recipes
- Custom world crafting tables

Creator defaults:

- Command: `drugcreator`
- Allowed QBCore groups: `admin`, `god`
- Optional ACE permission support via `Config.Creator.useAce`
- ACE name if enabled: `bldr.drugcreator`

Stored tables:

- `bldr_drug_items`
- `bldr_drug_recipes`
- `bldr_drug_tables`

### UI Customization

The resource ships with theme controls for the drug UI.

Config sections:

- `Config.UI.colors`
- `Config.UI.gradients`
- `Config.Notifications`

Supported built-in command controls:

- `/bldr_setcolor`
- `/bldr_setgradient`
- `/bldr_showcolors`
- `/bldr_resetcolors`
- `/bldr_savecolors`

## Default Sellable Items

These are the hardcoded defaults in `Config.Items`. Admin-created items can extend or override them.

| Item | Label | Base Price | XP | Min Level | Max Amount |
|------|-------|------------|----|-----------|------------|
| `weed` | Weed | 42 | 4 | 0 | 40 |
| `xtc` | Ecstasy | 70 | 5 | 1 | 24 |
| `cocaine` | Cocaine | 105 | 7 | 2 | 20 |
| `meth` | Meth | 155 | 9 | 3 | 16 |
| `heroin` | Heroin | 170 | 10 | 4 | 12 |

## Progression Levels

| Level | Title | XP | Multiplier |
|------|-------|----|------------|
| 0 | Street Rookie | 0 | 1.0 |
| 1 | Corner Dealer | 100 | 1.05 |
| 2 | Block Runner | 300 | 1.12 |
| 3 | Neighborhood Pusher | 700 | 1.2 |
| 4 | District Supplier | 1500 | 1.35 |
| 5 | City Kingpin | 3000 | 1.5 |
| 6 | Regional Boss | 6000 | 1.75 |
| 7 | Drug Lord | 12000 | 2.0 |

## Economy and Security Defaults

Economy:

- `Config.Economy.globalPriceMultiplier = 0.92`
- `Config.Economy.xpMultiplier = 0.9`
- `Config.Economy.maxPayoutPerSale = 8500`
- `Config.Economy.maxXPGainPerSale = 250`

Security:

- `Config.Security.enabled = true`
- `Config.Security.maxClientCoordOffset = 20.0`
- `Config.Security.maxItemNameLength = 64`
- `Config.Security.minFinalPrice = 1`
- `Config.Security.rejectInvalidCoords = true`

## Commands

### Player Commands

| Command | Description |
|---------|-------------|
| `/checkevolution` | Check your evolution progress if enabled in config |
| `/checknpc` | Print nearby NPC model info for blacklist tuning |
| `/bldr_setcolor [type] [hex]` | Change a UI color |
| `/bldr_setgradient [type] [css]` | Change a UI gradient |
| `/bldr_showcolors` | Show current UI colors |
| `/bldr_resetcolors` | Reset UI theme to defaults |
| `/bldr_savecolors` | Save current UI color choices |

### Admin Commands

These use QBCore admin command permissions unless noted otherwise.

| Command | Description |
|---------|-------------|
| `/drugcreator` | Open the admin creator UI |
| `/forcerobme` | Force a robbery test |
| `/adddrugxp [id] [xp]` | Add drug XP to a player |
| `/checkdrugstats [id]` | Show stored XP and sales stats |
| `/drugdebug` | Toggle debug mode |
| `/testevorecord [id] [item] [amount] [revenue]` | Record test evolution progress |
| `/testevounlock [id] [revenue|count] [item] [amount]` | Push an evolution unlock toward completion |
| `/testevocraft [id] [recipe_key]` | Trigger evolution crafting for testing |
| `/debugunlocks [id]` | Print unlock state rows |
| `/testexactsyntax` | Test the unlock insert query |
| `/simpledbtest` | Run a simple DB health test |
| `/dbtest` | Test evolution table access |
| `/dbcheck [id]` | Read raw unlock rows for a player |
| `/checkevolution [id]` | Check another player's progress as admin |
| `/clearevodata [id] [weed|cocaine|meth|all]` | Clear evolution data |
| `/forceunlock [id] [recipe_key]` | Force unlock a recipe |

### Developer and Local Debug Commands

These are present in `client.lua` for testing and troubleshooting:

- `/testrobbery`
- `/bldr_request_token`
- `/bldr_debug_npcs`
- `/bldr_testprop`
- `/bldr_fix_ui`
- `/bldr_debug_resource`
- `/bldr_test_nui`

## Database Tables

Core:

- `bldr_drugs`
- `bldr_drugs_logs`

Evolution:

- `drug_evolution_progress`
- `drug_evolution_unlocks`

Creator:

- `bldr_drug_items`
- `bldr_drug_recipes`
- `bldr_drug_tables`

## Upgrade Notes

If you are updating an older install:

1. Run `sql/add_missing_columns.sql` to add the newer XP and log columns.
2. Run `sql/migration_evolution.sql` if you are enabling or migrating evolution.
3. Run `sql/admin_creator.sql` if you want the in-game creator features.
4. Review `Config.Robbery.selectedPreset`, `Config.HotZones`, and `Config.Creator` because these are now major gameplay systems.

## Notes

- There is no git history in this workspace, so this README reflects the current codebase state rather than commit-by-commit changes.
- The previous README had outdated prices, milestones, permissions, and setup notes. This version was aligned to `fxmanifest.lua`, `config.lua`, `server.lua`, and the shipped SQL files.