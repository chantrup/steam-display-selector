# Contributing

Thanks for helping grow Steam Display Selector. The most valuable contribution is **adding a new game** so others don't have to do the research themselves.

## Adding a game

You don't write any code or hand-edit a registry file. The wizard learns a game's profile by watching what changes in its config file when you switch monitors.

1. Double-click `Add-Game.bat` (or run `engine\Add-Game.ps1` from PowerShell).
2. Give it a short key, the game's display name, and the path to its display config file.
3. For each monitor you want supported: set the game to that monitor in its own display settings, fully quit, then return to the wizard and press Enter to snapshot.
4. The wizard shows you every line it found different between monitors, with `[likely noise]` / `[looks display-related]` hints and a suggested `k` command. Review the list - some games auto-tune rendering settings (dynamic resolution, VRS, shadow quality) between sessions regardless of monitor, and those will show up too. Prune anything that isn't really about which monitor you picked.
5. Save. The wizard writes the profile straight into `gameslist.json`.

### Submitting your game

Open a pull request that adds your game's entry to `gameslist.json`. Please include in the description:

- **Game name and Steam app ID** (if known)
- **Config path**, with `%APPDATA%` / `%LOCALAPPDATA%` noted rather than your own username baked into the path
- **Which monitors you captured and tested** - if you only have two displays, say so, so others know whether Monitor 3/4 support has actually been verified
- **Anything you excluded during pruning and why** - this helps reviewers sanity-check the profile without having to reproduce your whole capture

### A note on accuracy

The pruning heuristic is a guess based on the *shape* of a value (long decimals tend to be auto-tuned quality settings; field names containing "display"/"monitor"/"screen"/"output" tend to be real). It is not always right. Before submitting, make sure every field you kept actually changes because of monitor choice - not because you changed resolution, graphics settings, or anything else between your two captures. If in doubt, recapture rather than guess.

### Games that won't work with this tool

Some games don't store their monitor choice in an editable config file at all. If you hit one, please still open an issue describing what you found - it helps others avoid the same dead end. Known categories that don't work:

- Settings stored in the **Windows Registry** rather than a file
- **Encrypted or binary** config formats
- Games that **re-pick the primary display** at every launch regardless of any config value
- Games where the config gets **overwritten by cloud sync** after the edit

## Code style

- `gameslist.json` should stay pure data, written by `Add-Game.ps1` - don't hand-edit it in a pull request. If you need to fix something in an existing entry, regenerate it with the wizard rather than editing JSON directly, so the fields stay consistent with what the wizard would actually produce.
- `SteamDisplaySelector.ps1` is the engine: one generic find-and-swap mechanism, no per-game logic. If you find a game whose config format genuinely can't be expressed as "find this line, swap it for that monitor's version" (including "absent" as a valid version), please open an issue describing it rather than special-casing the engine - that's exactly the kind of per-game code path this version was built to avoid.
- `Add-Game.ps1` is the wizard. Changes here should be tested against at least one real game's config file before submitting, ideally one with a tricky encoding (UTF-16, BOM) or a field that gets deleted entirely on one monitor, since those are the cases most likely to break silently.
