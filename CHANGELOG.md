# Changelog

All notable changes to this project will be documented in this file.

---

## [1.0.0] - 2026-03-13

### Initial Release — LucidNightmareNavigatorEnhanced

This release marks the first independent version of the addon, forked and significantly
enhanced from [LucidNightmareNavigator](https://github.com/Debuggernaut/LucidNightmareNavigator)
by Wonderpants of Thrall.

### Added
- **8×8 grid map** — live visual overview of explored rooms with wall indicators and colored POI markers
- **Grid map auto-refresh** — updates automatically when a new orb or rune is marked
- **Teleport trap detection** — trap room is flagged with a persistent orange marker; navigation routes around it
- **"I just got ported!" button** — immediately marks the trap room and recalculates navigation
- **Map persistence** — progress saved to `SavedVariablesPerCharacter` and reloaded on login
- **Colored POI navigation buttons** — visual found/unfound state for each rune and orb
- **WoW 12.x (The War Within) compatibility** — TOC updated for interface versions 120000/120001
- **MIT License**

### Changed
- Renamed addon from `LucidNightmareNavigator` to `LucidNightmareNavigatorEnhanced`
- Updated TOC: title, author, email, BattleTag, and SavedVariables key
- Rewrote README with full feature list, usage guide, controls, notes, and credits
- Updated `release.sh` to use the new addon name

### Fixed
- Teleport trap handling no longer corrupts the map state
- Removed obsolete XML tag that caused Lua warnings on load

---

## Prior History (Upstream)

For changes prior to this fork, see the original repository:
[github.com/Debuggernaut/LucidNightmareNavigator](https://github.com/Debuggernaut/LucidNightmareNavigator)
