"""Effect definitions drawn in code (stance rework phase 4, 2026-11-23): ribbons,
fronts and tile effects (content/effects/<name>.tres). Written only when missing;
edit the .tres files afterwards. Run from the project root:
python3 tools/once/make_code_effects.py
"""
import os

# field -> value (GDScript literal); "sheet" names a PNG in assets/effects/.
R = dict
DEFS = {
    # Ribbons. Path: 0 line, 1 whip, 2 figure 8, 3 coil.
    "water_whip_ribbon": R(sheet="water_whip_strip", ribbon="true", path=1, tip_fx='&"water_whip_tip"',
                           impact_fx='&"water_impact"', curl=0.9, fps=24.0, extend_frames=7, snap_frame=7,
                           retract_frames=6, hit_frame=7),
    "fire_whip_ribbon": R(sheet="fire_whip_strip", ribbon="true", path=1, tip_fx='&"fire_whip_tip"',
                          impact_fx='&"fire_whip_impact"', curl=0.8, fps=24.0, extend_frames=6, snap_frame=6,
                          retract_frames=6, hit_frame=6),
    "fire_stream": R(sheet="fire_whip_strip", ribbon="true", path=0, thickness=2, scroll_speed=60.0,
                     head_fx='&"fire_stream_head"', hand_fx='&"fire_stream_burst"', impact_fx='&"fire_stream_impact"',
                     loop="true"),
    "water_jet": R(sheet="water_whip_strip", ribbon="true", path=0, thickness=2, scroll_speed=80.0,
                   head_fx='&"water_jet_head"', impact_fx='&"water_jet_impact"', loop="true"),
    "leeching_tide_ribbon": R(sheet="water_whip_strip", ribbon="true", path=0, thickness=2, scroll_speed=-60.0,
                              tint="Color(0.45, 0.55, 0.95, 1)", impact_fx='&"leech_target"', hand_fx='&"leech_self"',
                              hold_seconds=0.9, fade_out="true"),
    "metal_cable_ribbon": R(sheet="metal_cable_strip", ribbon="true", path=0, impact_fx='&"cable_sparks"',
                            hold_seconds=0.8, fade_out="true"),
    "lightning_bolt": R(sheet="lightning_strip", ribbon="true", path=0, jag_seconds=0.05, jag_amount=0.25,
                        hand_fx='&"lightning_fingers"', impact_fx='&"lightning_strike"', hold_seconds=0.45,
                        fade_out="true"),
    "lightning_redirect": R(sheet="lightning_strip", ribbon="true", path=2, jag_seconds=0.05, jag_amount=0.08,
                            hand_fx='&"lightning_fingers"', hold_seconds=1.2, fade_out="true"),
    "fire_dragon": R(sheet="fire_whip_strip", ribbon="true", path=3, scroll_speed=40.0,
                     head_fx='&"fire_stream_head"', loop="true"),
    "air_blade_trail_ribbon": R(sheet="air_blade_trail", ribbon="true", path=0, alpha=0.6, loop="true"),
    # Fronts (the piece is head_fx).
    "breath_of_fire": R(front="true", head_fx='&"breath_front"', trail_fx='&"breath_front"', blocked_fx='&"breath_blocked"',
                        front_speed=9.0, trail_fade_seconds=0.35, hold_seconds=1.0),
    "tidal_wave_front": R(front="true", head_fx='&"tidal_front"', front_speed=6.0, wets="true", hold_seconds=1.6),
    "water_pulse_front": R(front="true", head_fx='&"pulse_front"', blocked_fx='&"pulse_blocked"', front_speed=9.0,
                           wets="true", hold_seconds=1.0),
    "gust_wind": R(front="true", head_fx='&"gust_front"', front_speed=12.0, hold_seconds=0.7),
    "air_blast_wind": R(front="true", head_fx='&"gust_front"', front_speed=12.0, piece_scale=2, hold_seconds=0.7),
    # Tiles and the screen. Mode: 1 wet, 2 burning, 3 sand, 4 ring, 5 cracks, 6 sandstorm, 7 sense, 8 rain.
    "wet_ground": R(tile_mode=1, tile_tint="Color(0.12, 0.28, 0.5, 0.35)", tile_seconds=4.0),
    "burning_ground": R(tile_mode=2, head_fx='&"inferno_flames"', loop="true"),
    "sinkhole_sand": R(tile_mode=3, tile_tint="Color(0.86, 0.72, 0.45, 0.5)", tile_seconds=6.0),
    "stomp_ring": R(tile_mode=4, front_speed=6.0, tile_seconds=1.0),
    "quake_cracks": R(tile_mode=5, tile_tint="Color(0.08, 0.06, 0.05, 0.75)", tile_seconds=4.0),
    "sandstorm": R(tile_mode=6, tile_tint="Color(0.82, 0.66, 0.4, 0.22)", tile_seconds=6.0),
    "seismic_sense": R(tile_mode=7, front_speed=8.0, tile_seconds=6.0),
    "healing_rain": R(tile_mode=8, tile_tint="Color(0.65, 0.85, 1, 0.75)", tile_seconds=5.0),
}


def main():
    for name, d in DEFS.items():
        path = f"content/effects/{name}.tres"
        if os.path.exists(path):
            continue
        sheet = d.pop("sheet", None)
        lines = ['[gd_resource type="Resource" script_class="FxDef" format=3]', "",
                 '[ext_resource type="Script" path="res://data/defs/fx_def.gd" id="1_fx"]']
        if sheet:
            lines.append(f'[ext_resource type="Texture2D" path="res://assets/effects/{sheet}.png" id="2_sheet"]')
        lines += ["", "[resource]", 'script = ExtResource("1_fx")', f'id = &"{name}"']
        if sheet:
            lines.append('sheet = ExtResource("2_sheet")')
        if sheet:
            from PIL import Image
            w, h = Image.open(f"assets/effects/{sheet}.png").size
            lines.append(f"frame_size = Vector2i({w}, {h})")
        lines += ["frames = 1", "rotate = false"]
        d.setdefault("fps", 12.0)
        for k, v in d.items():
            lines.append(f"{k} = {v}")
        with open(path, "w") as f:
            f.write("\n".join(lines) + "\n")
        print("wrote", path)


if __name__ == "__main__":
    main()
