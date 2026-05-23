# Descent

A Godot 4 aircraft landing simulator where players manage throttle, descent rate, and crosswind alignment while receiving real-time telemetry and touchdown scoring.

**[▶ Play in browser](https://YOUR_ITCH_URL)**

## Controls

| Key | Action |
|-----|--------|
| `W / S` | Throttle up / down |
| `↑ / ↓` | Pitch nose down / up |
| `← / →` | Roll |
| `A / D` | Yaw |
| `F` | Toggle flaps |
| `G` | Toggle gear |
| `C` | Switch camera |
| `R` | Restart |

## Run locally

```bash
git clone https://github.com/arunjo5/Descent.git
```

Open `project.godot` in **Godot 4.6+** and press `F5`.

## Architecture

- `Main.gd` — world construction, system wiring
- `AircraftController.gd` — flight model (lift / drag / thrust / gravity / wind)
- `LandingEvaluator.gd` — touchdown detection, outcome classification, scoring
- `WindSystem.gd` — base wind + gusts + crosswind
- `FlightHUD.gd` — telemetry overlay + result panel
