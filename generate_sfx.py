"""Procedural SFX Generator for Godot using pyfxr.
Generates retro/arcade sound effects (WAV) directly into assets/audio/.

Usage:
    python generate_sfx.py <preset> <output_path>
    python generate_sfx.py --init-defaults

Presets:
    explosion, jump, hurt, pickup, powerup, laser, tone
"""
import sys
import argparse
from pathlib import Path

try:
    import pyfxr
except ImportError:
    print("Error: pyfxr is not installed. Run: pip install pyfxr")
    sys.exit(1)

PRESETS = {
    "explosion": pyfxr.explosion,
    "jump": pyfxr.jump,
    "hurt": pyfxr.hurt,
    "pickup": pyfxr.pickup,
    "powerup": pyfxr.powerup,
    "laser": pyfxr.laser,
}

DEFAULTS = [
    ("explosion", "assets/audio/sfx/explosion.wav"),
    ("jump", "assets/audio/sfx/jump.wav"),
    ("hurt", "assets/audio/sfx/hurt.wav"),
    ("pickup", "assets/audio/sfx/pickup.wav"),
    ("powerup", "assets/audio/sfx/powerup.wav"),
    ("laser", "assets/audio/sfx/laser.wav"),
]

def generate_sound(preset_name: str, out_path: Path) -> None:
    if preset_name not in PRESETS:
        print(f"Unknown preset '{preset_name}'. Available: {', '.join(PRESETS.keys())}")
        sys.exit(1)

    out_path.parent.mkdir(parents=True, exist_ok=True)
    sound = PRESETS[preset_name]()
    buf = sound.build()
    buf.save(str(out_path))
    print(f"Generated {preset_name} -> {out_path} ({buf.duration:.2f}s)")

def main():
    parser = argparse.ArgumentParser(description="Generate procedural SFX for Godot.")
    parser.add_argument("preset", nargs="?", choices=list(PRESETS.keys()), help="Sound preset")
    parser.add_argument("output", nargs="?", help="Output WAV path (e.g. assets/audio/sfx/jump.wav)")
    parser.add_argument("--init-defaults", action="store_true", help="Generate standard placeholder SFX into assets/audio/sfx/")

    args = parser.parse_args()

    if args.init_defaults:
        print("Generating standard placeholder SFX pack...")
        for p, dest in DEFAULTS:
            generate_sound(p, Path(dest))
        print("Done! Ready to import in Godot.")
        return

    if not args.preset or not args.output:
        parser.print_help()
        sys.exit(1)

    generate_sound(args.preset, Path(args.output))

if __name__ == "__main__":
    main()
