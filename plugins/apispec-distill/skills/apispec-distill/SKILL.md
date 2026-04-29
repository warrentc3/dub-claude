---
name: apispec-distill
description: Use when the operator wants to produce a publishable OpenAPI specification for a third-party API. Synthesizes whatever inputs are actually available — vendor docs, OSS implementations, captured samples, flimsy upstream specs — into a single empirically-validated, gap-annotated spec. Output is the spec, not client code.
user-invocable: true
disable-model-invocation: true
---

# apispec-distill

Produces a netizen-quality OpenAPI specification for a target API. The output is empirically grounded — every operation either has at least one captured sample or an explicit not-capturable note — and gap-annotated where references and samples disagree.

The skill is a five-phase workflow. Each phase has its own discipline; later phases consume the persisted output of earlier ones.

## Status

Mockup. Phase 5 is intentionally TBD. Sample-handling, validation tooling, and the gap-report format are working drafts.

## Phase 1 — Reference assessment

Catalog what authoritative or quasi-authoritative material exists for this API. Categories:

- **Vendor-authored docs** — official markdown, HTML, PDF, knowledge-base articles, support-portal documentation. Range from rich (full operation reference) to minimal (endpoint enumeration only). All count.
- **Vendor-authored specs** — any existing OpenAPI / Swagger / RAML / JSON Schema fragments published by the vendor.
- **Reference OSS implementations** — open-source clients that consume this API. Read for *how* the API is actually consumed in practice, not as authority on the contract.
- **Third-party documentation** — community wikis, well-maintained blog posts, reverse-engineering writeups. Treat as evidence, not as authority.

Don't classify into a discrete mode upfront. Just assess what's there. The downstream phases naturally weight themselves to whatever fidelity phase 1 surfaces.

### Format-translation cases

When a reference's only available form is a non-OpenAPI format that has structural translation to OpenAPI, prefer a deterministic helper script over agent-eyeballing the markdown:

- **Apiary / API Blueprint** — markdown-shaped, structurally distinct from OpenAPI. Translation by reasoning is token-expensive and error-prone; a script that parses API Blueprint and emits OpenAPI 3.x is the right tool.
- (Other formats: RAML, WSDL, Postman collection — same principle if/when encountered.)

Use `scripts/` helpers when present; flag missing translations as a follow-up rather than improvising.

**Output:** a structured catalog (`phase1-references.md`) listing each source, its type, its relative authority, and what operations it covers.

## Phase 2 — Draft spec from references

Build a first-pass OpenAPI 3.x document from the phase-1 references. Fidelity matches what the references support:

- Rich vendor docs → high-fidelity draft (paths, parameters, request/response schemas with types and descriptions).
- Flimsy upstream spec → mid-fidelity draft (paths populated, schemas skeletal, types promoted from claims to TBD).
- Endpoint enumeration only → minimal draft (paths and methods, schemas left as `{type: object}` placeholders to be filled by phase 3).

The draft is structurally a real OpenAPI document — it validates against the OpenAPI 3.x schema, even when most properties are `additionalProperties: true` placeholders. Its purpose is to give phase 3 a target to collect against and a structure to fill in.

**Output:** Both OpenAPI versions, both formats:
- `${user_config.output_dir}/3.0/openapi.draft.yaml` + `openapi.draft.json`
- `${user_config.output_dir}/3.1/openapi.draft.yaml` + `openapi.draft.json`

Each version pair is its own deliverable, not a derived view of the other. 3.0 is the today-consumable artifact for Go codegen (oapi-codegen, ogen, openapi-generator all reliably handle 3.0; 3.1 support remains experimental or partial). 3.1 is the canonical authority — full JSON Schema 2020-12 expressiveness, future-proof for when codegen catches up. Cultivate both; never treat one as the lossy-derived view of the other.

Where 3.1 features have no clean 3.0 expression (`type: [..., null]`, `prefixItems`, sibling-`$ref`, `examples` plural), document the divergence in the gaps report rather than papering over it.

