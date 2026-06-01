#!/usr/bin/env python3
"""Command helper for the Codex traffic light."""

from __future__ import annotations

import argparse
import json
import time
from pathlib import Path


APP_DIR = Path(__file__).resolve().parent
STATE_FILE = Path.home() / "Library" / "Application Support" / "CodexTrafficLight" / "state.json"
STATES = {"working", "done", "waiting", "idle", "quit"}


def ensure_runtime() -> None:
    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)


def write_state(state: str) -> None:
    if state not in STATES:
        raise SystemExit(f"Unknown state: {state}")
    ensure_runtime()
    payload = {"state": state, "updated_at": time.time()}
    STATE_FILE.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")


def read_state() -> str:
    try:
        payload = json.loads(STATE_FILE.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return "idle"
    except Exception:
        return "idle"
    state = payload.get("state", "idle")
    return state if state in STATES else "idle"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Codex traffic light command helper")
    parser.add_argument("command", choices=[*sorted(STATES), "status"], help="State command")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.command == "status":
        print(read_state())
        return 0
    write_state(args.command)
    print(args.command)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
