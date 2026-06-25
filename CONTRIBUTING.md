# Contributing

Thanks for helping grow Steam Display Selector. The most valuable contribution is **documenting a new game** so others don't have to do the research themselves.

## Adding a game

All per-game settings live in **`games.bat`** — not in the main `SteamDisplaySelector.bat` script. The cleanest way to contribute a game is to open an issue or pull request with the following details:

1. **Game name**
2. **Config file location** (full path, with `%APPDATA%` / `%LOCALAPPDATA%` / install-folder noted)
3. **Which format it uses** — `plain`, `utf16`, or `string-multi-field`
4. **Which field(s) change** when you switch monitors
5. **The indexing** — does monitor selection start at 0 or 1?
6. **A sample registry block** for `games.bat`, in the same style as the existing examples

### How to find this information

1. Launch the game and set it to one monitor in its own display settings. Quit.
2. Open the config file in Notepad and note the relevant values.
3. Switch the game to a different monitor in its settings. Quit.
4. Re-open the config and compare — whatever changed is what the script needs to edit.
5. Confirm the indexing by editing the value by hand and launching to verify which monitor it opens on.
6. Check the field still exists after switching back to the *first* monitor too — some games delete a field entirely when set to their default/primary monitor instead of writing an explicit value. If that happens, use `DELETE` as that monitor's value (see `string-multi-field` notes below).

### A note on multi-field games

Some games (especially RE Engine titles) rewrite several fields when switching monitors — a display name, a mode index, a resolution, sometimes in more than one section of the file. If you see more than one field change, list **all** of them. The `string-multi-field` format handles multiple fields separated by semicolons.

### A note on XML attribute fields

Some games (e.g. Crimson Desert) store their monitor field as an XML attribute, like:
```xml
<OptionStringVector Name="_display" _value="MonitorName 0"/>
```
rather than a plain `Field=Value` line. The script detects this automatically when the field name starts with an underscore, and edits it using the included `xmlfield.ps1` helper instead of a plain text replace. If you're contributing a game like this, name the field with its leading underscore exactly as it appears in the config (e.g. `_display`), and make sure your pull request notes that `xmlfield.ps1` is required.

## New config formats

If a game stores its monitor setting in a way none of the three formats handle (for example, in the Windows Registry rather than a file, or in a binary format), please open an issue describing exactly what changes when you switch monitors. New format handlers can be added to the script.

## Code style

- `games.bat` should stay pure data — one commented block per game, each with its Steam Launch Option line, matching the existing entries. No script logic belongs in this file.
- `SteamDisplaySelector.bat` contains the engine logic. Changes here should be tested carefully — this project has previously hit subtle bugs from batch's handling of `call set` double-expansion, case sensitivity, and nested quotes/escaping with `<` `>` characters. When in doubt, prefer moving complex logic into a dedicated `.ps1` helper file (like `xmlfield.ps1`) rather than cramming it into an inline batch `-Command` string.