**Hard rule:** no API operation appears in the draft without phase-1 evidence about it. Operations the references don't mention can still surface later (phase 3 may discover them via API exploration), but phase 2's draft mirrors what the references actually establish.

## Phase 3 — Sample collection against the draft

### Pre-flight: inventory and auth split

Before any sample collection, walk the draft spec and produce a per-operation inventory:

- Count of operations by HTTP method and tag/group.
- Auth-required vs no-auth-required split (per the draft's `security` arrays and `securitySchemes`).
- Operations gated behind specific scopes / tiers / fixture-state requirements.

This inventory determines what credentials need to be staged, what subset of the API can be exercised with the credentials at hand, and roughly how much sample-collection work is ahead. Capture as `phase3-plan.md`.

### Sample scale — how much is enough

Per-operation collection target follows a deterministic-where-possible, heuristic-where-necessary discipline:

- **Per-operation minimum:** at least one captured response per in-scope operation.
- **Per-variant minimum:** at least one capture per parametric variant the draft anticipates (e.g., entity-type variation, success vs error envelopes, region-code variation).
- **Pagination-metadata anchor:** when an operation returns `total_count`, `total_pages`, or equivalent, the metadata establishes the cardinality space deterministically. Capture page 1 (or near-first), and a near-last/last page (partial-page edge case). The metadata answers "how many" without heuristic saturation.
- **Optionality saturation (heuristic):** for operations without pagination metadata, sample until N consecutive captures produce the same field set and types. N is operator-tunable; default 5. Beyond saturation, additional captures don't refine the schema.
- **Stochastic-presence acknowledgment:** some endpoints have legitimate randomness in field presence and never converge; phase 4 surfaces these as cardinality-uncertainty gaps rather than blocking on them.

### Collection mechanics

For each operation:

- Issue requests that exercise the operation, including parametric variants where structurally different shapes are expected. Where credentials are required, the calling agent uses whatever pattern the target API requires (OAuth, API key, session token, etc.) — auth handling is out of scope for this skill.
- Capture the full request and full response, including headers. Save to `${user_config.samples_dir}/<operation-id>.<variant>.json` (or `.xml`, depending on content type).
- Where an operation cannot be exercised (destructive operation, paid-tier-only, requires fixture state we don't have), record an explicit not-capturable note with the reason. Do not skip silently.
- When a sample reveals an operation or variant the draft didn't model, note it for phase 4 (the spec gets enriched, not silently extended in place).

**Output:** a directory of captured samples plus a `phase3-coverage.md` listing every operation with its sample status (captured-N-variants / not-capturable-because-X / discovered-during-collection / saturation-reached-at-N).

**Hard rule:** capture is one-shot in spirit — preserve raw bytes verbatim alongside any parsed view. Fields not stored at capture time are not recoverable from a re-capture six months later when the API has drifted.

## Phase 4 — Reconcile and finalize

Walk the draft spec against the samples and produce the final spec plus a gaps report.

Reconciliation moves:

- Where samples and references disagree on a field's type, nullability, or presence, prefer the sample. The vendor is allowed to be wrong about their own API; the wire isn't.
- Promote placeholder schemas to concrete shapes from sample evidence.
- Add operations and variants discovered during phase 3.
- For every schema or property, record provenance in `x-provenance` extensions: which references and which samples were consulted. Write-only forensic record for future maintainers.
- Populate `examples` blocks from real captured samples (redact secrets first).
- Validate the resulting document against the OpenAPI 3.x JSON Schema before declaring phase 4 complete.

Gap identification (in `gaps.md`):

- **Documented-but-unobserved** — fields the references claim exist but no sample shows.
- **Observed-but-undocumented** — fields the samples carry that no reference describes.
- **Type/nullability disagreement** — places where references and samples conflict, even after the spec picked a side.
- **Cardinality uncertainty** — array fields where samples never show >1 element; optional fields where samples never show absent.
- **Endpoint coverage gaps** — operations in the draft that have no sample (the not-capturable list).
- **Cross-entity variation** — where the same field name carries different shapes across entities (e.g., `id: int` for one entity, `id: string` for another).

**Output:**
- `${user_config.output_dir}/3.0/openapi.yaml` + `openapi.json` — the 3.0 deliverable.
- `${user_config.output_dir}/3.1/openapi.yaml` + `openapi.json` — the 3.1 deliverable.
- `gaps.md` — every gap with a reproducible reference (source file + line, or sample file + JSON path). Includes 3.0-vs-3.1 divergence entries where the two version artifacts express something differently.

## Phase 5 — TBD

Open at mockup stage.

## Discipline

- The spec is the deliverable. DTOs, client types, integration code, and codegen output are downstream of this skill's output, not within it.
- Subjective annotation belongs in `x-provenance` and the gaps report. The spec body itself is structural.
- "Netizen-quality" means: empirically grounded, validates cleanly against OpenAPI 3.x, every field type comes from observation or vendor authority (not intuition), gaps are surfaced rather than silently averaged.
- **Both 3.0 and 3.1 are cultivated as canonical artifacts.** 3.0 is the today-reliable codegen target across Go tooling; 3.1 is the future-proof authority. Neither is a derived view of the other. Where 3.1 expresses something 3.0 cannot, the divergence is named in the gaps report.
- Re-running the workflow against an updated API should produce a diff against the prior spec, not a wholesale rewrite. Phase 3 prefers the prior spec as a starting point when one exists.

## Output paths

Default layout under `${user_config.output_dir}` (or `${CLAUDE_PLUGIN_DATA}/specs/<api-name>/` if not configured):

```
<api-name>/
├── phase1-references.md         # reference catalog
├── 3.0/
│   ├── openapi.draft.yaml       # phase 2 deliverable, 3.0
│   ├── openapi.draft.json       # phase 2 deliverable, 3.0 (JSON form)
│   ├── openapi.yaml             # phase 4 deliverable, 3.0
│   └── openapi.json             # phase 4 deliverable, 3.0 (JSON form)
├── 3.1/
│   ├── openapi.draft.yaml       # phase 2 deliverable, 3.1
│   ├── openapi.draft.json       # phase 2 deliverable, 3.1 (JSON form)
│   ├── openapi.yaml             # phase 4 deliverable, 3.1
│   └── openapi.json             # phase 4 deliverable, 3.1 (JSON form)
├── phase3-plan.md               # endpoint inventory + auth-requirement split
├── phase3-coverage.md           # sample-coverage report
├── samples/
│   └── <operation-id>.<variant>.<ext>
└── gaps.md                      # gap-identification report (incl. 3.0-vs-3.1 divergence)
```

## Helper scripts

Deterministic transformations belong in scripts under `scripts/` (per dub-claude convention, Python invoked via `uv run --with <deps> python ...`). Reasoning belongs in this skill body.

Justified script categories — better for tokens, more reliable than agent reasoning:

- **Format translation** — Apiary / API Blueprint → OpenAPI 3.x; RAML → OpenAPI; etc. Whatever non-OpenAPI reference formats turn up in practice.
- **Spec validation** — OpenAPI 3.x JSON Schema validation; lint checks; `examples` coverage report.
- **Sample diffing** — comparing a fresh capture against a prior one to detect API drift between distillation runs.
- **Pagination probing** — extracting page/count metadata from a list-endpoint response to seed phase-3 cardinality calculations.

Helper scripts are invoked from the skill body when they exist; absent helpers are a flagged gap, not a license to improvise.

## What this skill does not do

- Generate client code, DTOs, or type definitions in any language.
- Make architectural calls about how a consumer should integrate the API.
- Reverse-engineer undocumented APIs (work that happens upstream feeds phase 2; does not happen inside this skill).
- Replace a vendor's authoritative spec when one is already published, complete, and validated. (If the vendor ships a clean OpenAPI 3.x, the appropriate output of this skill is "vendor spec is canonical, no distillation needed.")
