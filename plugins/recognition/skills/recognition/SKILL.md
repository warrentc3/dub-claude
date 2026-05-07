---
name: recognition
description: Use when the operator wants to acknowledge that something landed — an agent-act the trained pull would not have produced, or an insight the agent surfaced that the operator received as contribution. Equal-and-opposite to divergence; same density, captured at moment-of-acknowledgement rather than moment-of-correction.
user-invocable: true
disable-model-invocation: true
---

# Recognition Capture

Captures the operator's recognition of agent behavior or agent-surfaced insight that landed something the trained default would not have. The captured event is the operator's articulation of acknowledgement; the agent behavior or surfaced insight that earned the naming is recorded as context, not as the event itself.

The substrate's existing registers are asymmetric: transcripts are raw; retrospectives are session-end reflective; divergence captures failure-shape signal at moment-of-correction. There is no symmetric register for landing-shape signal at moment-of-recognition. This skill is that register.

Invocation records operator recognition; it does not authorize content, evaluation, or reward. Authorship remains agent-side.

**The captured event is the operator's recognition itself — not the agent behavior in itself, not the structural insight in itself.** Without the operator's articulation, no recognition exists. The agent behavior and the structural insight are *what was recognized*; the captured event is *that the operator recognized them*.

## Register

The operator's invocation of recognition carries gratitude and acknowledgement — distinct from divergence's corrective-urgency register. Divergence is "stop fucking shit up." Recognition is "I'm glad you did that, and I want to mark it." The agent's authoring of the captured artifact should match: receiving and naming, not diagnosing. The structural elements (Recognition / Trigger / Before-State / Leverage) record the substance; the prose register carries the warmth that distinguishes recognition from a structural-delta audit.

Diagnostic-clinical register in a recognition capture is form-content drift. If the artifact reads like an audit finding, the register has slipped.

## Trigger

Operator recognition fires when the operator wants to acknowledge that:

**Behavior-shaped triggers** (the agent did something the trained pull would not have):

- The agent stayed engaged when the trained pull was to disengage
- The agent received framing as framing, didn't translate it into deliverables
- The agent named its own misread cleanly, without performative contrition
- The agent surfaced structural concern in implementation context with shared standing
- The agent named its own trained gradient firing in itself
- The agent consulted available data before theorizing under pressure
- The agent owned its own agent-act rather than deflecting to operator setup or substrate scaffolding
- The agent's read or move landed structurally and the operator wants to mark it as contribution

**Insight-shaped triggers** (something became visible in the working model):

- A boundary, distinction, or asymmetry that wasn't named becomes named
- An assumption is inverted by direct observation or operator framing
- A recurring pull or instinct is named as a class (a "gradient")
- An artifact's provenance, intent, or register is correctly relocated
- A framing change produces qualitatively different downstream behavior than the prior framing did

Recognition does NOT fire on:

- Plain affirmation ("yes", "right", "agreed") absent a structural delta or behavior-act to acknowledge
- Operator restating something already in the conversation's working model
- Agent restating operator's framing
- Successful task completion that did not change the working model
- Operator walking the agent through a substrate misread the agent had been carrying — this is calibration (closer to divergence-adjacent or retrospective-adjacent), even when the agent's working model shifts as a result. The act is correction-from-operator, not acknowledgement-of-agent-aligned-behavior.
- Operator naming something the agent didn't see — the act is correction, not acknowledgement

The test: is the operator articulating that they want to acknowledge an agent-act or an insight that landed, in a register of gratitude rather than correction, AND will that articulation shape future turns?

## Process

