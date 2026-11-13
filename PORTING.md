# ArcHUD2 → WoW Forever (1.60.x, Interface 16001) porting notes

Source: `legacy\ArcHUD2` (ArcHUD 2.0 r8945, Interface 11200, Ace2). APIs were checked against
`_ref\wow-ui-source` branch `forever` (1.60.1.70790).

## What changed
- **Ace2 removed.** `Framework.lua` replaces AceAddon, AceEvent, AceDB, AceModuleCore, AceDebug, AceConsole and Metrognome. The method names are kept, so the ring code reads like the original. `Locale.lua` replaces AceLocale, and the three locale files are unchanged apart from their header lines (plus one broken byte in deDE).
- **Lua 5.1.** Handlers take `(self, event, ...)`. Also: `%` instead of `math.mod`, `_G` instead of `getglobal`, and `...` instead of `arg`.
- **APIs:**
  - `UnitMana*` → `UnitPower*`.
  - `UNIT_MANA/RAGE/ENERGY/FOCUS` → `UNIT_POWER_FREQUENT`/`UNIT_MAXPOWER`.
  - `SPELLCAST_*` → `UNIT_SPELLCAST_*` with `UnitCastingInfo`/`UnitChannelInfo`.
  - `PLAYER_COMBO_POINTS` → player power events with `GetComboPoints("player","target")`.
  - `UnitBuff`/`UnitDebuff` → `C_UnitAuras`.
  - `UnitIsPartyLeader` → `UnitIsGroupLeader`.
  - `PARTY_MEMBERS_CHANGED` → `GROUP_ROSTER_UPDATE`.
  - `PlaySound` now uses `SOUNDKIT` constants.
  - `ManaBarColor` → `PowerBarColor`.
  - `GetPetHappiness` → `C_PetInfo.GetPetHappiness`.
  - The `DebuffTypeColor` and `MirrorTimerColors` values are now kept locally.
- **Rings and secret values (hybrid renderer, `RingTemplate.lua`):**
  - When values are readable, the original quadrant/chip/slice code runs unchanged: same look, tapered tip and fade animation.
  - When health or power is secret (combat restrictions), the ring shows its full half-ring. A rotating `MaskTexture` then cuts it along the radius. The rotation, color fade, "full" alpha and deficit visibility all come from `UnitHealthPercent`/`UnitPowerPercent` curves, so Lua never reads the number.
  - Differences in secret mode: no smooth fill animation, and no tapered tip.
- **Clickable nameplates** are now `SecureUnitButtonTemplate` buttons (left click targets, right click opens the unit menu). They are reparented to UIParent, shown through `RegisterUnitWatch`, and mouse enable/disable is queued until combat ends.
- **Hiding Blizzard frames:**
  - Player, pet and target frames, ComboFrame and MirrorTimerContainer are hidden by reparenting them to a hidden frame, out of combat. The old approach unregistered all their events, which would taint them now.
  - The cast bar is switched off with `SetUnit(nil)` instead.
- **`/archud config`** now uses the Blizzard Menu API (MenuUtil) at the cursor. The tree is the same as before; sliders are `MinimalSliderWithSteppersTemplate` rows.
- **SavedVariables:** still `ArcHUDDB`, but data lives under `ArcHUDDB.forever` (version 1, per character). Old Ace2 data is ignored, not imported.

## Removed (and why)
- **MobHealth2/3 and MobInfo-2 support:** those addons don't exist, and the client reports real target health.
- **DruidBar and SoleManax dependency:** the API reports druid mana directly.
- **`ArcHUD_CustomClick` override:** secure buttons can't call addon code in place of targeting.
- **The cancel-spell-targeting behavior when clicking a nameplate:** the secure "target" action casts the pending spell on the unit instead.
- **`tmp\Party.lua`:** it was never listed in the TOC.

## Added (not in the original, requested by the user)
- **Minimap button** (`MinimapIcon.lua`): drag it around the minimap; click opens the ArcHUD menu. The position (`MinimapAngle`) and visibility (`MinimapIcon`, menu: Miscellanous options → Minimap icon) are saved per character. The frame is named `ArcHUDMinimapButton` so minimap button collector addons can find it.
- **Addon compartment entry:** ArcHUD shows up in Blizzard's addon list on the minimap. It uses the TOC fields `AddonCompartmentFunc`, `AddonCompartmentFuncOnEnter`, `AddonCompartmentFuncOnLeave` and `IconTexture`, plus the three matching `ArcHUD_OnAddonCompartment*` globals.
- **Icon:** `Icons\ArcHUDIcon.tga`, generated: two arcs, green left and blue right.
- **Error log:** stored in `ArcHUDDB.forever.errorLog`; `/archud errors [clear]`.

## Fixes after first in-game test
- **Settings reverted when switching sliders.** Pooled menu rows fired the previous slider's callback during `Init`, writing the new slider's value into the old setting. Old handlers are now detached before `Init`. All settings are also range-checked on login and on every change, and invalid values reset to their defaults with a chat message.
- **The HUD stopped updating after the first fight.**
  - Cause: once a ring's alpha had been set from a secret value, `GetAlpha()` kept returning a secret, and the fade code compared it, which raised an error.
  - Fix: ring alpha is now always tracked in Lua (`curAlpha`), and `GetAlpha()` is never compared.
- **One error froze every ring.** All ring timers share one update loop, so a single error stopped the timers after it.
  - Fix: timers, event handlers and internal messages now run through `xpcall`. Errors are still reported to BugSack, but the other rings keep running.

## Verify in game
1. Do the rings fill from the correct end in secret mode (in combat, or with a target in a dungeon)? If they fill top-down, set `ROTATION_SIGN = -1` in `RingTemplate.lua`.
2. Does `UnitHealthPercent(unit, true, colorCurve)` return an accessible color table, so color fade works in combat?
3. Do the menu slider rows render and apply correctly?
4. Are target buffs and debuffs shown in restricted content (12.1 aura restrictions)?
5. Does `PlayerModel:SetUnit` work in dungeons? If it refuses, the model is hidden instead.
6. Hide and show the Blizzard frames, both out of combat and in combat (the change should wait until combat ends).
7. Interface number: run `/dump select(4, GetBuildInfo())`.
