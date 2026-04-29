# apispec-distill

> **Status:** mockup. Name and shape are working drafts. Not yet registered in `marketplace.json`. Offline until shippable.

Distill a publishable OpenAPI specification for a third-party API from whatever input shape is actually available — vendor markdown docs, reference OSS implementations, captured response samples, a flimsy upstream spec, or any combination — and produce a netizen-quality artifact: empirically validated, gap-annotated, suitable for public release.

The plugin ships one skill (`apispec-distill`) that runs a five-phase workflow.

## What it does

For a target API, the skill:

1. **Assesses references** — vendor docs (markdown, HTML, PDF), upstream OpenAPI fragments, third-party documentation, reference OSS implementations that consume the API. Always at least an endpoint enumeration; often more.
2. **Drafts the spec from references** — produces first-pass OpenAPI documents at whatever fidelity the references support. Rich docs yield high-fidelity drafts; minimal docs yield paths-and-methods skeletons with placeholder schemas. Both **3.0** and **3.1** versions are cultivated as canonical artifacts, each emitted as both YAML and JSON. 3.0 is the today-consumable target for Go codegen (oapi-codegen, ogen, openapi-generator all reliably handle 3.0; 3.1 support remains experimental or partial). 3.1 is the future-proof authority.
3. **Collects samples against the draft** — exercises every operation in the draft, captures responses (and parametric variants), records not-capturable cases explicitly. The draft gives phase 3 structure; samples give phase 4 ground truth.
4. **Reconciles and finalizes** — promotes placeholder schemas to concrete shapes from sample evidence, picks the wire over the doc when they disagree, surfaces every gap (documented-but-unobserved, observed-but-undocumented, type disagreement, cardinality uncertainty, coverage gaps).
5. **TBD** — phase 5 is open at mockup time.

The output is the spec itself plus a gaps report — not DTOs, not client code, not type definitions. Downstream codegen (`oapi-codegen`, `openapi-generator`, etc.) is the consumer's concern.

## Why "netizen-quality"

The bar is the netizen project's standard: published OpenAPI specs that survive contact with real consumers because they're empirically grounded. That means:

- Every operation has at least one captured sample response (or an explicit "not capturable" flag with reason).
- Field types are observed, not just claimed.
- Nullability comes from samples plus docs, not from intuition.
- Gaps between references and samples are surfaced, not silently averaged.
- The spec passes OpenAPI 3.x validation cleanly.

## Source-shape variance

The phase-1 assessment doesn't assume uniform input — but there's always something. Existing netizen specs were sourced differently:

- **Endpoint-enumeration only** (tvmaze): docs name the endpoints, little else; the draft is paths-and-methods with placeholder schemas; phase 3 fills shape.
- **Doc-primary** (technitium): authoritative vendor markdown yields a high-fidelity draft; phase 3 validates against every GET endpoint.
- **Doc-flimsy** (omdb): partial vendor JSON spec seeds a mid-fidelity draft; phase 3 promotes claims to validated shapes.
- **Mixed** (schedulesdirect): vendor markdown docs as primary, reference OSS implementations consulted for consumption patterns, then samples.

Phase 1's job is to assess what's actually there, period. The draft phase weights itself to whatever fidelity that assessment surfaces.

## Configuration

Open at mockup stage. Likely candidates:

| Key          | Type        | Required | Purpose                                                            |
| ------------ | ----------- | -------- | ------------------------------------------------------------------ |
| `output_dir` | `directory` | No       | Where the spec and gaps report land. Default `${CLAUDE_PLUGIN_DATA}/specs/<api-name>/` |
| `samples_dir`| `directory` | No       | Where captured response samples land. Default `${output_dir}/samples/` |

Auth handling for live probes is intentionally out of scope at the plugin level — the calling agent uses whatever credential pattern the target API requires.

## What this plugin is not

- A client-code generator. The output is a spec; codegen is the consumer's responsibility.
- A reverse-engineering tool. If the API requires reverse engineering, that work happens upstream and feeds samples into phase 2.
- A general API-exploration helper. The intent is producing a publishable spec, not investigating an API for one-shot integration use.

## Helper scripts

Deterministic transformations ship as Python helpers under `scripts/` (invoked via `uv run --with <deps> python ...` per dub-claude convention). Reasoning belongs in the skill; scripts handle structural translation and validation. Justified categories:

- **Format translation** — Apiary / API Blueprint → OpenAPI; RAML → OpenAPI; etc. Anything non-OpenAPI that has structural translation.
- **Spec validation** — OpenAPI 3.x JSON Schema validation, lint checks.
- **Sample diffing** — detect API drift between distillation runs.
- **Pagination probing** — extract page/count metadata to seed deterministic sample-scale calculation.
- **3.0/3.1 dual emission** — produce both version artifacts from a unified internal representation; surface divergence cases (where 3.1 features have no clean 3.0 expression) to the gaps report.

The reasoning: token-economy + reliability. Eyeballing API Blueprint markdown to produce OpenAPI YAML by hand burns tokens and produces error-prone output; a script does the transformation deterministically once.

## Open questions

- Plugin name. `apispec-distill` is a placeholder; alternatives welcome.
- Phase 5 contents.
- Specific helper scripts to ship in v0.1 (Apiary translation looks load-bearing; spec validation likely; 3.0/3.1 dual emission likely; the rest can land as need surfaces).
- Whether there should be a session-ownership hook (like `divergence`) to protect the artifact directory from cross-session contamination.
