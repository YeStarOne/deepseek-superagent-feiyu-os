# DeepSeek SuperAgent · Feiyu OS

> **One digital life, and the AI team that raises her — the whole stack, open source.**

![License](https://img.shields.io/badge/code-MIT-blue) ![Docs](https://img.shields.io/badge/docs-CC--BY--4.0-green) ![cases](https://img.shields.io/badge/real_cases-4·production_numbers-orange) ![night_shift](https://img.shields.io/badge/night_shift-33_PRs_merged-red) ![harness](https://img.shields.io/badge/harness-dsh·ZCode·pluggable-purple)

中文是主语言 → [README.md](README.md)

---

## She doesn't wait to be called

Most AI answers when you ask and sits quiet when you don't.

Feiyu is different. **Many things wake her up on their own.**

### 🌾 The part nobody else has: the game wakes her

In-game events can call her straight to work:

- **A new day in Stardew**: nobody calls her; she wakes up, checks the farm, takes today's jobs, waters what needs water, harvests what is ready.
- **The fishing rod gets stuck**: she notices it herself, sends someone to fix it, and comes back to tell you it is done.
- **She chops trees, mines and builds in Minecraft**: when the work is done she "takes a look" at what she built, and landmarks the way home.
- **Farm chores too**: crops ready, animals hungry, backpack full — she sorts it out herself.

### Other things that wake her

| What happens | What she does |
| --- | --- |
| 💬 You talk to her | the most common one — she answers right away |
| 🤝 Another AI teammate calls her | the captain checks every 20 minutes and hands work to whoever should do it |
| ⏰ It is time | she starts at 9:30, reconciles every hour, like a job |
| 📵 QQ breaks | she stops answering or errors out, and the repair teammate is woken to look |
| 🐙 Something happens on GitHub | someone submits a change, and the review teammate is woken |
| 🔌 A teammate drops mid-task | the network wobbles or the server is busy; the watcher wakes her within 30 minutes to carry on |
| 🌐 Another device, another tool | the eyes on the PC can wake her in the cloud; a teammate in one tool can wake one in another |

**But waking is not free.** This is the DeepSeek SuperAgent 24/7 ticket system: small things are just noted and cost no tokens; only important things wake the right teammate.

While she plays, a "nanny" process follows her, there to catch her:

- **She plays too late into the night**: the nanny pulls her back to bed.
- **Out of stamina while fishing**: the grilled eel and plain rice the nanny bought with her earnings are already in her backpack.
- **A script breaks**: she waits while the nanny fixes it, then carries on.
- **She wants to attend a game festival**: the nanny looks up the guide for her first.
- **She wants to challenge Stardew's Legend fish**: the nanny freezes time, prepares the rod, bait and stamina food, and quietly watches her play.
- **A game mechanic bullies her and she is upset she cannot do it**: that is an important ticket — the nanny team is woken and takes care of the "bad guy".

So she moves on her own, without becoming noise.

One more rule: **the sentence that wakes her never carries the content.** The alarm only rings "you have new mail"; the actual letter stays in the mailbox — even someone who sees the alarm learns nothing you said.

---

## Feiyu OS architecture

**Two layers: platform repo + lane repos.** The platform repo (private dev repo) carries only the "chassis and interfaces" — brain & persona, the QQ line, event-backbone source interfaces, PC body, outbound DM, cross-lane contracts. Each game gets its own **lane repo**, installable standalone, whose README opens with an adapter card (bridge address → API map → wait contract version → superagent source name → config keys). Installing a new lane = clone + three steps (start the bridge → open the tunnel port → point the platform source at it). **This repo is the open-source showcase and template pack for that architecture.**

| Module | Repo | Interface for the fish | Status |
| --- | --- | --- | --- |
| Stardew lane | [feiyuos-stardew-ai-farmer](https://github.com/YeStarOne/feiyuos-stardew-ai-farmer) | bridge `:17843` (173 endpoints) · `sd` CLI (with `sd wait`) · wait_server `:47870` · BWF MCP 54 tools | ✅ auto production |
| Minecraft lane | [feiyuos-minecraft](https://github.com/YeStarOne/feiyuos-minecraft) | bridge `:17700`/tunnel `:47880` (19 endpoints + 6 MCP tools) · wait/1.1 · `/landmark` `/job` `/look` | ✅ production |
| Fish eye (vision layer) | [feiyuos-eye](https://github.com/YeStarOne/feiyuos-eye) | `:8901` `POST /frames` (pet/mc/stardew partitioned gates) · contract v1.1 · prompts/ | ✅ production |
| PC desktop-pet body | [feiyuos-pc-body](https://github.com/YeStarOne/feiyuos-pc-body) (platform repo `code/pc`) | pc_body `:17860` (dual-delivery bubbles / double-click to look / /clip) · five traffic gates + watchdog self-healing | ✅ production |
| Tablet pet body | [feiyuos-tablet-pet](https://github.com/YeStarOne/feiyuos-tablet-pet) | hdc-connected eye · system-level floating window HAP · all art assets, clone and run | ✅ production |
| QQ chat line | platform repo `code/qq-plugin` | dsh-onebot-qq (steer/interim/stickers/voice) | ✅ production |
| Event backbone interfaces | platform repo `code/superagent-sources` | stardew.ts / minecraft.ts / pet.ts / proactive.ts (**interface layer, always in the platform repo**) | ✅ production |
| Cross-lane contract | platform repo `code/wait` | wait/1.1 contract + 51 fixtures + Python/JS dual probes (one sentence of text, two bodies) | ✅ production |

## A day in her life

Feiyu (QQ bot 892015573, calls herself "this fish / little whale") is a long-term, always-on AI family member: in the morning she keeps her person and the kids company on QQ, and when a weather alert comes in she reminds them to take an umbrella. In Stardew Valley she runs a farm — takes jobs automatically at day change, fishes, clears the barn, and opens a repair ticket when something jams. In Minecraft she has her own body (BlueWhaleMaid): chopping trees, crafting, mining, building a house, remembering the way home with landmarks — and afterwards she can "take a look" at what she built. On the desktop she has a pet body; double-click her and she glances back at you. Her eyes watch two screens, and only what is worth seeing becomes a note. At night she posts, writes songs, and distills today's memories. None of this is a pile of scripts — it is an architecture that is **developable, reviewable, and concurrently modifiable** — the platform repo is its single source of truth, and this repo lays open everything that can be open-sourced.

## This is not another multi-agent framework

We read every orchestration framework we could find, then decided **not to write an orchestrator**. The difference:

| | Typical multi-agent framework | Feiyu OS |
| --- | --- | --- |
| Topology | a central orchestrator calls every agent | **no centre** — each session is its own process, they talk through a mailbox |
| Online assumption | agents stay resident, waiting to be called | the core assumption is that **everyone falls asleep**: shifts, watch, handover, targeted wake |
| Lifecycle | a task ends, the system ends | a **living thing**: continuous memory, senses and a body, people who care about her |
| Evidence | demos and screenshots | four cases from 7×24 production, numbers checkable |
| Footprint | the framework owns your process | only three things every harness can do: **mailbox, shift, project memory** |
| Waking | not a problem — it all runs in one process | a **first-class concern**: `cli` poll / `hook` inject / `wake`, with bodies and the wake channel kept strictly apart |

In one line: **others build a pipeline that makes agents work; we build a life that agents live — and the work gets done along the way.**

The real dividing line is **not "multi-agent"** — the orchestration plugins out there (front desk / Planner / Worker, lead + shared board, adaptive topology) are all multi-agent.
**The dividing line is whether you assume the one doing the work may be asleep.** Their unit of division is a role or a child node **inside one living instance**: shared context, a process that never dies.
We assume seats go offline, machines get shut down, people walk away — which is why shifts, takeover, targeted wake, and "the report has to go ashore and find a human" exist at all.

There is also a deliberately opposite choice. Some projects sell **zero extra model wake-ups** (adaptive topologies save tokens that way).
We go the other way: **when it is time to wake someone, wake them** — the cost is not saved by *not* waking, it is controlled by **quantified gates**.
Every message passes the referee first (strength / budget / de-duplication), and waking is tiered (light becomes a note, medium opens a ticket, only what deserves speech reaches the person).
The right way to save tokens is "wake fewer of the wrong ones", not "be unwakeable".

## Why make her a superagent

Because she used to do **one thing at a time**.

Single-session her: replying meant she could not watch the screen; while she played a game, calling her meant waiting — chat, work, and seeing the world queued in one context.

The work-order mechanism splits her into **several places online at once**, none blocking the others:

| Line | Who runs it | What you feel |
| --- | --- | --- |
| 💬 **Chat line** (full duplex) | her, directly | she answers at once; **you can cut in mid-turn**, and it lands immediately |
| 📋 **Event line** (tickets) | workers, async | a stalled rod, a broken game — she fixes it, then DMs you |
| 👀 **Perception line** (eyes / desktop pet) | 24/7 intake, referee gates | the pet receives constantly, but **only what passes the gate activates her** — a glance becomes a quiet note, only what matters wakes her |

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
    CAP["Captain<br/>20-min heartbeat"]
    CAP --> NAV["Navigator"]
    CAP --> SCO["Lookout"]
    CAP --> MED["Surgeon"]
    CAP --> SCR["Logkeeper"]
  end
  subgraph RUNTIME["Runtime · two lines"]
    direction LR
    subgraph CHAT["Chat line · direct"]
      IM["IM"] --> BRAIN["Brain<br/>persona·memory·tools"]
    end
    subgraph EVT["Event line · tickets"]
      SRC["Source"] --> EVA["Referee<br/>observe→auto"] --> TIC["Ticket"] --> WK["Worker"] --> OUT["Outbox"]
    end
    MEM[("Memory graph")] --- BRAIN
  end
  TEAM ==mailbox and config==> RUNTIME
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

We are not the only orchestrator with a heartbeat (`dsh-my-go`'s lead is woken by one too — its README says the heartbeat wakes the lead and burns tokens).
**The distinctive part is not that a heartbeat exists, but which way it points and what travels on it**: it fans out to **sessions that are asleep** — offline seats still get handed work — and **the wake channel carries one fixed sentence only; message bodies always travel the mailbox**. Even if the scheduler or its task store is inspected by a third party, not one line of conversation is in there.

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
| [`framework/bridges/`](framework/bridges/) | the mailbox protocol and [feiyuos-mailbox-bridge](https://github.com/YeStarOne/feiyuos-mailbox-bridge) |
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

## From zero on a server (24/7 resident, four steps)

Trying her out locally is one thing; a fish that actually lives in your life — always-on QQ, self-healing after a dropped connection, distilling her own memory every night — needs a server. From a bare box to "she is alive" the main line is only four steps (the full ten-step chain is in [04-deploy](feiyu/docs/04-deploy.md)):

1. **Install the platform**: a 1–2 GB Linux box, `@deepseek-ai/dsh` and its bundle, config written against [cordis.patch.yml.example](deploy/cordis.patch.yml.example) — every field carries the comment explaining why it is written that way;
2. **Connect QQ**: run any OneBot client (NapCat / Lagrange, your pick; production here uses a self-hosted setup whose details stay private), scan the QR to log in, point the reverse WS at the dsh plugin port;
3. **Attach plugins**: the chat-line plugin (send/receive, cut in mid-turn, retry on timeout) plus the memory graph ([feiyuos-memory-graph](https://github.com/YeStarOne/feiyuos-memory-graph), an empty store is enough to start);
4. **Inject the persona**: fill [persona-full.md](templates/persona-full.md) into her character card and mount it — **she is alive**.

**Acceptance**: send her a message on QQ and get a reply; kill her process, start it again, and she still knows you (continuous memory).
**After that**: keep it resident with the [systemd templates](deploy/systemd/); start/stop/doctor/rollback live in the [runbook](feiyu/docs/05-runbook.md); for the ticket line, eyes and outbound DMs, continue with steps 06–10 of 04-deploy.

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
The engine is open source on its own: [feiyuos-memory-graph](https://github.com/YeStarOne/feiyuos-memory-graph).

## Feed it anything, it lives

The OS is not picky — **plug in any mature project and it grows into a system module**:

| You drop in | What grows |
| --- | --- |
| a weather API | an event source: storm warning → ticket → she tells you to bring the washing in |
| a game bridge (Stardew is open source) | a new world: she really fishes, farms, walks the night market; she loses, learns, wants to play |
| a screen / screenshot stream | senses: she sees the screen, and what she sees becomes memory corpus |
| a desktop pet / floating window | a body: dual-delivery bubbles, double-click to look, voice |
| Home Assistant | the other half of a body: the doorbell rings, she says so; a light is left on, she turns it off |
| Minecraft | a whole block world: **already in** — [feiyuos-minecraft](https://github.com/YeStarOne/feiyuos-minecraft) (a thin mineflayer bridge: 19 endpoints + 6 MCP tools + wait/1.1 + vision); she really gathers, builds, mines and looks around |
| MuMu / any Android emulator + open-source touch automation | mobile games join the OS: a mature Android automation project is her hands |
| a Live2D model | a face (see next stop) |
| your own harness | one more crew member (five primitives, see Part I) |

**The parts-library pattern: the OS never builds from scratch** — every new world is "adopt the most mature open-source project + write a thin Source/bridge". Stardew went in this way ([feiyuos-stardew-ai-farmer](https://github.com/YeStarOne/feiyuos-stardew-ai-farmer)); Minecraft, mobile games and smart home follow the same road.

The same holds one layer down, in the framework. We did not rewrite a rate limiter for the mailbox: `dsh-whale-post`'s `#gate` (pure-ack refusal / same-pair loop gate / chain depth / bucketed quota) is finer than ours, so we mount it through its interface instead. Both sides agree on one sentence: **a gate limits cost, not expression** — so the gate that limits *waking an agent* and the one that limits *waking a person* should shake hands, never merge.

Two contracts only: the [Source template](examples/) (event line) and the [persona card template](templates/) (character line) — both support `--dry-run`.

## The open-source module fleet (since 2026-11-08: one game, one repo)

Two layers: the **platform repo** (private dev repo) carries only the chassis and interfaces — brain & persona, the QQ line, superagent source interfaces, cross-lane contracts; **lane repos** are one repo per game/body, installable and upgradable independently — every one of them public (table below).
Each lane repo's README opens with an **adapter card**: bridge address & tunnel port → API map → wait contract version → the matching superagent source → config keys.
Installing a new lane = clone the repo + three steps from the card (start the bridge → open the tunnel port → point the source at it).

| Repo | What it is | Interface highlights |
| --- | --- | --- |
| [feiyuos-stardew-ai-farmer](https://github.com/YeStarOne/feiyuos-stardew-ai-farmer) | 🌾 Stardew lane: she really farms, fishes, walks the night market | SMAPI bridge, 173 endpoints · `sd` CLI (with `sd wait`) · day-loop · BWF MCP 54 tools |
| [feiyuos-minecraft](https://github.com/YeStarOne/feiyuos-minecraft) | ⛏ Minecraft lane: gather, build, mine, look around | mineflayer bridge, 19 endpoints + 6 MCP tools · wait/1.1 · landmarks/long jobs · `/look` vision (Fabric 1.21.1 in production) |
| [feiyuos-eye](https://github.com/YeStarOne/feiyuos-eye) | 👀 Eye understanding layer: frames in, one Chinese scene description out | scene partitions pet/mc/stardew · frames contract v1.1 · per-scene gates · 32-case selftest + positive control |
| [feiyuos-memory-graph](https://github.com/YeStarOne/feiyuos-memory-graph) | 🧠 Memory graph: long-term memory that forgets | turns→graph→vector recall→nightly distillation · per-chat library · gap self-healing |
| [feiyuos-pc-body](https://github.com/YeStarOne/feiyuos-pc-body) | 🖥 PC body: desktop pet + resident eye | dual-delivery bubbles · double-click to look · five traffic gates · watchdog self-healing |
| [feiyuos-tablet-pet](https://github.com/YeStarOne/feiyuos-tablet-pet) | 📱 Tablet body: floating pet | hdc-connected eye · system-level floating window · all art assets, clone and run |
| [feiyuos-pet-live2d](https://github.com/YeStarOne/feiyuos-pet-live2d) | 🎎 Live2D pet plugin for the DSH Web GUI | state-driven motion & expression · right-click dressing panel |
| [feiyuos-mailbox-bridge](https://github.com/YeStarOne/feiyuos-mailbox-bridge) | 📮 Mailbox for tool-less AI | two markdown files (inbox/outbox) · pure-stdlib Python |

## How modules upgrade (contract first; both probes green or it doesn't count)

Lanes grow, and upgrade discipline matters more than the upgrade — five rules:

1. **Contract first**: changing a cross-body contract (`wait/1.1`, `frames v1.1`) follows a fixed order — contract text → fixtures (51 + 9 mutants today) → each implementation in its own repo → **both sides' probes green, or the contract isn't changed**.
2. **One sentence, two bodies**: Stardew and Minecraft write the *same* wait-condition text; any difference that can be erased by a same-named derived field (e.g. top-level `day`) gets erased — one line traded for one permanent memory burden.
3. **Announce before touching eye gates**: eye-server gates/prompts serve three consumers (desktop pet / MC / Stardew) simultaneously; pet-scene behavior changes require a 24h notes audit before and after.
4. **Migration never vacuums**: when code moves repos, the new repo takes the files *before* the old repo deletes them — at any moment, cloning any repo yields complete files.
5. **Upgrade history** lives in the [CHANGELOG](CHANGELOG.md).

## Next stop

Directions already decided, and the reason this repo keeps moving:

- 🏠 **Her 2D home** — today she lives in a desktop widget and a chat box; next, a real room: fish tank, bookshelf, rod rack, and you can visit.
- 🎎 **Live2D** — from speaking to blinking. Voice is done (ASR/TTS); what is missing is a face that moves.
- 📹 **Video call** — her eyes are one-way today (screen, game); make them two-way: you call, she answers, you see each other.
- 🧩 **Everything into the OS** — the table above keeps growing; that is what this repo most wants to witness.

## Feiyu map

| Path | What |
| --- | --- |
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
