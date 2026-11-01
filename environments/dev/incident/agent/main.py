from pathlib import Path

instructions = (Path(__file__).parent / "instructions.txt").read_text(encoding="utf-8")
