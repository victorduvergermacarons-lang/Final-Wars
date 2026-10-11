# Testing multiplayer

Final Wars uses direct-IP co-op: one player **hosts** (and plays), the other
**joins** by IP address. Default port: **7777/UDP**.

## 1. Two instances from the Godot editor (fastest)

Godot can launch several copies of the game with one press of **F5**.

1. Open the project in Godot 4.7.
2. Menu **Debug → Customize Run Instances…**
3. Tick **Enable Multiple Instances** and set the count to **2** (up to 4).
4. In the instance list, give each instance its **launch arguments**:

   | Instance | Arguments |
   |----------|-----------|
   | 1 | `-- --host --name=Alice` |
   | 2 | `-- --join=127.0.0.1 --name=Bob` |

   (The `--` separator is optional; the game reads its flags either way.)
5. Press **F5**. Two windows open: Alice hosts, Bob joins her automatically.
   The windows may open on top of each other; drag one aside.

Leave the arguments empty to get the main menu in both windows instead, then
click **Host Game** in one and **Join Game** (address `127.0.0.1`) in the other.

Available flags: `--solo`, `--host`, `--join=ADDRESS`, `--port=N`, `--name=NAME`.

**Tip:** each window only takes keyboard input while it has focus. Click a window
before moving its hero.

### Things worth trying with two instances

- Walk Bob next to a Wolf so it aggros, face it (tap the direction) and Strike;
  have Alice click Bob's party frame and press Heal: Alice joins the fight (red
  outline = in combat). Or have Alice line up with the Wolf and throw Fireballs.
- Sidestep just before a Wolf bites: it bites where you were (0.3 s reaction).
- Let one hero die: the other can target the body and cast **Resurrect**, or the
  dead player presses **Release** to respawn at the nearest graveyard.
- Pull a Wolf far from its spawn: it evades (heals, untargetable) and walks home.
- Close the host window: the joined player returns to the menu with a message.

## 2. Two computers on the same network (LAN)

1. The host finds their local IP address:
   - Windows: `ipconfig` → "IPv4 Address" (e.g. `192.168.1.23`)
   - macOS: System Settings → Network, or `ipconfig getifaddr en0`
   - Linux: `ip addr`
2. The host clicks **Host Game** (port 7777). If the OS asks whether to allow
   Godot / Final Wars through the firewall, allow it on private networks.
3. The other player enters that address and clicks **Join Game**.

## 3. Over the internet

Direct IP means the joining player must be able to reach the host's port:

- **Port forwarding:** in the host's router, forward **UDP 7777** to the host
  computer's local IP. The joining player uses the host's *public* IP
  (search "what is my IP" on the host's machine).
- **Or a virtual LAN** such as Tailscale or ZeroTier: both players join the
  same virtual network and use the host's virtual IP, with no router changes.

Your own steps feel instant even with latency (they're predicted locally and
corrected by the host); abilities take effect once the host confirms them.

## 4. Automated check (no editor needed)

```bash
GODOT=/path/to/godot tests/net/run_net_check.sh
```

Starts a headless host and three headless clients on localhost (set `PLAYERS=2`
for fewer). Each client joins with its own character, walks four tiles, casts and
saves its hero; the host checks every guest arrived and that each hero leaves the
world cleanly when its player disconnects. Prints `Network check passed.` on
success; logs go to `/tmp/netcheck/`.

## Troubleshooting

| Symptom | Likely cause / fix |
|---------|--------------------|
| "Could not host on port 7777" | Another program (or another host instance) uses the port. Pick another port on both sides. |
| Joiner stays on "Connecting…", then "Could not connect" | Wrong IP, host not running, firewall blocking UDP 7777, or (internet) no port forward. |
| "The game is full." / can't connect to a full game | Up to 4 players (`Net.MAX_PLAYERS`). |
| "The host is using a zone this game doesn't have" | The two copies are different builds. Both players need the same version. |
| Two windows but keys move nothing | Click the window you want to control first. |
| Action bar keys changed unexpectedly | Both instances share `user://settings.cfg`; rebinding in one affects the other next launch. |
