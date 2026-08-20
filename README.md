<div align="center">

<!-- Replace with your own logo -->
<img src="assets/logo.png" alt="WhatMark?" width="160">

# WhatMark?

**How much does a text change when it goes through machine translation?**

A controlled experiment, with numbers instead of impressions.

[![Python](https://img.shields.io/badge/python-3.10%2B-blue)](https://www.python.org/)
[![Agent Skill](https://img.shields.io/badge/Claude-Agent%20Skill-8A63D2)](https://code.claude.com/docs/en/skills)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux%20%7C%20macOS-lightgrey)]()
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Dependencies](https://img.shields.io/badge/dependencies-none-brightgreen)]()

</div>

---

## What it is

WhatMark? is an **Agent Skill for Claude Code** that runs a controlled
linguistic experiment: it produces the same content through two independent
paths and measures how much they diverge.

```
                    ┌─────────────────────────┐
      brief ───────►│  A · direct writing     │───► A_direct.txt ──┐
        │           └─────────────────────────┘                     │
        │                                                           ▼
        │           ┌─────────────────────────┐              ┌─────────────┐
        └──────────►│  B · English            │              │   ANALYSIS  │
                    │      ↓ Ollama/Mistral   │───► B_translated.txt │ metrics │
                    │      translation        │              └─────────────┘
                    └─────────────────────────┘                     │
                                                                    ▼
                                                              report.txt
```

The idea borrows from parallax: two observations of the same object from
different positions produce a measurable shift. Here the object is a piece
of content, the positions are two production paths, and the shift is
measured in lexical and structural metrics.

**The output isn't the two texts. It's the analysis of their difference.**

## What it's for

- Understanding **what gets lost** in machine translation compared to direct writing
- Comparing **different translators** on the same source text and spotting their tics
- Measuring the effect of **temperature** and other sampling parameters
- Establishing the **background noise** of a local model: how much it varies across identical runs
- Studying **translation artifacts** in a specific technical domain

> **Note:** translation performed by Mistral completely breaks the watermark.

---

## Requirements

| Component | Version | Notes |
|---|---|---|
| Python | 3.10+ | stdlib only, nothing to install |
| [Claude Code](https://code.claude.com) | 2.1.3+ | required: it's what invokes the skill via `/whatmark` |
| [Ollama](https://ollama.com) | any | installed by the script if missing |
| Model | `mistral` (~4.4 GB) | or any other Ollama model |

Everything runs **locally**. No external API, no key, no data leaving the
machine other than the requests you make to Claude Code yourself.

### Disk space: it adds up more than it looks

Don't underestimate this: **Ollama itself is not lightweight**. On Windows,
the installed app alone takes up about **3 GB** (almost all GPU acceleration
libraries under `lib/`), plus another ~1.5 GB of application data under
`%LOCALAPPDATA%` — **~4.5 GB for Ollama alone**, before pulling any model.
The default `mistral` model adds another **~4.4 GB** on top of that.

| Item | Measured size |
|---|---|
| Ollama (application) | ~3 GB (Windows: `%LOCALAPPDATA%\Programs\Ollama`) |
| Ollama (application data) | ~1.5 GB (Windows: `%LOCALAPPDATA%\Ollama`) |
| `mistral` model | ~4.4 GB (confirmed via `ollama list`) |
| **Realistic total** | **~9 GB** |

Numbers on Linux/macOS may vary (depends on which GPU backends get pulled
in), but are in the same order of magnitude. **Make sure you have at least
10 GB free before running the installer** — if you pick a model other than
`mistral`, check its size on [ollama.com/library](https://ollama.com/library)
before pulling it.

## Installation

### One-liner

Downloads and runs the installer on its own (including the rest of the
repository) — open your shell **as Administrator** and paste:

**Windows** (PowerShell):

```powershell
irm https://raw.githubusercontent.com/Uriel-SG/whatmark-skill/main/install.ps1 | iex
```

**Linux / macOS** (bash):

```bash
curl -fsSL https://raw.githubusercontent.com/Uriel-SG/whatmark-skill/main/install.sh | bash
```

Neither one requires cloning the repository by hand: if they don't find
themselves already inside a checkout, they download one on their own to
`~/whatmark-skill` (or `%USERPROFILE%\whatmark-skill` on Windows) before
proceeding with the steps described below.

### Windows (manual)

```powershell
git clone https://github.com/Uriel-SG/whatmark-skill.git
cd whatmark-skill
.\install.ps1
```

If PowerShell blocks the script:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\install.ps1
```

### Linux / macOS (manual)

```bash
git clone https://github.com/Uriel-SG/whatmark-skill.git
cd whatmark-skill
./install.sh
```

### What the installer does

1. Asks upfront whether it's OK to install Ollama and the model automatically
   if they're missing
2. Checks **Python 3.10+**, stops with clear instructions if missing
3. Checks **Ollama**: if missing, asks for confirmation and installs it
   (`winget` on Windows, the official installer on Linux)
4. Checks that the **service is running** on `127.0.0.1:11434`, otherwise
   starts it in the background and waits up to 20 seconds
5. Checks the **model**: if missing, asks for confirmation and pulls it
6. Copies the skill to `~/.claude/skills/whatmark`
7. Creates the **workspace** and checks it's writable
8. Runs a **final check** that the scripts actually run

Any step that fails stops with the cause and the fix. No silent errors.

### Options

```bash
./install.sh --yes                      # no interactive prompts
./install.sh --model llama3.2           # alternative model
./install.sh --workspace /srv/whatmark  # different working folder
```

```powershell
.\install.ps1 -Yes -Model llama3.2 -Workspace D:\WhatMark
```

## Workspace

All produced files land in a dedicated folder, created on first run:

| System | Path |
|---|---|
| Windows | `C:\ClaudeText` |
| Linux / macOS | `~/ClaudeText` |
| Override | `WHATMARK_DIR` environment variable |

```
C:\ClaudeText\
├── brief.txt            the brief shared by both paths
├── A_direct.txt         path A · direct writing
├── B_source_en.txt      path B · English source
├── B_translated.txt     path B · after translation
└── report.txt           the analysis
```

---

## Usage

Restart Claude Code and type:

```
/whatmark a 400-word post about Zero Trust, technical tone, for IT managers
```

The skill also triggers on its own when a request matches its description —
you can simply write *"compare a text written in Italian with the same
thing translated by Mistral"*.

From there Claude agrees on the brief, writes the direct text, writes the
English version, has Mistral translate it, runs the analysis, and comments
on the results.

### Using the scripts directly

The scripts also work without Claude, as plain CLI tools:

```bash
# Translation
python3 scripts/ollama_translate.py source_en.txt -o translated.txt \
    --target italian --model mistral

# Comparison
python3 scripts/compare_texts.py A_direct.txt B_translated.txt \
    --labels "Direct" "Translated" --save report.txt

# Where do the files go?
python3 scripts/ollama_translate.py --workspace
```

---

## The metrics

```
metric                    Direct      Translated  delta
words                          75           81    +8.0%
type-token ratio             0.84       0.8395    -0.1%
avg. sentence length         12.5         13.5    +8.0%
technical anglicisms            3            0  -100.0%

LEXICAL DIVERGENCE  (0 = identical, 1 = no overlap)
  unigrams (single words)   : 0.4776
  bigrams  (pairs)          : 0.6706
  trigrams (triples)        : 0.7935
```

| Metric | What it reveals |
|---|---|
| **Unigram Jaccard** | how much vocabulary the two texts share |
| **Bigram/trigram Jaccard** | how much the *syntax* changed |
| **Type-token ratio** | lexical richness: a drop means flattened vocabulary |
| **Avg. sentence length** | translators tend to lengthen sentences, spelling out what was implicit |
| **Sentence length stdev** | rhythmic variety: a drop means flatter, more monotone prose |
| **Technical anglicisms** | English terms translated when they shouldn't have been |
| **Exclusive vocabulary** | the translator's concrete word choices, readable at a glance |
| **Invisible characters** | presence of Unicode category `Cf` characters in the texts |

### Reading the increasing scale

The most informative pattern is the **unigram → bigram → trigram**
progression.

If unigrams diverge little but trigrams diverge a lot, the translator kept
the vocabulary and **restructured the sentences**. If both diverge to the
same degree, it changed the words themselves. That's the difference between
a syntactic reformulation and a lexical substitution, and it shows up in the
numbers before you even re-read the text.

---

## Suggested experiments

**1. Background noise — do this first**

Translate twice with identical parameters and compare the two Italian
outputs. The residual divergence is pure sampling noise: it's the threshold
below which any other result means nothing. Without this number, you risk
reading as "translation effect" what's really just `temperature`.

**2. Comparing translators**

Same English source, translated by `mistral`, `llama3.2`, `qwen2.5`.
Compare the translations against each other: each model's individual tics
show up clearly.

**3. Temperature effect**

Same translation at `--temperature 0.1` and `0.9`. Quantifies how much
sampling affects a task that, in theory, should be deterministic.

**4. Technical domain**

Texts full of terminology that's normally left in English in the target
language. The anglicism counter becomes a direct indicator of the
translator's quality in that domain.

**5. Round-trip**

IT → EN → IT, compared against the original. Measures how much meaning
survives a full round trip.

---

## Methodological note

**Production order matters.**

The two texts must be produced independently. If you write the English
version first and the Italian one right after, the second is *anchored* to
the first — it's still in the model's context. You'd be comparing two
translations, not a translation against genuine writing.

The skill enforces the correct order (direct first, English after). For a
truly clean test, produce the two texts in **separate sessions** starting
from the same written brief.

---

## Repository structure

```
whatmark-skill/
├── README.md
├── LICENSE
├── install.sh              Linux / macOS installer
├── install.ps1             Windows installer
├── assets/
│   └── logo.png
└── skill/
    ├── SKILL.md            the actual skill
    └── scripts/
        ├── ollama_translate.py
        └── compare_texts.py
```

## Uninstalling

```powershell
Remove-Item -Recurse "$env:USERPROFILE\.claude\skills\whatmark"
```

```bash
rm -rf ~/.claude/skills/whatmark
```

The workspace is left untouched: it holds your work.

## Contributing

Issues and pull requests welcome. Areas where the project would benefit most:

- **additional metrics** — sentence-level edit distance, inter-paragraph
  cohesion measures, per-language readability indices
- **anglicism lists** for domains other than IT security
- **support for other local backends** besides Ollama
- **validation on language pairs** other than IT/EN

## License

MIT — see [LICENSE](LICENSE).

<div align="center">
<sub>Built to understand how models behave, not to hide it.</sub>
</div>
