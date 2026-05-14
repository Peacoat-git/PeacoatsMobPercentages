# Peacoat's Mob Percentages

![WoW Version](https://img.shields.io/badge/WoW-12.0.5-blue)
![Version](https://img.shields.io/badge/version-1.2.0-green)

A lightweight World of Warcraft addon that shows each trash mob's **forces (count) percentage** contribution toward completing a Mythic+ dungeon — displayed directly on the NPC tooltip when you hover over them.

---

## Features

- Shows `Forces: X.XX%` on NPC tooltips inside supported dungeons
- Only activates when you're **inside a relevant dungeon instance** — silent everywhere else
- Bosses and non-counting NPCs show nothing (clean by design)
- Configurable **font size** (8–20pt)
- Configurable **line placement** — append the forces line above or below existing tooltip text
- Enable/disable toggle with UI reload prompt
- Settings persist across sessions via SavedVariables
- Custom Peacoat icon in the addon list and settings panel

---

## Supported Dungeons

### Midnight Season
| Dungeon | Total Count |
|---|---|
| Algethar Academy | 460 |
| Magister's Terrace | 585 |
| Maisara Caverns | 607 |
| Nexus-Point Xen'as | 596 |
| Pit of Saron | 643 |
| Seat of the Triumvirate | 568 |
| Skyreach | 431 |
| Windrunner Spire | 591 |

### Mists of Pandaria Season
| Dungeon | Total Count |
|---|---|
| Gate of the Setting Sun | 25 |
| Mogu'shan Palace | 20 |
| Scarlet Halls | 50 |
| Scarlet Monastery | 40 |
| Scholomance | 35 |
| Shado-Pan Monastery | 32 |
| Siege of Niuzao Temple | 65 |
| Stormstout Brewery | 25 |
| Temple of the Jade Serpent | 45 |

NPC data sourced from [MythicDungeonTools](https://github.com/mythicdungeontoolsteam/MythicDungeonTools).

---

## Installation

1. Download the latest release zip
2. Extract so the folder structure is:
   ```
   World of Warcraft/_retail_/Interface/AddOns/PeacoatsMobPercentages/
   ```
3. The folder must contain `PeacoatsMobPercentages.toc` at its root
4. Restart WoW (or `/reload`)

---

## Usage

Hover over any trash mob inside a supported dungeon — the forces % line appears automatically on the tooltip.

### Settings Panel

Open via: `ESC → Interface → AddOns → Peacoat's Mob Percentages`

- **Enable/Disable** — toggle the addon on or off (prompts for UI reload)
- **Font Size** — slider from 8 to 20pt (default: 12, matches standard tooltip text)
- **Line Placement** — choose whether the forces line appears above or below the existing tooltip lines

### Slash Commands

| Command | Action |
|---|---|
| `/pmp` | Open the settings panel |
| `/pmp enable` | Enable the addon |
| `/pmp disable` | Disable the addon |
| `/pmp above` | Place forces line above tooltip content |
| `/pmp below` | Place forces line below tooltip content |
| `/pmp size <8-20>` | Set the font size |

---

## How "Above" Placement Works

WoW's tooltip API only supports appending lines, not inserting at arbitrary positions. The `above` mode uses the established technique (also used by TipTac and idTip): snapshot all existing line texts and colours, `ClearLines()`, inject the forces line first, then re-add all original lines in order.

---

## Files

```
PeacoatsMobPercentages/
├── PeacoatsMobPercentages.toc   # Addon metadata & load order
├── PeacoatsMobPercentages.lua   # Core logic, tooltip hook, settings UI
├── Data.lua                     # NPC force counts & zone mappings (205 NPCs, 47 zones)
└── Media/
    ├── icon.tga                 # 64x64 addon icon (TGA)
    └── icon.png                 # 64x64 addon icon (PNG)
```

---

## License

MIT — do whatever you like with it.
