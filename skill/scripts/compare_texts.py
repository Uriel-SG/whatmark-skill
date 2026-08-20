#!/usr/bin/env python3
"""
Compares two texts in the same language and quantifies how much they diverge.

Meant for: the same content produced through two different paths (written
directly in the target language, vs. written in English and then
translated by a local model), to measure what the translation step changes.

Stdlib only.

Usage:
    python3 compare_texts.py A_direct.txt B_translated.txt
    python3 compare_texts.py A.txt B.txt --labels "Direct" "Translated"
    python3 compare_texts.py A.txt B.txt --json --save report.json
"""

import argparse
import json
import os
import re
import statistics
import unicodedata
from collections import Counter
from pathlib import Path

# Technical terms normally left in English in Italian text.
# Measures whether the translator (improperly) translated them.
ANGLICISMS = {
    "endpoint", "endpoints", "firewall", "threat", "hunting", "detection",
    "rule", "rules", "malware", "ransomware", "phishing", "log", "logs",
    "patch", "patching", "cloud", "server", "client", "network", "backup",
    "alert", "alerts", "payload", "exploit", "bug", "software", "hardware",
    "device", "devices", "tool", "tools", "framework", "dashboard", "query",
    "token", "watermark", "lateral", "movement", "hardening", "compliance",
    "trust", "zero", "privilege", "least", "perimeter", "identity", "access",
}

WORD_RE = re.compile(r"\b[\w'’-]+\b", re.UNICODE)
SENT_RE = re.compile(r"(?<=[.!?])\s+(?=[A-ZÀ-Ü])|\n{2,}")


def workspace():
    """Working folder. See ollama_translate.py for the logic."""
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
        raise SystemExit(f"Could not create {path}: {e}")
    return path


def resolve_in(name):
    p = Path(name)
    if p.exists():
        return p
    alt = workspace() / p.name
    if alt.exists():
        return alt
    raise SystemExit(f"File not found: {name}  (also looked in {workspace()})")


def resolve_out(name):
    p = Path(name)
    return p if (p.is_absolute() or len(p.parts) > 1) else workspace() / p


def tokenize(text):
    return [w.lower() for w in WORD_RE.findall(text)]


def sentences(text):
    return [s.strip() for s in SENT_RE.split(text) if s.strip()]


def ngrams(tokens, n):
    return Counter(tuple(tokens[i:i + n]) for i in range(len(tokens) - n + 1))


def jaccard(c1, c2):
    """Jaccard distance between two sets of n-grams (0 = identical)."""
    s1, s2 = set(c1), set(c2)
    if not s1 and not s2:
        return 0.0
    return 1 - len(s1 & s2) / len(s1 | s2)


def invisible_chars(text):
    """Unicode characters of category Cf: the 'invisible' ones."""
    found = Counter()
    for ch in text:
        if unicodedata.category(ch) == "Cf":
            found[f"U+{ord(ch):04X} {unicodedata.name(ch, '?')}"] += 1
    return dict(found)


def profile(text, label):
    toks = tokenize(text)
    sents = sentences(text)
    slens = [len(tokenize(s)) for s in sents] or [0]
    paras = [p for p in text.split("\n\n") if p.strip()]

    return {
        "label": label,
        "chars": len(text),
        "words": len(toks),
        "unique_words": len(set(toks)),
        "type_token_ratio": round(len(set(toks)) / len(toks), 4) if toks else 0.0,
        "sentences": len(sents),
        "paragraphs": len(paras),
        "sent_len_mean": round(statistics.mean(slens), 2),
        "sent_len_stdev": round(statistics.stdev(slens), 2) if len(slens) > 1 else 0.0,
        "sent_len_max": max(slens),
        "anglicisms": sum(1 for t in toks if t in ANGLICISMS),
        "invisible_chars": invisible_chars(text),
        "_tokens": toks,
    }


