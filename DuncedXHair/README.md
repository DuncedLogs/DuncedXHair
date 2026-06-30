# DuncedXHair

Standalone WoW addon for a movable, configurable center-screen crosshair.

## Install

Copy the `DuncedXHair` folder into:

```text
World of Warcraft/_retail_/Interface/AddOns/
```

Then enable `DuncedXHair` on the character select addon screen.

## Setup

Use `/dxh` in game.

Useful commands:

```text
/dxh options
/dxh unlock
/dxh lock
/dxh center
/dxh size 64
/dxh thickness 3
/dxh border 4
/dxh shape circle
/dxh shape unicode
/dxh symbol +
/dxh symbol filledcircle
/dxh weight bold
/dxh fill 100
/dxh combat on
/dxh combat off
/dxh timing on
/dxh showafter 3
/dxh hideafter 20
/dxh linger 2
```

`shape` supports `cross`, `circle`, `square`, and `unicode`. Unicode mode uses a selectable font symbol such as `+`, `○`, `●`, `□`, or `■`. Use `/dxh symbol +` or pick a symbol in the options panel. `weight` supports `light`, `regular`, `medium`, and `bold` in unicode mode.

`thickness` controls line/ring thickness for circle and square, `size` controls the overall shape size, `border` controls the black outline, and `fill` controls how filled circle and square shapes are.

Use `/dxh fill 0` for an outline, `/dxh fill 100` for a filled shape, or any value between.

Combat timing:

- `showafter` hides the crosshair until that many seconds into combat.
- `hideafter` hides it after that many seconds in combat. Use `0` to disable.
- `linger` keeps it visible for that many seconds after combat ends.

## Boss Phase Rules

Boss phase rules require a phase source. The addon listens for DBM and BigWigs phase callbacks when either boss mod is loaded. It also uses Blizzard encounter start/end events to know which boss is active.

Examples:

```text
/dxh phases on
/dxh rule lura 4
/dxh rule lura 2,4
/dxh delrule lura
/dxh rules
```

With phase rules enabled, the crosshair is hidden unless the active encounter name matches a configured rule and the current phase is allowed. Boss names are matched loosely, so `lura` will match an encounter name that contains `Lura`.

If a boss name match is unreliable, you can use an encounter ID rule:

```text
/dxh rule id:1234 2,4
```

For testing without a boss mod callback:

```text
/dxh phase 4
```
