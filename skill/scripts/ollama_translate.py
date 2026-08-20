#!/usr/bin/env python3
"""
Translates a text by calling a local model served by Ollama.

Stdlib only: nothing to install.
Ollama exposes an HTTP API on localhost:11434 - no SDK needed.

Usage:
    python3 ollama_translate.py input.txt -o B_translated.txt --target italian
    cat input.txt | python3 ollama_translate.py - --target italian
"""

import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

DEFAULT_HOST = "http://127.0.0.1:11434"
DEFAULT_MODEL = "mistral"

PROMPT = """You are a professional translator. Translate the text below into {target}.

Rules:
- Translate the MEANING, not word by word.
- Keep established English technical terms untranslated when that is the
  convention in the target language (e.g. in IT security: endpoint, threat
  hunting, detection rule, lateral movement, firewall, zero trust).
- Preserve paragraph breaks and any markdown formatting.
- Output ONLY the translation. No preamble, no notes, no explanation.

Text to translate:
---
{text}
---"""


def workspace():
    """
    Working folder where all produced files land.

    Priority: the WHATMARK_DIR environment variable, otherwise the
    platform default. Created if it doesn't exist.
    """
    env = os.environ.get("WHATMARK_DIR")
    if env:
        path = Path(env)
    elif os.name == "nt":
        path = Path("C:/ClaudeText")
    else:
        path = Path.home() / "ClaudeText"

    try:
        path.mkdir(parents=True, exist_ok=True)
    except OSError as e:
        raise SystemExit(
            f"Could not create the working folder {path}: {e}\n"
            f"Set an alternative path with the WHATMARK_DIR environment variable."
        )
    return path


def resolve_out(name):
    """A plain name lands in the workspace; an explicit path does not."""
    p = Path(name)
    return p if (p.is_absolute() or len(p.parts) > 1) else workspace() / p


def resolve_in(name):
    """Look for the file where indicated, otherwise in the workspace."""
    p = Path(name)
    if p.exists():
        return p
    alt = workspace() / p.name
    if alt.exists():
        return alt
    raise SystemExit(f"File not found: {name}  (also looked in {workspace()})")


def check_ollama(model, host=DEFAULT_HOST):
    """Check that Ollama is responding and that the model is present."""
    try:
        with urllib.request.urlopen(f"{host}/api/tags", timeout=10) as resp:
            tags = json.loads(resp.read().decode("utf-8"))
    except urllib.error.URLError as e:
        raise SystemExit(
            f"Ollama not reachable at {host}: {e}\n"
            f"Start it with:  ollama serve"
        )

    available = [m["name"] for m in tags.get("models", [])]
    if not any(a == model or a.startswith(f"{model}:") for a in available):
        raise SystemExit(
            f"Model '{model}' not present in Ollama.\n"
            f"Available: {', '.join(available) or '(none)'}\n"
            f"Install it with:  ollama pull {model}"
        )


def translate(text, target, model=DEFAULT_MODEL, host=DEFAULT_HOST,
              temperature=0.3, timeout=900):
    """Send the text to Ollama and return the translation."""
    payload = {
        "model": model,
        "prompt": PROMPT.format(target=target, text=text),
        "stream": False,
        "options": {"temperature": temperature},
    }

    req = urllib.request.Request(
        f"{host}/api/generate",
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )

    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            body = json.loads(resp.read().decode("utf-8"))
    except urllib.error.URLError as e:
        raise SystemExit(f"Error calling Ollama: {e}")
    except TimeoutError:
        raise SystemExit(
            f"Timed out after {timeout}s. The model might be too large "
            f"for this machine, or the text too long."
        )

    out = body.get("response", "").strip()
    if not out:
        raise SystemExit("Ollama responded but the translation is empty.")
    return out


def main():
    p = argparse.ArgumentParser(description="Translate a text via Ollama.")
    p.add_argument("input", nargs="?", help="Input file, or '-' for stdin")
    p.add_argument("-o", "--output", help="Output file (default: stdout)")
    p.add_argument("--target", default="italian", help="Target language")
    p.add_argument("--model", default=DEFAULT_MODEL, help="Ollama model")
    p.add_argument("--host", default=DEFAULT_HOST, help="Ollama URL")
    p.add_argument("--temperature", type=float, default=0.3)
    p.add_argument("--workspace", action="store_true",
                   help="Print the working folder and exit")
    args = p.parse_args()

    if args.workspace:
        print(workspace())
        return

    if not args.input:
        raise SystemExit("Missing input file. Use '-' to read from stdin.")

    text = (sys.stdin.read() if args.input == "-"
            else resolve_in(args.input).read_text(encoding="utf-8"))

    if not text.strip():
        raise SystemExit("Empty input.")

    check_ollama(args.model, args.host)
    result = translate(text, args.target, args.model, args.host, args.temperature)

    if args.output:
        dest = resolve_out(args.output)
        dest.write_text(result + "\n", encoding="utf-8")
        print(f"Translated -> {dest}  ({len(result.split())} words)", file=sys.stderr)
    else:
        print(result)


if __name__ == "__main__":
    main()
