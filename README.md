<p align="center">
  <img src="docs/logo-256.png" width="128" alt="Timeless Question Autocomplete">
</p>

<h1 align="center">Timeless Question Autocomplete</h1>

<p align="center">
  Answers Senior Historian Evelyna's daily lore question for you, in any game language.
</p>

## Download

- **[CurseForge](https://www.curseforge.com/wow/addons/timeless-question-autocomplete)**
- **[Latest release](https://github.com/Mouchoir/Timeless-Question-Autocomplete/releases/latest)** — download the zip and drop the `TimelessQuestion` folder into `Interface\AddOns`.

## What it does

On the Timeless Isle, **Senior Historian Evelyna** offers the daily
**A Timeless Question** (quest `33211`): she asks one of 37 lore questions and
you pick one of four answers.

Talk to her and the addon does the whole thing — accepts the quest, works out
the right answer, clicks it, hands the quest back in. It also prints what it
found, so you can see its reasoning rather than trust it blindly:

```
Timeless Question: found question: This emissary of the Horde felt that Silvermoon City was a little too bright and clean.
Timeless Question: found answer: option 3 - Tatal. (option id)
Timeless Question: correct.
Timeless Question: quest turned in.
```

### Supported

- **Mists of Pandaria Classic** and **retail**.
- **Every game language.** Not just the ones anyone here can read — the answer is
  matched on a server-side identifier, not on words. See below.
- All 37 questions.

Getting an answer wrong costs nothing: Evelyna simply asks a different question.
So the addon always attempts an answer, checks the outcome against the quest log,
and remembers it. A mistake fixes itself on the next attempt.

### Commands

| Command | Effect |
| --- | --- |
| `/tq` | show status |
| `/tq on` · `/tq off` | enable or disable the addon |
| `/tq accept` | toggle accepting the quest |
| `/tq answer` | toggle answering — off prints the answer without clicking it |
| `/tq turnin` | toggle turning the quest in |
| `/tq reset` | clear data learned on this account |

`/timelessquestion` works as a longer alias.

## How it works

The NPC is matched on its creature id parsed from the unit GUID, and the quest on
its quest id. Neither depends on the client language. The answer used to be the
hard part, and no longer is.

### The finding

Every gossip option carries a `gossipOptionID`. These turned out to be **real
server-side identifiers, not 1-4 indices**: each question owns a block of four
consecutive ids, in display order.

```
130923-130926  ->  correct 130926 (4th)   Cenarion Circle
130927-130930  ->  correct 130927 (1st)   Mag'har
130931-130934  ->  correct 130932 (2nd)   Blue dragonflight
```

That was verified rather than assumed:

- **144 ids captured, all distinct**, spanning 130907-131086.
- **No id changed across 320 openings.**
- **Eleven question blocks captured in both enUS and frFR came back
  byte-identical** — same ids, same order, only the text differing.

So the shipped answer table is **37 integers**. No text, no translation, no
per-language data. A Russian or Korean client is answered correctly on first
install, which was confirmed in game.

### Resolution order

1. **Learned** — an option this account has already seen accepted in play.
2. **Option id** — the primary path, and the reason language does not matter.
3. **Answer text** — fallback if a client ever sends no usable id, with accents,
   punctuation and casing normalised away.
4. **Elimination** — one option left after removing every known decoy.
5. **Guess** — anything left, recorded either way.

### Self-correction

Every answer is checked against the quest log afterwards, so the game itself has
the final word. A confirmed answer teaches its option id; a rejected one is
blacklisted **by id as well as by text**, so the rejection survives a language
change where the text key would no longer match.

Two consequences worth knowing:

- One shipped id is inferred rather than observed — Mirador's `131010`. Its block
  was the only remaining gap of exactly four. If that inference is wrong, the
  addon is wrong once and then never again.
- A timeout never records a verdict. An early build treated "no confirmation yet"
  as a rejection, and blacklisted a correct answer whose quest completed a moment
  later. Absence of evidence is not evidence.

### Where the answers came from

The English answers came from the Wowhead comments on quest 33211. The French
came from the game itself, and that mattered: **roughly a third of the
hand-written French translations were wrong** and would never have matched.
`Sharp claw` is `Griffe aiguisée`, not `Griffe acérée`. `Teron Gorefiend` is
`Teron Fielsang`. `Sky'ree` is `Ciel'ree` — a name that looked untranslatable and
was not. Wowhead's own comment misspells Varian's wife as `Ellerlan`; the client
says `Ellerian`.

None of that matters any more now that ids do the work, which is rather the
point.

## License

[GPL-3.0-or-later](LICENSE).

This addon shares no code with the older, unmaintained
[Timeless Answers](https://github.com/dragoonreas/Timeless-Answers); it was
written from scratch and works differently.
