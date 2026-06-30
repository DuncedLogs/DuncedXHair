# DuncedXHair

Standalone World of Warcraft addon for a movable center-screen crosshair with combat, boss phase, shape, size, and color controls.

## Features

- Movable and lockable crosshair frame
- Shapes: cross, dot, circle, square
- Adjustable size, thickness, border, alpha, class color, and custom color
- Visibility modes for combat and instances
- Combat timing rules:
  - show after N seconds in combat
  - hide after N seconds in combat
  - linger after combat ends
- Optional boss phase rules using DBM or BigWigs phase callbacks

## Install

Download `DuncedXHair.zip` from a GitHub Actions artifact or release, then extract it into:

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
/wcx options
/wcx unlock
/wcx lock
/wcx center
/wcx shape cross
/wcx shape dot
/wcx shape circle
/wcx shape square
/wcx size 64
/wcx thickness 3
/wcx border 4
/wcx timing on
/wcx showafter 3
/wcx hideafter 20
/wcx linger 2
/wcx phases on
/wcx rule lura 2,4
```

## Packaging

This repository includes a GitHub Actions workflow that creates `DuncedXHair.zip` with the correct addon folder structure.

Manual PowerShell packaging:

```powershell
Compress-Archive -Path .\DuncedXHair -DestinationPath .\DuncedXHair.zip -Force
```

## Publishing To GitHub

Create an empty GitHub repository named `DuncedXHair`, then run:

```powershell
git remote add origin https://github.com/YOUR_USERNAME/DuncedXHair.git
git push -u origin main
```

To create a release with an attached addon zip, push a version tag:

```powershell
git tag v1.1.0
git push origin v1.1.0
```