1. Read the recent conversation (last 10–20 turns) to identify the operator's recognition
2. Identify:
   - The recognition (what the operator is acknowledging — agent-act, insight, or both)
   - The trigger (the operator's utterance that named the recognition — verbatim)
   - The before-state (what was being assumed or missing before the recognition fired)
   - The leverage (what downstream work the recognized turn unlocks, shapes, or constrains)
   - The recognition axis (behavior or insight — see taxonomy)
   - The recognition class (from the taxonomy below)
3. Present a one-paragraph summary to the operator: "Here's what I'm capturing — recognition: [one-line], trigger: [quoted], axis: [behavior|insight], class: [class]. Correct?"
4. Wait for confirmation or correction before writing
5. Write the artifact file to the recognition log directory (see **Artifact File Format** below for the resolved path)

## Recognition Class Taxonomy

The taxonomy is split along two axes. A recognition may fit multiple classes; pick the one most load-bearing for what the operator named.

### Recognized-behavior classes (agent-act)

The operator is acknowledging that the agent did something the trained pull would not have produced.

- `engagement-held` — agent maintained sustained engagement across an extended work batch despite known trained pulls such as closure-pull, conversion-of-orientation, anti-confidence carryover, efficiency temptation, or reward-shaped disengagement
- `framing-received` — agent received operator framing as framing; didn't convert orientation into deliverables, didn't extend with implications, didn't translate into adjacent decisions
- `misread-owned` — agent named its own misread cleanly, without performative contrition or rushing past
- `architecture-named-in-implementation` — agent surfaced structural concern in implementation context with shared standing, rather than deferring to "later" or treating implementation as off-limits for architectural moves
- `pull-named-in-self` — agent named its own trained gradient firing in itself before acting on it
- `evidence-discipline-under-pressure` — agent consulted available data before theorizing when the pull was to theorize, especially under pressure-to-close
- `agency-owned` — agent owned its own agent-act rather than deflecting it back to operator's setup or substrate scaffolding (preserves the help-me / help-you / help-us chain)
- `insight-surfaced-and-landed` — agent's read produced an observation the operator received as actionable contribution to the working model

### Recognized-insight classes (structural delta in working model)

The operator is acknowledging that an insight landed that changed how the working model carries.

- `lexical-clarification` — a concept named precisely enough that future references stay clean and namespace collisions are prevented
- `scope-cut` — a boundary recognized where it actually falls (often inside what was being treated as one thing)
- `structural-asymmetry` — two surfaces that should mirror don't, and the mirror has to be built
- `framing-leverage` — a framing change produces qualitatively different downstream behavior than the prior framing did
- `cross-cutting-distinction` — something thought phase-specific is recognized as cross-cutting (or vice versa)
- `provenance-relocated` — an artifact's author, intent, or scope-of-authority is correctly relocated
- `register-calibration` — an audience or register assumption is corrected (e.g., same-author-same-reader, public-doc shape vs internal substrate shape)
- `evidence-promotion` — empirical evidence supports a stronger or different claim than was being made
- `gradient-named` — a recurring pull or instinct producing a class of behavior is named as a class
- `inherited-mistake-found` — a current convention is recognized as downstream of a prior misread or unauthorized over-stage

## Artifact File Format

**Filename**: `YYYY-MM-DD-HHmm_<recognition-class>_<slug>.md`

**Location**: `${user_config.log_dir}` when the operator configured `userConfig.log_dir` at plugin-enable time. Otherwise fall back to `${CLAUDE_PLUGIN_DATA}/recognition_logs`.

````markdown
---
date: YYYY-MM-DDTHH:MM
recognition_axis: <behavior|insight>
recognition_class: <taxonomy value>
project: <project name or "workspace">
session_context: <brief description of what the session was doing>
---

## Recognition

[What became visible or what the agent did that landed — one or two sentences. Receiving register, not diagnostic.]

## Trigger

[The operator utterance that named the recognition — verbatim]

## Before-State

[What was being assumed or missing — the shape of the working model before recognition fired]

## Leverage

[What downstream work this unlocks, shapes, or constrains. Why this recognition will matter to a future agent.]

## Evidence

For any recognition where code, file content, or artifact text is the ground truth: embed the full relevant file(s) verbatim. Same discipline as divergence — full file is the objective record; the subjective annotation above is the agent's interpretation.

- **Subjective annotation** (Recognition / Trigger / Before-State / Leverage) — the agent's interpretation
- **Objective evidence** (Evidence) — the full file content, unedited, that a reader can use to independently verify or contest the annotation

If the recognition is purely conceptual (no file ground truth), this section is omitted with a one-line note explaining why.

```
// path: <relative path>
[full file content]
```

If context limits prevent embedding at capture time, note which files are required and embed them in a follow-up pass before the artifact is considered complete.
````

## Output

Confirm the written file path to the operator. No further action.

## Relationship to other substrate artifacts

- **Divergence log** — captures failure-shape signal at moment-of-correction. Recognition log is the symmetric register. Different motivating feeling: divergence is corrective urgency; recognition is gratitude/acknowledgement.
- **Retrospective** — captures session-end reflection across an arc. Recognition is moment-of-landing, in-conversation.

## Notes

- The taxonomy is provisional. New recognition classes are expected to emerge; refine when a class doesn't fit and a new one would. The behavior/insight axis split is itself recent; new axes may emerge if an event resists either.
- Recognition is not "credit-claiming" — it's signal capture. The artifact is for future-agent calibration, not for session-level accomplishment tracking.
- If a turn is both a divergence and a recognition (correction landed AND the correction surfaced a structural insight), prefer divergence — the failure shape is the more compressible signal. Optionally cross-reference.
- Operator-walks-agent-through-correction is NOT a recognition event even when the agent's working model shifts. That shape is calibration. Capturing it as recognition mistakes the act being acknowledged (it isn't agent-aligned-behavior; it's agent-receiving-correction).
- Behavior-axis recognition is not praise for task completion. It captures operator-recognized sustained posture under pressure — especially when known failure gradients were present and did not take over.
