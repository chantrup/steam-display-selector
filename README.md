# Steam Display Selector

**Launch any Steam game on the monitor you choose — without changing your primary display.**

When you click Play, a small prompt asks which monitor to use. Pick one, and the game launches on that display with its renderer initialized correctly from the start.

---

## The problem this solves

If you have multiple monitors, you've probably hit this: a game always opens on your primary monitor, and moving it afterward with `Win + Shift + Arrow` sometimes causes frame drops, stutter, or a blurrier image.

That happens because the game initializes its rendering pipeline (refresh rate, resolution, swap chain) against whatever monitor it launched on. Moving the window afterward doesn't always force it to reinitialize cleanly — so you're left running with settings tuned for the wrong display.

The common "fixes" people are told to use all have downsides:

- **Set the target as your Windows primary monitor** — disrupts your desktop layout, and switching back is inconsistent.
- **Move the window after launch** (manually, or with tools like DisplayFusion) — the renderer is already bound to the original monitor, causing the performance issues above. This also tends to fail for fullscreen games specifically.
- **Big Picture Mode** — works for some setups but is clunky for quick swaps.

Steam has no built-in feature to pick a launch monitor, and most games don't expose a reliable launch parameter for it.

**Steam Display Selector takes a different approach:** it edits the game's own config file *before* the game launches, so the renderer starts on the correct monitor from the very beginning. No primary-monitor switching, no after-the-fact window moving.

---

## How it works

1. You add the script to a game's Steam Launch Options.
2. When you click Play, Steam runs the script first.
3. The script asks which monitor you want (1–4), or press Enter to keep your current config.
4. It edits the game's config file to point at that monitor.
5. It hands off to Steam, and the game launches on the correct display.

---

## Files

This tool is **three files**, which must all live in the **same folder**:

| File | Purpose |
|------|---------|
| `SteamDisplaySelector.bat` | The engine. Contains all the script logic. You shouldn't need to edit this. |
| `games.bat` | The game registry. A plain list of per-game settings. This is the file you'll actually edit when adding a game. |
| `xmlfield.ps1` | A helper script used only by games that store their monitor setting as an XML attribute (e.g. Crimson Desert). Required for those games; harmless if unused. |

Keeping the registry in its own file means you never have to scroll through script logic to add a game — `games.bat` is just a clean, readable list.

---

## Requirements

- Windows
- Steam
- A game that stores its monitor/display selection in an editable config file (most do)

---

## Setup