def compare(text_a, text_b, label_a="A", label_b="B"):
    pa, pb = profile(text_a, label_a), profile(text_b, label_b)
    ta, tb = pa.pop("_tokens"), pb.pop("_tokens")

    uni_a, uni_b = ngrams(ta, 1), ngrams(tb, 1)
    bi_a, bi_b = ngrams(ta, 2), ngrams(tb, 2)
    tri_a, tri_b = ngrams(ta, 3), ngrams(tb, 3)

    only_a = sorted(set(uni_a) - set(uni_b), key=lambda w: -uni_a[w])
    only_b = sorted(set(uni_b) - set(uni_a), key=lambda w: -uni_b[w])

    def drift(x, y):
        return round((y - x) / x * 100, 1) if x else 0.0

    return {
        "profiles": [pa, pb],
        "divergence": {
            "unigram_jaccard": round(jaccard(uni_a, uni_b), 4),
            "bigram_jaccard": round(jaccard(bi_a, bi_b), 4),
            "trigram_jaccard": round(jaccard(tri_a, tri_b), 4),
        },
        "drift_pct": {
            "words": drift(pa["words"], pb["words"]),
            "sentences": drift(pa["sentences"], pb["sentences"]),
            "sent_len_mean": drift(pa["sent_len_mean"], pb["sent_len_mean"]),
            "type_token_ratio": drift(pa["type_token_ratio"], pb["type_token_ratio"]),
            "anglicisms": drift(pa["anglicisms"], pb["anglicisms"]),
        },
        "vocab_only_in_a": [(w[0], uni_a[w]) for w in only_a[:25]],
        "vocab_only_in_b": [(w[0], uni_b[w]) for w in only_b[:25]],
        "structure_preserved": pa["paragraphs"] == pb["paragraphs"],
    }


def render(r):
    pa, pb = r["profiles"]
    la, lb = pa["label"], pb["label"]
    w = max(len(la), len(lb), 12)

    out = ["=" * 68, "TEXT COMPARISON", "=" * 68,
           f"\n{'metric':<22} {la:>{w}} {lb:>{w}}   delta", "-" * 68]

    for name, key in [
        ("words", "words"),
        ("unique words", "unique_words"),
        ("type-token ratio", "type_token_ratio"),
        ("sentences", "sentences"),
        ("paragraphs", "paragraphs"),
        ("avg. sentence length", "sent_len_mean"),
        ("sentence length stdev", "sent_len_stdev"),
        ("longest sentence", "sent_len_max"),
        ("technical anglicisms", "anglicisms"),
    ]:
        d = r["drift_pct"].get(key)
        ds = f"{d:+.1f}%" if d is not None else ""
        out.append(f"{name:<22} {pa[key]:>{w}} {pb[key]:>{w}}   {ds:>8}")

    d = r["divergence"]
    out += ["\n" + "-" * 68,
            "LEXICAL DIVERGENCE  (0 = identical, 1 = no overlap)",
            "-" * 68,
            f"  unigrams (single words)   : {d['unigram_jaccard']:.4f}",
            f"  bigrams  (pairs)          : {d['bigram_jaccard']:.4f}",
            f"  trigrams (triples)        : {d['trigram_jaccard']:.4f}",
            "\n" + "-" * 68, "EXCLUSIVE VOCABULARY", "-" * 68,
            f"  Only in [{la}]:",
            "    " + ", ".join(f"{x}({n})" for x, n in r["vocab_only_in_a"][:15]),
            f"  Only in [{lb}]:",
            "    " + ", ".join(f"{x}({n})" for x, n in r["vocab_only_in_b"][:15]),
            f"\n  Paragraph structure preserved: "
            f"{'YES' if r['structure_preserved'] else 'NO'}"]

    for p in (pa, pb):
        if p["invisible_chars"]:
            out.append(f"\n  [!] Invisible characters in [{p['label']}]:")
            out += [f"      {k} x{v}" for k, v in p["invisible_chars"].items()]

    out.append("\n" + "=" * 68)
    return "\n".join(out)


def main():
    p = argparse.ArgumentParser(description="Compare two texts.")
    p.add_argument("file_a")
    p.add_argument("file_b")
    p.add_argument("--labels", nargs=2, default=["A", "B"])
    p.add_argument("--json", action="store_true", help="Raw JSON output")
    p.add_argument("--save", metavar="FILE",
                   help="Save the report to the workspace (.json or .txt)")
    args = p.parse_args()

    a = resolve_in(args.file_a).read_text(encoding="utf-8")
    b = resolve_in(args.file_b).read_text(encoding="utf-8")
    r = compare(a, b, *args.labels)

    text = (json.dumps(r, ensure_ascii=False, indent=2) if args.json else render(r))
    print(text)

    if args.save:
        dest = resolve_out(args.save)
        payload = (json.dumps(r, ensure_ascii=False, indent=2)
                   if dest.suffix == ".json" else render(r))
        dest.write_text(payload, encoding="utf-8")
        print(f"\nReport saved -> {dest}")


if __name__ == "__main__":
    main()
