---
name: whatmark
description: Comparative experiment on what changes when a text goes through machine translation. Generates the same content through two independent paths (written directly in the target language, vs. written in English and translated by a local model via Ollama), then quantifies their lexical and structural divergence with measurable metrics. Use this skill when the user wants to compare machine translation with direct writing, study a translator's artifacts, measure how much two texts in the same language diverge, analyze the stylistic tics of a local model, or evaluate which path produces better prose.
---

# WhatMark?

Two observations of the same object from different positions produce a
measurable shift. Here the object is a piece of content, the two positions
are two production paths, and the shift is measured in lexical metrics.

- **Path A** — the text written directly in the target language.
- **Path B** — the same content written in English, then translated by a
  local model served by Ollama.

The output isn't the two texts: it's **the analysis of their difference**.

## Prerequisites

Ollama running with at least one model. Check before starting:

```bash
curl -s http://127.0.0.1:11434/api/tags
```

If it doesn't respond, start Ollama. If the model is missing:
`ollama pull mistral`. Don't install anything without asking the user for
confirmation.

## Paths and interpreter

The scripts live in `scripts/` **inside this skill**, not in the user's
working directory. Resolve the skill's absolute path before running them.

The produced files, however, land in the **workspace**: `C:\ClaudeText` on
Windows, `~/ClaudeText` elsewhere, or the path in `WHATMARK_DIR`. The
scripts create it themselves and resolve simple names inside it, so just
pass `A_direct.txt` with no path.

Interpreter: `py` on Windows, `python3` on macOS and Linux.
In the examples below, `<SKILL>` is this folder's absolute path and `<PY>`
is the correct interpreter.

## Step order: don't reverse it

The direct text must be written **before** the English one. If you write
the English version first, the target-language text you produce right
after is anchored to what's already in context: you'd be comparing two
translations, not a translation against genuine writing.

For a truly clean test, produce the two texts in separate sessions starting
from the same written brief.

## Procedure

### 1. Agree on the brief

Ask for topic, approximate length, target language, and tone.
Write a 2-3 line brief and get it confirmed: it will be used **verbatim**
for both paths. It's the only variable that must stay fixed for the
experiment to make sense.

Save it as `brief.txt` in the workspace.

### 2. Path A — direct writing

Write the text in the target language following the brief.
Save it as `A_direct.txt` in the workspace.

### 3. Path B — English, then translation

Write the **same** content in English, from the same brief.
Save it as `B_source_en.txt` in the workspace.

Translate it with the local model:

```bash
<PY> "<SKILL>/scripts/ollama_translate.py" B_source_en.txt \
    -o B_translated.txt --target italian --model mistral
```

Options: `--model` (any model in Ollama), `--target` (language),
`--temperature` (default 0.3, low for translation).

### 4. Analysis

```bash
<PY> "<SKILL>/scripts/compare_texts.py" A_direct.txt B_translated.txt \
    --labels "Direct" "Translated" --save report.txt
```

Add `--json` for structured output.

### 5. Interpret

Don't just print the table. Comment on what the numbers say:

| Metric | What it reveals |
|---|---|
| **Unigram Jaccard** | how much vocabulary they share. High = the translator chose different words |
| **Bigram/trigram Jaccard** | how much the *syntax* changed. Always grows relative to unigrams: if it grows a lot, the translator restructured the sentences, not just swapped words |
| **type-token ratio** | lexical richness. A drop in the translated text = flattened vocabulary |
| **avg. sentence length** | translators tend to lengthen sentences: they spell out what the original left implicit |
| **sentence length stdev** | rhythmic variety. A drop = more monotone prose |
| **technical anglicisms** | how many English terms the translator translated when it shouldn't have. In the IT domain this is the most diagnostic indicator |
| **exclusive vocabulary** | the translator's concrete word choices. The most readable part at a glance |

Close with a qualitative verdict: which of the two texts is better, where
the translator lost register or precision, whether the structure held up.

## Variants

- **Comparing models** — same `B_source_en.txt`, translated by different
  models (`--model mistral`, `--model llama3.2`, `--model qwen2.5`).
  Compare the translations against each other: each one's tics emerge.
- **Temperature effect** — same translation at `--temperature 0.1` and `0.9`.
- **Background noise** — translate twice with identical parameters and
  compare the two outputs. The residual divergence is pure sampling noise,
  and gives you the threshold below which any other result is irrelevant.
  Do this first: without that number you can't interpret the others.
- **Round-trip** — IT to EN to IT, compared against the Italian original.
  Measures how much meaning survives a full round trip.

## Notes

Python 3.10+ stdlib only, no dependencies.
`ollama_translate.py` talks to Ollama's HTTP API on `127.0.0.1:11434`:
no SDK needed, it's a POST with a JSON payload.