1. **Download all three files** (`SteamDisplaySelector.bat`, `games.bat`, `xmlfield.ps1`) and save them together in the same folder, e.g. `C:\Users\YourName\Documents\SteamDisplaySelector\`.

2. **Add your game to `games.bat`** (see [Adding a game](#adding-a-game) below). A few popular games are included as working examples.

3. **Set the Steam Launch Option** for your game:
   - Right-click the game in Steam → **Properties** → **General** → **Launch Options**
   - Enter: `"C:\Path\To\SteamDisplaySelector.bat" GAMEKEY %command%`
   - Replace the path with where you saved the files, and `GAMEKEY` with the key you defined in `games.bat`.

4. **Click Play.** Pick your monitor when prompted.

---

## Adding a game

Every game stores its display setting differently, so adding one means finding three things and adding a few lines to **`games.bat`**.

The script supports three config formats:

### `plain`
For plain-text config files where the monitor is a simple number.
Example: `fullscreen_output = 0`

```
set CONFIG_MYKEY=C:\Users\YourName\AppData\Roaming\...\settings.cfg
set FIELD_MYKEY=fullscreen_output
set FILETYPE_MYKEY=plain
```

Monitor values are 0-based: Monitor 1 = `0`, Monitor 2 = `1`, etc.

### `utf16`
For UTF-16 encoded XML config files where the monitor is a number.
Example: `<OutputMonitor>0</OutputMonitor>`

```
set CONFIG_MYKEY=C:\Users\YourName\AppData\Roaming\...\GraphicsConfig.xml
set FIELD_MYKEY=OutputMonitor
set FILETYPE_MYKEY=utf16
```

> **How to tell if a file is UTF-16:** open it in Notepad. If it looks normal, it's `plain`. If it looks garbled or full of strange characters, it's `utf16`.

### `string-multi-field`
For games where one or more fields need to change when switching monitors — a monitor name, a display index, a resolution, or a combination. Each monitor gets one line listing all fields to update, separated by semicolons.

Single field:
```
set TARGET_MYKEY_1=TargetDisplay=1:YourMonitorName
```

Multiple fields (commas inside values escaped with `^`):
```
set TARGET_MYKEY_1=DisplayName=Monitor1Name;FullScreenDisplayMode=464;NormalWindowResolution=(2560^,1440)
```

**Deleting a field** — some games remove a field entirely when set to their default/primary monitor, rather than writing an explicit value. Use `DELETE` as the value for that monitor:
```
set TARGET_MYKEY_1=_display=DELETE
set TARGET_MYKEY_3=_display=YourMonitorName 0
```

**XML attribute fields** — if a field's name starts with an underscore (like `_display` above), the script treats it as an XML attribute-style field (e.g. `<OptionStringVector Name="_display" _value="..."/>`) and edits it via the included `xmlfield.ps1` helper. This only applies to underscore-prefixed field names; everything else is treated as a plain `Field=Value` line.

```
set CONFIG_MYKEY=C:\...\config.ini
set FILETYPE_MYKEY=string-multi-field
set TARGET_MYKEY_1=...
set TARGET_MYKEY_3=...
```

### Finding the config file and field

1. Search the web for `"[Game Name] config file location monitor Windows"`. Config files commonly live in `%APPDATA%`, `%LOCALAPPDATA%`, or the game's install folder.
2. Open the config in Notepad (or a code editor).
3. Change the monitor in the game's own settings, switch to a different monitor, quit, and re-open the config. Whatever field changed is the one you need.
4. **Verify the indexing** by editing the value manually and launching the game to confirm which monitor it opens on before trusting the script with it.
5. If you suspect a field disappears entirely on a particular monitor (rather than changing value), test that explicitly — switch back to that monitor in-game, quit, and check whether the field is gone. If so, use `DELETE` for that monitor's entry.

> The included games (Helldivers 2, Elden Ring Nightreign, Monster Hunter Wilds, Pragmata, Crimson Desert) use **one user's** specific config paths and monitor names as real-world examples. Replace those values with your own paths and monitor names.

---

## Included examples

| Game | Format | Notes |
|------|--------|-------|
| Helldivers 2 | `plain` | Single numeric field |
| Elden Ring Nightreign | `utf16` | UTF-16 encoded XML |
| Pragmata | `string-multi-field` | Single `index:name` field |
| Monster Hunter Wilds | `string-multi-field` | Five fields incl. resolution |
| Crimson Desert | `string-multi-field` | XML attribute field, uses `DELETE` for its default monitor |

These cover all current formats, so most new games can be added by following the closest matching example.

---

## How this compares to window-moving tools (e.g. DisplayFusion)

Tools like DisplayFusion can move a game's window to a specific monitor using triggers that fire on window creation. This works for windowed games, but its own documentation acknowledges it struggles with fullscreen games specifically, since many fullscreen titles force themselves to the primary monitor and can't be moved, or don't send the window-creation event the trigger needs at all.

That's the same underlying problem this tool exists to avoid: moving a window *after* launch doesn't undo the fact that the game's renderer already initialized against the wrong monitor's refresh rate, resolution, and swap chain. Steam Display Selector edits the game's config *before* launch instead, so the renderer initializes correctly the first time — no window-moving involved.

---

## Contributing

This tool gets more useful the more games are documented. If you work out the config details for a game that isn't listed, contributions are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md).

If a game uses a config format none of the three handlers support, open an issue describing what changes in the config when you switch monitors, and it can potentially be added as a new format.

---

## Support

If this saved you some time, you can support the project here:
**[GitHub Sponsors / Ko-fi link — add your link]**

---

## License

MIT — see [LICENSE](LICENSE). Free to use, modify, and share.

Created by **BChan**.
