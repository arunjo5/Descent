# Descent

A Godot 4 aircraft landing simulator where players manage throttle, descent rate, and crosswind alignment while receiving real-time telemetry and touchdown scoring.

<img width="700" alt="Screenshot 2026-05-22 at 10 52 40 PM" src="https://github.com/user-attachments/assets/cc853f66-0e60-4491-83d6-f242e8d0142e" />

**[▶ Play in browser](https://aj864.itch.io/descent)**

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
| `T` | Cycle time of day (Dawn / Day / Dusk / Night) |
| `Y` | Cycle weather (Clear / Rain / Snow / Fog) |
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
