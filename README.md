# DuncedXHair

Standalone World of Warcraft addon for a movable center-screen crosshair with combat, boss phase, shape, size, and color controls.

## Features

- Movable and lockable crosshair frame
- Shapes: cross, circle, square
- Adjustable size, thickness, border, alpha, class color, and custom color
- Separate visual settings remembered for each shape
- Fill amount for circle and square shapes
- Visibility modes for combat and instances
- Combat timing rules:
  - show after N seconds in combat
  - hide after N seconds in combat
  - linger after combat ends
- Optional boss phase rules using DBM or BigWigs phase callbacks, with P1-P8 checkbox setup in options
- Encounter ID helper in the boss phase editor for current raid bosses

## Install

Download `DuncedXHair.zip` from the latest release, then extract it into:

```text
World of Warcraft/_retail_/Interface/AddOns/
```

The final path should be:

```text
World of Warcraft/_retail_/Interface/AddOns/DuncedXHair/DuncedXHair.toc
```

## Commands

```text
/dxh options
/dxh unlock
/dxh lock
/dxh center
/dxh shape cross
/dxh shape circle
/dxh shape square
/dxh size 64
/dxh thickness 3
/dxh border 4
/dxh fill 100
/dxh timing on
/dxh showafter 3
/dxh hideafter 20
/dxh linger 2
/dxh phases on
/dxh rule lura 2,4
```
