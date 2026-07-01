# DuncedXHair

Standalone World of Warcraft addon for a movable center-screen crosshair with combat, boss phase, shape, size, and color controls.

## Features

- Movable and lockable crosshair frame
- Shapes: cross, inverted cross, circle, square
- Adjustable size, thickness, fill amount, border, alpha, class color, and custom color
  
**Visibility modes:**
- Optional boss phase rules using DBM or BigWigs phase callbacks, with P1-P8 checkbox setup in options
- Combat/Instance visibility toggle
- Combat time-based visibility toggle

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

I used Codex Pro for creating this addon
