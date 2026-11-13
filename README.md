# ArcHud 2 Forever

A port of **ArcHUD 2.0** (Saleel/Nenie, 2006) to **WoW Forever** (client 1.60.x, Interface 16001).

ArcHud 2 Forever draws a combat HUD around your character: player, target and pet health and power as rings, plus a cast bar, combo points, mirror timers (breath/fatigue) and druid mana. A small target frame shows text values and a 3D model.

## Install

Download it from CurseForge, or copy the `ArcHUD2` folder into `World of Warcraft\_forever_\Interface\AddOns\`.

## Usage

- `/archud` or `/ah` shows the commands.
- `/archud config` opens the options menu. The minimap button and the addon compartment entry open it too.
- `/archud errors [clear]` shows or clears the saved error log.

## Differences from the 2006 version

WoW Forever runs the modern (Midnight 12.x) addon API, and health and power can be *secret values* in combat. When values are secret, the rings use a mask-based fill: no smooth animation and no tapered tip. Outside combat they look and animate as before. MobHealth/MobInfo and DruidBar support was removed because the game now provides those values itself. See [PORTING.md](PORTING.md) for the full list.

Settings are saved per character in `ArcHUDDB`. Settings from the old Ace2 version are not imported.

## Credits

Original ArcHUD by Saleel/Nenie of Argent Dawn, based on Tivoli's Nurfed HUD and the StatRings code by Iriel and Antiarc. Forever port by Cebion.

## Bugs

Please open an issue with the BugSack output, or with the text from `/console scriptErrors 1`.

## License

GNU General Public License v2, the same licence as the original ArcHUD2 (https://www.curseforge.com/wow/addons/arc-hud2). See [LICENSE](LICENSE).
