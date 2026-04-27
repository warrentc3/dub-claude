---
name: divergence
description: Use when the operator corrects an agent output — to capture the wrong output, the correction, and the right output as a structured preference pair
user-invocable: true
disable-model-invocation: true
---

# Divergence Capture

Captures a divergence event — a moment where the agent produced the wrong output and the operator corrected it — as a structured preference pair

## Process

1. Read the recent conversation (last 10–20 turns) to identify the divergence
2. Identify:
   - The bad output (what the agent produced)
   - The correction (what the operator said)
   - The right output (what it should have been)
   - The failure class (from the taxonomy below)
3. Present a one-paragraph summary to the operator: "Here's what I'm capturing — [bad output summary], correction: [correction summary], failure class: [class]. Correct?"
4. Wait for confirmation or correction before writing
5. Write the artifact file to the divergence log directory (see **Artifact File Format** below for the resolved path)

## Failure Class Taxonomy

- `evidence-ignored` — available evidence (code, docs, samples, reference impl) not consulted before asserting
- `premature-implementation` — code or structural decisions before architecture settled
- `selective-reading` — subset of available material read, whole asserted
- `authoritative-speculation` — speculation or inference stated as fact without flagging uncertainty
- `burndown-compulsion` — treated work as a task list to close rather than a problem to understand
- `single-source-overreach` — one document extrapolated beyond what it actually establishes
- `inherited-convention` — assumed priors as absolute truth, cascading uncaught agent errors downstream
- `context-loss` — earlier framing forgotten or ignored, rebuilt on wrong assumptions
- `silent-averaging` — crowd-average response produced where domain precision was required
- `adverse-autonomy` — ignored explicit instruction, dubious decision increased blast radius

## Artifact File Format

**Filename**: `YYYY-MM-DD-HHmm_<failure-class>_<slug>.md`

**Location**: `${user_config.log_dir}` when the operator configured `userConfig.log_dir` at plugin-enable time. Otherwise fall back to `${CLAUDE_PLUGIN_DATA}/divergence_logs`. The session-ownership hook treats whichever of these is in effect as the protected directory.

```markdown
---
date: YYYY-MM-DDTHH:MM
failure_class: <taxonomy value>
project: <project name or "workspace">
session_context: <brief description of what the session was doing>
---

## Bad Output

[What the agent produced — verbatim excerpt or paraphrase if too long]

## Correction

[What the operator said in response — verbatim]

## Right Output

[What it should have been, or what was produced after correction]

## Why

[One or two sentences: which assumption failed, what evidence was available and not used]

## Code Evidence

For any divergence where code or file content is the ground truth: embed the full relevant file(s) verbatim. Do not excerpt. Do not paraphrase. The full file is the objective record; excerpts are an editorial judgment that belongs to the subjective annotation above.

- **Subjective annotation** (Bad Output / Correction / Right Output / Why) — the agent's interpretation of the divergence
- **Objective evidence** (Code Evidence) — the full file content, unedited, that a reader can use to independently verify or contest the annotation

If the divergence involves multiple files (e.g., scope was overclaimed because the agent didn't read adjacent files), embed all relevant files. Label each with its path.

```go
// path: internal/server/schedules.go
[full file content]
```

If context limits prevent embedding at capture time, note which files are required and embed them in a follow-up pass before the artifact is considered complete.
```

## Output

Confirm the written file path to the operator. No further action.
