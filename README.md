# Steam Display Selector - v2

Pick which monitor a Steam game launches on. When you click **Play**, this
tool runs first, asks which monitor you want, edits the game's config so the
renderer comes up on that display from the start, then launches the game.

## What's different in v2

In v1, almost every new game needed new logic hardcoded into the script
(`plain` vs `utf16` vs `string-multi-field`, a `DELETE` keyword, a special
regex for float resolutions, a separate `xmlfield.ps1` for XML attributes).

v2 removes all of that. There is **one** mechanism for every game:

> A game profile is just *"which line(s) in the config change when you switch
> monitors, and what each of those lines looks like for each monitor."*
> Applying a monitor = find that line, swap it for the target monitor's version
> of the line. **"Absent" is a valid version** - that's how a field a game
> deletes on its primary monitor is handled.

Encoding (UTF-8 / UTF-16 / BOM), XML vs INI, one field vs many,
delete-the-field-entirely - all collapse into the same find-and-swap step.
**No per-game code.** New games are pure data in `gameslist.json`.

## Adding a game - the only manual step

You don't write rules or understand the file format. You let the tool *watch*.

Double-click `Add-Game.bat` in the folder. (Or, if you prefer running it from an
already-open terminal: `powershell -ExecutionPolicy Bypass -File .\engine\Add-Game.ps1`)

Either way, nothing changes permanently on your system - the execution-policy
bypass only applies to that one run, so you never need to enable PowerShell
scripts machine-wide just to use this tool.

The wizard asks for the game key, a name, and the config file path. The key
can only use letters, numbers, underscore, and hyphen - no spaces or symbols.
This isn't arbitrary: the key has to survive being passed through Steam's
Launch Option field (which splits on spaces) and Windows batch files (where
`%` is a special character), so the wizard rejects anything else and asks
again. `HD2`, `MHWILDS`, `MY-COOL-GAME` are all fine; `Crimson Desert` is not.

Then, for each monitor you care about:

1. In the **game's** display settings, set it to that monitor.
2. **Fully quit** the game so it writes the config.
3. Press Enter to snapshot.

It diffs the snapshots, figures out exactly which line(s) the game changes per
monitor (including any it deletes), shows you what it found, and lets you
exclude any that aren't actually monitor-related before saving. Some games
auto-tune rendering settings (dynamic resolution, VRS, shadow quality)
between sessions regardless of monitor - those will show up as detected
lines too, so check each one before saving. Whatever you keep gets written
into `gameslist.json`. Done.

> Finding the config file is the one thing the wizard can't do for you. Search:
> `"<Game Name>" config file location monitor AppData Windows`, or set the
> monitor in-game and look for the file that changed under `%APPDATA%`,
> `%LOCALAPPDATA%`, or the game's install folder.

## Seeing what's already added

`gameslist.json` is plain data, but you shouldn't need to open it just to see
what's in there. Double-click `List-Games.bat`, or run it from a terminal:
`powershell -ExecutionPolicy Bypass -File .\engine\List-Games.ps1`

This prints one line per game - key, name, which monitors have been captured,
how many fields, and the config path - and offers to remove a game by key if
you ask for one. You never need to hand-edit the JSON to add, inspect, or
remove a game.

## Setting the Steam launch option

Right-click the game in Steam -> **Properties** -> **Launch Options**:

```
"C:\Path\To\SteamDisplaySelector.bat" GAMEKEY %command%
```

Replace `GAMEKEY` with the key you used in the wizard.

## Files

Everything you actually click sits at the top level. The PowerShell scripts
that do the work live in `engine/` - you never need to open that folder.

```
SteamDisplaySelector/
|-- README.md
|-- CONTRIBUTING.md
|-- LICENSE
|-- Add-Game.bat            <- double-click to learn a new game
|-- List-Games.bat          <- double-click to see/remove what's saved
|-- SteamDisplaySelector.bat  <- Steam calls this one automatically; you don't run it yourself
|-- gameslist.json           <- your games, as data
`-- engine/
    |-- Add-Game.ps1
    |-- List-Games.ps1
    |-- SteamDisplaySelector.ps1
    `-- history.json         <- auto-created; your last 2 monitor picks per game
```

| File | Role |
|------|------|
| `SteamDisplaySelector.bat` | Thin launcher Steam calls; sets execution policy and forwards to the engine. |
| `Add-Game.bat` | Double-click launcher for the auto-learn wizard - no manual execution-policy bypass needed. |
| `List-Games.bat` | Double-click launcher to see/remove what's saved. |
| `gameslist.json` | All your games as data. Ships with Helldivers 2 as a worked example. |
| `engine/SteamDisplaySelector.ps1` | The engine: picker -> find-and-swap -> launch. You never edit this to add a game. |
| `engine/Add-Game.ps1` | Auto-learn wizard. Captures snapshots, derives rules, writes `gameslist.json`. |
| `engine/List-Games.ps1` | Prints a clean index of every stored game; can remove one by key. |
| `engine/history.json` | Auto-created. Tracks your last 2 monitor picks per game, shown in the picker. Safe to delete - it just regenerates. |

## gameslist.json schema

```json
{
  "monitorLabels": { "1": "Monitor 1 (Main)", "3": "Monitor 3 (usual swap)" },
  "games": {
    "GAMEKEY": {
      "name": "Display Name",
      "config": "%APPDATA%\\Vendor\\Game\\config.ext",
      "fields": [
        {
          "locator": { "kind": "wrap", "prefix": "Field=", "suffix": "" },
          "anchor": null,
          "lines": { "1": "Field=ValueForMon1", "3": "Field=ValueForMon3" }
        }
      ]
    }
  }
}
```

- **locator.kind `wrap`** - find the line by an invariant `prefix` + `suffix`;
  used for value-changing fields.
- **locator.kind `exact`** - match a whole line; used for present/absent fields.
- **anchor** - for an absent->present field, the line to insert after.
- **lines** - per monitor, the full line text, or `"__ABSENT__"` to remove it.

You normally never hand-edit this; the wizard writes it, and `List-Games.ps1`
is how you inspect it. In practice `fields` stays small per game - it only
holds the lines that actually differ between monitors (typically 1-5), not
the whole config file, even for configs with hundreds of lines total.

## Limits (honest)

This works for any game that saves its monitor choice to an **editable config
file on disk** - the large majority. It will **not** work for games that:

- store the display in the **Windows registry** rather than a file,
- keep it in an **encrypted/opaque binary** blob,
- **re-pick the primary display** at every launch regardless of config, or
- overwrite the file from **cloud sync** after the edit.

If the wizard sees *many* changed lines (timestamps, play counters, window
position), some may be noise - re-capture without changing other settings in
between, and review what it reports before saving.

## License

MIT.
