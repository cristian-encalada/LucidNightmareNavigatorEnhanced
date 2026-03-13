# Lucid Nightmare Navigator Enhanced

A World of Warcraft addon that helps you navigate the **Endless Halls** maze required to obtain the [Lucid Nightmare](https://www.wowhead.com/guides/lucid-nightmare-secret-mount#seventh-note-endless-halls) secret mount.

## Features

- **8×8 grid map** — live visual overview of your explored rooms, updated automatically as you discover runes and orbs
- **Turn-by-turn navigation** — guides you to the nearest unexplored territory, any marked rune or orb, or the teleport trap room
- **Wall marking** — click the cardinal direction buttons at the top to mark blocked corridors in each room
- **Teleport trap handling** — marks the trap room on the map, navigation avoids it, and a dedicated button lets you route back to it
- **Map persistence** — your progress is saved across sessions and reloaded automatically on login
- **Map export / import** — serialize your map to a text box for backup or sharing

## How to Use

1. Enter the Endless Halls and open the addon window
2. Walk around normally — the addon tracks your position and builds the map as you move
3. When you discover a rune or orb, click the matching colored button in the **Points of Interest** panel
4. Use the **Navigation Target** buttons to get step-by-step directions to any POI or unexplored area
5. If you get teleported by the trap room, click **"I just got ported!"** immediately
6. Open the **Grid Map** at any time for a bird's-eye view of your progress

## Credits

This addon is a fork and significant enhancement of [LucidNightmareNavigator](https://github.com/Debuggernaut/LucidNightmareNavigator) by **Wonderpants of Thrall** (Bernycinders-Thrall, USA), which was itself loosely based on the original **LNH** by **Vildiesel** (EU - Well of Eternity) and further developed by contributors including **Saregon** and **Ray**.

The Endless Halls map visualization was inspired by the web tool at [nightswimmer.github.io/EndlessHalls](https://nightswimmer.github.io/EndlessHalls).

### Enhancements in this fork

- 8×8 grid map with live room layout, wall indicators, and colored POI markers
- Grid map auto-refreshes when a new orb or rune is marked
- Teleport trap detection and persistent orange marking
- Map saved to `SavedVariablesPerCharacter` and reloaded on login
- Colored POI navigation buttons with found/unfound state
- WoW 12.x (The War Within) compatibility

## Issues & Contributions

Bug reports and pull requests are welcome. Please open an issue on the project repository.
