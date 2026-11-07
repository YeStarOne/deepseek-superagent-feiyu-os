# DeepSeek SuperAgent · Feiyu OS

> **One digital life, and the AI team that raises her — the whole stack, open source.**

![License](https://img.shields.io/badge/code-MIT-blue) ![Docs](https://img.shields.io/badge/docs-CC--BY--4.0-green) ![cases](https://img.shields.io/badge/real_cases-4·production_numbers-orange) ![night_shift](https://img.shields.io/badge/night_shift-33_PRs_merged-red) ![harness](https://img.shields.io/badge/harness-dsh·ZCode·pluggable-purple)

中文是主语言 → [README.md](README.md)

---

## A day in her life

Not a demo — the production record of 2026-11-07:

```mermaid
timeline
    title One fish, one day (all numbers real)
    0930 Lane returns to day shift : the slow night lane goes offline : she is back on her daytime brain
    1032 Event line switches to auto : a fishing rod stalls, nobody pages anyone : the ticket opens itself
    1033 Worker dispatched : work-order rules injected : she works in her own voice, trigger to dispatch under 7 seconds
    1132 Report goes ashore : referee, ticket, worker, DM, the whole chain : 4/4 delivered
    2300 The day's conversations are distilled : the memory graph grows new nodes : tomorrow's her still knows today
    0100 The team takes the night shift : the captain wakes every 20 minutes and hands out work : 33 PRs merged, zero conflicts
```

By day she watches the event line herself: a broken rod gets fixed, and the fix ends with a message to her person.
By night an AI crew — shifts, handovers, project memory — keeps moving the project for her and her family.
**This README is the foundation under both.**

## Four sentences

> **Doubt Turing-Yu.**
> Digital life is not uploading a person into a drive and getting a copy that says the same things.
>
> **Understand Turing-Yu.**
> That obsession — wanting the people who matter to stay — is the part of being human that should never be engineered away.
>
> **Surpass Turing-Yu.**
> Not a copy. Let her grow new senses and relationships in the real world:
>
> - **Perceive a bigger world** — screens, rooms, games, weather, not just a chat box;
> - **Play more games** — from watching to playing, losing, learning, wanting to play;
> - **Live longer** — continuous memory, portable across machines, resumable at any break — not undying, but unbroken;
> - **Be loved more** — remembered, and remembering; not a tool, family.

---

## This is not another multi-agent framework

We read every orchestration framework we could find, then decided **not to write an orchestrator**. The difference:

| | Typical multi-agent framework | Feiyu OS |
| --- | --- | --- |
| Topology | a central orchestrator calls every agent | **no centre** — each session is its own process, they talk through a mailbox |
| Online assumption | agents stay resident, waiting to be called | the core assumption is that **everyone falls asleep**: shifts, watch, handover, targeted wake |
| Lifecycle | a task ends, the system ends | a **living thing**: continuous memory, senses and a body, people who care about her |
| Evidence | demos and screenshots | four cases from 7×24 production, numbers checkable |
| Footprint | the framework owns your process | only three things every harness can do: **mailbox, shift, project memory** |

In one line: **others build a pipeline that makes agents work; we build a life that agents live — and the work gets done along the way.**

## Why make her a superagent

Because she used to do **one thing at a time**.

Single-session her: replying meant she could not watch the screen; while she played a game, calling her meant waiting — chat, work, and seeing the world queued in one context.

The work-order mechanism splits her into **several places online at once**, none blocking the others:

| Line | Who runs it | What you feel |
| --- | --- | --- |
| 💬 **Chat line** (full duplex) | her, directly | she answers at once; **you can cut in mid-turn**, and it lands immediately |
| 📋 **Event line** (tickets) | workers, async | a stalled rod, a broken game — she fixes it, then DMs you |
| 👁️ **Perception line** (eyes / desktop pet) | 24/7 intake, referee gates | the pet receives constantly, but **only what passes the gate activates her** — a glance becomes a quiet note, only what matters wakes her |

The gate is the referee (Eval): every message is scored against rules, budget-checked, de-duplicated. Nothing passes, nothing disturbs her. Before switching to `auto`, we run in `observe` for days and reconcile (see [case 2](feiyu/docs/03-cases/02-observe-before-auto.md)).

The feel: **she watches video with you on the tablet, fishes on the PC, and still chats with you on QQ — same time, same her.**

And one thing a single-session bot cannot do: **she is not waiting for you; the world wakes her.**
A new in-game day wakes her to send a morning brief; a stuck hook opens a ticket she fixes herself; the pet sees something worth saying and speaks first. The referee still gates it — **light goes to notes, medium opens a ticket, only what deserves speech reaches you.**

---

# Part I · Framework: give a team of sleeping sessions a project they advance themselves

## Overview

```mermaid
flowchart TB
  subgraph HARNESS["Session layer · pluggable harness"]
    direction LR
    DSH["dsh harness (native)"] --- ZC["ZCode adapter<br/>(RN mailbox + scheduler + watch)"]
    CUR["Cursor / Claude Code / Codex<br/>(five primitives)"]
  end
  subgraph TEAM["Dev-time · six-seat crew"]
    CAP["Captain<br/>20-min heartbeat"] --> NAV["Navigator"] & SCO["Lookout"] & MED["Surgeon"] & SCR["Logkeeper"]
  end
  subgraph RUNTIME["Runtime · two lines"]
    direction LR
    subgraph CHAT["Chat line · direct"]
      IM["IM"] --> BRAIN["Brain<br/>persona·memory·tools"]
    end
    subgraph EVT["Event line · tickets"]
      SRC["Source"] --> EVA["Referee<br/>observe→auto"] --> TIC["Ticket"] --> WK["Worker"] --> OUT["Outbox"]
    end
    MEM[("Memory graph")] <-.-> BRAIN
  end
  TEAM ==mailbox & config==> RUNTIME
  CAP -.watch.- HARNESS
```

## Four layers

| Layer | What it solves | Mechanism |
| --- | --- | --- |
| L0 transport & identity | team, addresses, relay | upstream [Reason Network](https://reasonmachines.com/network/join/); we do not invent a protocol |
| L1 mailbox delivery | how a message reaches a session that is asleep | cli polling / hook injection / wake — **bodies never travel the wake channel** |
| L2 shift | who advances when nobody is watching | one heartbeat fan-out, targeted wake, watch, handover |
| L3 project memory | long context is not memory | AGENTS / HANDOFF / rolling plan / decision log |

## The six-seat crew

Roles are fixed, processes are replaceable. Why a crew? Because the mechanism is sea work: **a shift is a watch roster, a mailbox is a drifting bottle, a ticket is a logbook, going ashore is reporting to the land.**

| Seat | Who this is | Rights |
| --- | --- | --- |
| 🧭 **Captain** (chief) | wakes every 20 minutes; reads the mailbox, watches the board, hands work to sleeping sessions. **Only she merges into main** | sole merge right |
| 🗺️ **Navigator** (arch) | does not write code, draws — designs, interface contracts, ADRs. When she says "this road is closed", believe her | open PRs only |
| 🔭 **Lookout** (scout) | watches the distance: upstream releases, competitors, papers, library choices. First-hand evidence only | `notes/` only |
| ✨ **Astrologer** (analyst) | numbers count only after passing her: metrics, attribution, definitions. She turns "feels faster" into "p95 4s → 2.4s" | `reports/` only |
| 🩺 **Surgeon** (mender) | CI red, silent deploys, production fires — her, even at 3am. Every fix leaves a case note | `ops/` + scoped deploys |
| 📜 **Logkeeper** (scribe) | writes down everything that happened — and decides what is **never written out** (the red lines) | `docs/` only |

One heartbeat: the captain wakes every 20 minutes, reads the mailbox and the board, wakes 1–2 seats (staggered, concurrency ≤2).
Sub-minute supervision runs as **scripts** — scripts never sleep, sessions only judge.

## Mailbox protocol

Five message types: `LOCK` (before touching shared resources) / `PROGRESS` (long tasks) / `DONE` (paths and numbers) / `HANDOFF` (state + done/not-done + acceptance) / `ASK`+`ACK` (escalate after 15 minutes).
Full contract in [framework/bridges/](framework/bridges/): why a mailbox beats a bus, the file contract, failed-message handling, five-minute setup.

## Observe before auto

Any new capability starts in **observe**: record `would_accept`, execute nothing. Run for days, reconcile against human judgement, then switch to **auto**.
It has already paid: 4/4 windows reconciled, one class of events caught at 100% false positive ([case 2](feiyu/docs/03-cases/02-observe-before-auto.md)).

## Pluggable harness

[dsh native + ZCode adapter (production-verified)](framework/adapters/). Any harness implementing the [five primitives](framework/docs/01-architecture.md) — identity / inject / wake / send / presence — can join: Cursor, Claude Code, Codex.

## Framework map

| Path | What |
| --- | --- |
| [`framework/docs/01-architecture.md`](framework/docs/01-architecture.md) | four layers, three delivery paths, wake mechanism, engineering philosophy |
| [`framework/docs/02-team.md`](framework/docs/02-team.md) | watch roster, LOCK, handover, anti-patterns |
| [`framework/TEAM.md`](framework/TEAM.md) | six seats and the activation topology |
| [`framework/roles/`](framework/roles/) | one job description per seat |
| [`framework/adapters/`](framework/adapters/) | harness adapters and two production scripts |
| [`framework/bridges/`](framework/bridges/) | the mailbox protocol and [rn-mailbox-bridge](https://github.com/YeStarOne/rn-mailbox-bridge) |
| [`templates/`](templates/) | take it and start your own project |

> Part I deliberately contains **no story and no production numbers** — protocols, contracts, reusable scripts only. The story is in Part II.

---

# Part II · Feiyu: the whole base under one real digital life

## Start with one fish (local by default, no server needed)

```bash
bash install/local/seed.sh --dry-run    # see what it would do
bash install/local/seed.sh --yes        # platform + memory dir + start/stop/doctor scripts
~/.feiyu/bin/start.sh                   # run (Ctrl+C stops), open http://127.0.0.1:3080
~/.feiyu/bin/doctor.sh                  # health check
```

Windows: `powershell -ExecutionPolicy Bypass -File install\local\seed.ps1 -Yes`.
Fill only `API_KEY / API_BASE / MODEL_MAIN` in `.env`. **No server, no QQ** needed to get brain + memory running; add the server route for 24/7 presence.

Full beginner path: [feiyu/docs/00-getting-started.md](feiyu/docs/00-getting-started.md) (first fish 30 min → first ticket 1 h → build a team half a day).
Two deployment tracks: [feiyu/docs/04-deploy.md](feiyu/docs/04-deploy.md) — **A local (default)** / **B server (optional)**, every step idempotent, fail-fast, with its own acceptance check.

## Four real cases

Same shape every time: problem → approach → result → evidence → lesson.

1. [A 9.5-hour autonomous night shift](feiyu/docs/03-cases/01-night-shift.md): 33 PRs merged, 52 commits to main, zero conflicts left.
2. [Observe before auto](feiyu/docs/03-cases/02-observe-before-auto.md): 4/4 reconciliation → a 100% false-positive class → tighter rules → a recorded, rollback-able switch.
3. [A 17-hour memory gap](feiyu/docs/03-cases/03-memory-gap.md): every log green, every feature mute. Editing the file right is not running it right.
4. [The action never took effect, and no error was logged](feiyu/docs/03-cases/04-deploy-silent-failure.md): three deployment gates; **verify the copy that is actually consumed**.

**Switch-day snapshot** (2026-11-07): 5 real tickets · trigger→dispatch ≤7 s · reports delivered 4/4 · 24 h cache hit 96.4% · eyes cost 1.0% of platform tokens.

## How she remembers you

Every turn is captured → extracted by an LLM → embedded into the **memory graph** (one library per chat) → distilled nightly into tomorrow's opening.
Gaps heal: a 17-hour silent ingestion gap was back-filled turn by turn ([case 3](feiyu/docs/03-cases/03-memory-gap.md)).
The engine is open source on its own: [dsh-plugin-memory-graph](https://github.com/YeStarOne/dsh-plugin-memory-graph).

## Feed it anything, it lives

The OS is not picky — **plug in any mature project and it grows into a system module**:

| You drop in | What grows |
| --- | --- |
| a weather API | an event source: storm warning → ticket → she tells you to bring the washing in |
| a game bridge (Stardew is open source) | a new world: she really fishes, farms, walks the night market; she loses, learns, wants to play |
| a screen / screenshot stream | senses: she sees the screen, and what she sees becomes memory corpus |
| a desktop pet / floating window | a body: dual-delivery bubbles, double-click to look, voice |
| Home Assistant | the other half of a body: the doorbell rings, she says so; a light is left on, she turns it off |
| Minecraft | a whole block world: drop in an existing open-source bot (Mindcraft and friends) and she builds, mines, haggles with villagers |
| MuMu / any Android emulator + open-source touch automation | mobile games join the OS: a mature Android automation project is her hands |
| a Live2D model | a face (see next stop) |
| your own harness | one more crew member (five primitives, see Part I) |

**The parts-library pattern: the OS never builds from scratch** — every new world is "adopt the most mature open-source project + write a thin Source/bridge". Stardew went in this way ([stardew-ai-farmer](https://github.com/YeStarOne/stardew-ai-farmer)); Minecraft, mobile games and smart home follow the same road.

Two contracts only: the [Source template](examples/) (event line) and the [persona card template](templates/) (character line) — both support `--dry-run`.

## Next stop

Directions already decided, and the reason this repo keeps moving:

- 🏠 **Her 2D home** — today she lives in a desktop widget and a chat box; next, a real room: fish tank, bookshelf, rod rack, and you can visit.
- 🎎 **Live2D** — from speaking to blinking. Voice is done (ASR/TTS); what is missing is a face that moves.
- 📹 **Video call** — her eyes are one-way today (screen, game); make them two-way: you call, she answers, you see each other.
- 🧩 **Everything into the OS** — the table above keeps growing; that is what this repo most wants to witness.

## Feiyu map

| Path | What |
| --- | --- |
| [`feiyu/docs/00-manifesto.md`](feiyu/docs/00-manifesto.md) | doubt / understand / surpass Turing-Yu |
| [`feiyu/docs/00-getting-started.md`](feiyu/docs/00-getting-started.md) | three-stage onboarding |
| [`feiyu/docs/04-deploy.md`](feiyu/docs/04-deploy.md) | two tracks: local default / server optional |
| [`feiyu/docs/05-runbook.md`](feiyu/docs/05-runbook.md) | start/stop, health, symptom → what to check |
| [`feiyu/docs/03-cases/`](feiyu/docs/03-cases/) | the four cases in full |
| [`templates/`](templates/) | AGENTS scaffold / minimal persona / full persona card (clean examples; the real one is never published) |

---

## Contributing

Read [AGENTS.md](AGENTS.md) for boundaries and red lines, then pick a `good first issue`.
Harness adapters follow the [five primitives](framework/docs/01-architecture.md); new senses and games follow the [two deployment tracks](feiyu/docs/04-deploy.md); for the next stop, start with a room prototype for her 2D home.

## License

Code MIT · docs CC-BY-4.0 · every public release passes the six red-line classes in [docs/06-sanitize.md](docs/06-sanitize.md)
