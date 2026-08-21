<div align="center">

<!-- Replace with your own logo -->
<img src="assets/logo.png" alt="WhatMark?" width="160">

# WhatMark?

***Academic Interesting, semi-pseudo-official purpose:***

How much does a text change when it goes through machine translation?

A controlled experiment, with numbers instead of impressions.

***Slightly more official and desired second kind of objective:***

***"WhatMark?"*** Stands for *"What Watermark?"*. By relying on accurate automated translation using open-source models running locally that do not apply watermarks, **the original watermark is naturally removed** while trying to minimize the loss of text quality and maintaining the outline and structure of the text produced by Claude.

**Note.** *It is recommended to always check and compare the generated texts: occasionally, the results are terrible using a lightweight model.*
*Alternatively, if local resources are available, you can use heavier models, and the result will be more than excellent.*

So, this is a sort of "academic" and interesting watermark breaker (conceived as an indirect side effect) made only for **education purpose**.

[![Python](https://img.shields.io/badge/python-3.10%2B-blue)](https://www.python.org/)
[![Agent Skill](https://img.shields.io/badge/Claude-Agent%20Skill-8A63D2)](https://code.claude.com/docs/en/skills)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux%20%7C%20macOS-lightgrey)]()
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Dependencies](https://img.shields.io/badge/dependencies-none-brightgreen)]()

</div>

---

## What it is

*"WhatMark?"* is an **Agent Skill for Claude Code** that runs a controlled
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

**The output isn't the two texts** (even if you have access to them). **It's the analysis of their difference.**

## What it's for

- Understanding **what gets lost** in machine translation compared to direct writing
- Comparing **different translators** on the same source text and spotting their tics
- Measuring the effect of **temperature** and other sampling parameters
- Studying **translation artifacts** in a specific technical domain
- Breaking the watermark (as a side effect)

> **Note:** translation performed by Mistral ***completely*** breaks the watermark.

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

## Suggested experiments (optional)

**1. Background noise**

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

---

# How does "WhatMark?" break the AI ​​watermark?

*To understand this, we first need to grasp—more or less, and in very simplified terms—how AI watermarking for text works.*

## How AI text watermarking works
 
When a language model writes, it constantly picks between words that would
work equally well. A watermark quietly nudges those coin-flip decisions in a
direction only the provider can predict (leaving the text unchanged in
meaning, but statistically unusual in a way a key-holder can measure).

### The key idea: models are often undecided
 
Halfway through a sentence, a model isn't choosing one correct word. It's
ranking every word it knows...
 
Sometimes the answer is forced. After *"the network is completely"*, the word
`flat` might be the obvious choice, and everything else is a distant runner-up.
 
But often several words are near-ties:
 
> Network segmentation is **essential** / **crucial** / **critical** / **vital**
 
Four words, same meaning, roughly equal odds... Whichever one comes out, no
reader would notice a difference.
 
**That indecision is free space.** *The watermark lives there.*

## How the nudge works

More or less, the procedure is as follows:

<img width="1024" height="559" alt="ai-wm" src="https://github.com/user-attachments/assets/33854ba9-aef8-4625-b6a2-812c7f135383" />

*before each word, the system does something like a secret coin flip*
 
1. It takes a **secret key** (which never leaves the provider's servers)
2. It mixes in **the last few words already written** *(at the very start
   there are none, so the words of your prompt may play that role)*
3. It feeds the mix into a **hash function** (one-way scramble)
4. Out comes the **digest**: a fixed block of bytes that read as a number and used
   as a starting value, it takes the name **seed**
5. The seed drives a **pseudo-random generator** (PRNG) that shuffles the whole
   dictionary into a new order
6. The shuffled list is **cut in two**: the first quarter becomes the
   **preferred group**, the rest doesn't
7. Preferred words get a **small bias** added to their score
8. The model picks normally from there

Meanwhile (and this is easy to miss) the model has been scoring every word
in its vocabulary on its own, completely independently. That calculation
knows nothing about the key or the seed. **The two only meet at step 7.**

### The shuffle is not random (and that's the point)

**The generator isn't actually random.** It's a *pseudo*-random number
generator: a fully deterministic algorithm that, given the same seed, always
produces the exact same sequence — same numbers, same order, every time,
forever. It only *looks* random to anyone who doesn't know the seed.
 
```
seed 42  →  8, 3, 7, 1, 9, 2 …        every single time
seed 42  →  8, 3, 7, 1, 9, 2 …        again, identical
seed 43  →  4, 6, 5, 9, 8, 2 …        completely different
```
 
That double nature is the entire trick... The shuffle has to be two
contradictory things at once:
 
- **Unpredictable** without the key — otherwise anyone could work out which
  words are preferred and deliberately avoid them
- **Perfectly repeatable** with the key — otherwise nobody could ever check a
  finished text, because they couldn't rebuild the same groups
  
Genuine randomness would fail on the second count. If the shuffle were truly
random, not even the system that performed it could reproduce it, and
detection would be impossible. The security doesn't come from randomness at
all — it comes from **the seed being secret**.

Then it moves to the next word and does it all again — with a completely
different split, because the preceding words have changed.
 
**Two things follow from step 2**, and they're the clever part:
 
- There is no fixed list of "marked words." The same word can be preferred in
  one sentence and not in the next.
- Anyone holding the key can replay the whole calculation later, because it
  only depends on words that are visible in the finished text.

### The bias: a small number that does all the work
 
The "thumb on the scale" has a name — the **bias** — and it's worth
understanding, because it explains almost everything else about how this
technology behaves...
 
Before picking a word, the model has given every word in its vocabulary a
raw score. The bias is simply **a fixed amount added to the score of every
preferred word**. Nothing subtler than that: *same amount, every time, only
to the preferred group.*
 
What makes it clever is that adding a fixed amount *doesn't have a fixed
effect.* Because scores get converted to probabilities through a curve, the
same bias behaves completely differently depending on how sure the model
already was.
 
| Situation | Before bias | After bias |
|---|---|---|
| Two near-tied synonyms | 55% / 45% | **90%** / 10% |
| One obviously correct word | 99.7% / 0.3% | **98%** / 2% |
 
Same bias, both times: in the first case it decides the outcome; in the
second it barely registers, because the gap it has to close is far too wide!
 
**This is the whole safety mechanism.** Grammar, facts, names and technical
terms are all cases where the model has a clear favourite... so the bias
can't overrule them. It only gets to act where the model was going to flip
a coin anyway.
 
It's also the reason **detection needs length.** Every forced word is a wasted
position: it lands in the preferred group by luck alone, carrying no signal.
Only the genuinely undecided moments count, and those are a fraction of any
piece of writing.
 
Turning the bias up would make the signal stronger and faster to detect —
and would start visibly degrading the writing, because it would begin
overruling choices that shouldn't be overruled. That trade-off has no clever
solution. It's the fundamental tension of the whole approach.
 
### How detection works
 
***The detector needs the key.*** It does **not** need the model.
 
It walks through the text and, at every position, recreates the same split
the generator used... possible because the split depends only on the key and
the preceding words. Then it simply counts.
 
If the preferred group holds a quarter of the dictionary, then in ordinary
human text about **25%** of words should land in it by coincidence.
 
| Text of 200 words | Words in preferred group | Verdict |
|---|---|---|
| Written by a human | ~50 | as expected |
| Watermarked | ~110 | far too many to be chance |
 
That's the whole test: not a fingerprint or a hidden character...just a
count that comes out wrong too consistently.

### The only real way to break the watermark

Everything is based on a "Translation Attack."

As we saw before, the watermark isn't stored in the words: It is stored in a relationship between each word and the ones before it... translation rebuilds every one of those relationships.

```
GENERATED
"Network segmentation is essential for limiting lateral movement"
              ↑              ↑
    these words determined the group used to check the next one

TRANSLATED
"Segmentare la rete è indispensabile per limitare i movimenti laterali"
              ↑              ↑
    different words → different seeds → different groups
```

Many people say: *"Okay, but if you translate it, it’s no longer the text produced by the LLM you’re paying for, and you lose quality. 
At that point, you might as well just have another AI generate the text directly!"*

While that may be true to some extent, it’s not quite the whole story... *"What Watermark?"*, for instance, has Claude handle the entire process, aiming to preserve Claude's outline, structure, and key choices—even though the final result differs from the original text: the content and general structure remain virtually identical.

Regarding quality: to allow everyone to use the tool entirely locally—without relying on the cloud or API keys—this repository uses a local, open-source Mistral model (which takes up less than 5GB). 
Naturally, the translation quality won't be optimal, and the text will require review. However, those with access to greater computational resources will achieve a perfect, excellent result: *the structure generated by Claude remains intact, yet the process of translating it into one's own language automatically and naturally eliminates the watermark.*

*The skill does exactly this:*

If I am Italian and want a text about the history of Rome, the skill doesn't have Claude write it in Italian; instead, it generates the text in English, automatically passes it to Mistral locally for translation, and then exports a ready-to-use .txt file—featuring Claude's content and structure, but "processed" by Mistral and stripped of the watermark.

---

# Disclaimer

**Watermarking matters.** Machine-generated text is now indistinguishable from human writing by reading alone, and in some contexts — court filings, research papers, news, political messaging — that difference carries real weight. *Watermarking doesn't solve this, but it makes a question askable that otherwise has no answer at all.*

It is also a **legal obligation.** Under **Article 50 of the EU AI Act**, in force since **2 August 2026**, providers must mark synthetic output in a machine-readable way, and ***publishers must disclose AI-generated content addressed to the public***. These are two separate duties: removing a mark does not discharge the second one, it only deletes the evidence supporting it.

On one hand, this project is experimental and aims to analyze the original text alongside the exact same text processed by a translator—with both outputs in the same language.

On the other hand, it is an experiment in simplified watermark removal while maintaining a certain level of quality.

***This does not mean that this repository should be used for malicious purposes.***

For me, delving into this subject matter and this project was fascinating and deeply engaging; the goal was study and in-depth exploration.
*May it be the same for you, too.*

--- 


## License

MIT — see [LICENSE](LICENSE).

<div align="center">
<sub>Built to understand how models behave, not to hide it.</sub>
</div>
