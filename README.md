# Bridge

Klondike Solitaire for LÖVE 11.5, played on a burgundy baize card table. Bridge is the first game in a planned suite of card games. Everything is drawn in code (cards, suits, table, rail), and the only assets are two open-license typefaces.

## Run

```
love .
```

## Play

Build the four foundations up by suit from Ace to King. On the tableau, build down in alternating colours. Only a King can go into an empty column.

| Do this | How |
|---|---|
| Move cards | Drag them, or **click** a card to send it to its best spot |
| Draw | Click the stock, or press **Space** |
| Undo | **U**, **Ctrl+Z**, **Backspace**, or the Undo button |
| Hint | **H**: the suggested card and its destination glow gold |
| Finish | **F** / **Enter** once every card is face up |
| New deal / start this deal over | **N** / **R** |
| Draw 1 ⇄ Draw 3 | **D** (deals a new game) |
| Ledger (statistics) | **S** or **L** |
| Mute, fullscreen | **M**, **F11** |

Every deal has a number, shown on the rail. `R` replays the same shuffle from the beginning.

### Scoring (Windows standard)
| Event | Points |
|---|---|
| Card to foundation | +10 |
| Waste to tableau | +5 |
| Turn over a tableau card | +5 |
| Foundation back to tableau | −15 |
| Recycle the waste (Draw 1) | −100 |
| Recycle the waste (Draw 3), from the 4th pass | −20 |
| Time bonus on a win (games over 30 s) | 700000 ÷ seconds |

The clock starts with your first move and pauses while a panel is open or the window is in the background.

## Develop

```
lovec . --selftest                       # rules tests (2000 random games, undo round-trips, regressions)
lovec . --shot <scenario> [--size WxH]   # render a scripted scene to %APPDATA%/LOVE/bridge/shots/
```

Scenarios: `deal`, `dealing`, `midgame`, `longcolumn`, `drag`, `hint`, `gallery` (all 52 faces and the back), `win` (the cascade), `winpanel`, `stats`.

### Layout
```
src/cards/      card (painting + animation), suits (Bezier meshes), deck, pile
src/games/klondike/
                game (the one move pipeline: canMove/moveCards/drawStock/undo, hints,
                auto-complete, pointer input), tableau/foundation/stock/waste,
                scoring, stats, cascade
src/ui/         theme (palette + fonts), table, decor, hud (the rail), button, panel, sparkle
src/dev/        selftest, capture, fixtures
lib/            LoveLibs (git subtree): scaling, settings, sfx
assets/fonts/   Old Standard TT, IM Fell English SC (SIL OFL 1.1, licences alongside)
```
