# Contributing

Thanks for helping grow Steam Display Picker. The most valuable contribution is **documenting a new game** so others don't have to do the research themselves.

## Adding a game

The cleanest way to contribute a game is to open an issue or pull request with the following details:

1. **Game name**
2. **Config file location** (full path, with `%APPDATA%` / `%LOCALAPPDATA%` / install-folder noted)
3. **Which format it uses** — `plain`, `utf16`, or `string-multi-field`
4. **Which field(s) change** when you switch monitors
5. **The indexing** — does monitor selection start at 0 or 1?
6. **A sample registry block** in the same style as the existing examples

### How to find this information

1. Launch the game and set it to one monitor in its own display settings. Quit.
2. Open the config file in Notepad and note the relevant values.
3. Switch the game to a different monitor in its settings. Quit.
4. Re-open the config and compare — whatever changed is what the script needs to edit.
5. Confirm the indexing by editing the value by hand and launching to verify which monitor it opens on.

### A note on multi-field games

Some games (especially RE Engine titles) rewrite several fields when switching monitors — a display name, a mode index, a resolution, sometimes in more than one section of the file. If you see more than one field change, list **all** of them. The `string-multi-field` format handles multiple fields separated by semicolons.

## New config formats

If a game stores its monitor setting in a way none of the three formats handle (for example, in the Windows Registry rather than a file, or in a binary format), please open an issue describing exactly what changes when you switch monitors. New format handlers can be added to the script.

## Code style

The script is plain Windows batch with PowerShell one-liners for file editing. Keep the **GAME REGISTRY** section readable, with one commented block per game including its Steam Launch Option line, matching the existing entries.
