# Design

granite's icon: a faceted granite stone; the blue face is the AI layer, one face of many (concept B).

- `make_icon.py` generates `icon.svg` (1024 px app icon on the macOS grid: 824 px shape, 100 px margin), `mark.svg` (the stone alone, for docs) and `menubar.svg` (one-colour template for the menu bar).
- `swift render.swift` renders them into `App/Assets.xcassets` (`AppIcon`, 16–512 pt at 1x and 2x; `MenuBarIcon`, a template image).
- `swift preview.swift` writes `preview-sheet.png` (git-ignored): every size on light and dark, to check by eye.

Change the stone or colours in `make_icon.py`, then run both scripts.
