# Pi+LLM Prompt Template

Frozen 2026-07-22. Any change requires updating this date and re-running affected conditions.

## Baseline Prompt

You are reviewing a codebase for violations of its architectural decisions.

Below are the project's Architectural Decision Records (ADRs). Each ADR documents a decision about the system's architecture: what was chosen, why, and what constraints it imposes.

Read each ADR carefully, then search the codebase for code that violates those decisions. A violation is any code that contradicts, bypasses, or ignores an architectural constraint stated in an ADR.

{adr_text}

For each violation you find, report it as a JSON object with these fields:

- `adr_id`: the ADR number (e.g., "0006") whose constraint is violated
- `location`: the file path or fully qualified name where the violation occurs
- `description`: one-sentence explanation of how the code violates the ADR
- `predicate`: the type of violation, if you can classify it (e.g., "prohibits_dependency", "prohibits_implementation", "requires_dependency", "requires_implementation"); otherwise null
- `subject`: the architectural element that the constraint applies to, if identifiable; otherwise null
- `object`: the architectural element that the constraint forbids or requires, if identifiable; otherwise null

Return a JSON array of violations. If you find none, return an empty array.

## CPT Condition Prompt

Same as baseline, but with CPT context injected before the ADR text:

You are reviewing a codebase for violations of its architectural decisions.

Below are the project's Architectural Decision Records (ADRs). Each ADR documents a decision about the system's architecture: what was chosen, why, and what constraints it imposes.

Read each ADR carefully, then search the codebase for code that violates those decisions. A violation is any code that contradicts, bypasses, or ignores an architectural constraint stated in an ADR.

{cpt_violation_report}

Below are the ADRs for reference:

{adr_text}

For each violation you find, report it as a JSON object with these fields:

- `adr_id`: the ADR number (e.g., "0006") whose constraint is violated
- `location`: the file path or fully qualified name where the violation occurs
- `description`: one-sentence explanation of how the code violates the ADR
- `predicate`: the type of violation, if you can classify it (e.g., "prohibits_dependency", "prohibits_implementation", "requires_dependency", "requires_implementation"); otherwise null
- `subject`: the architectural element that the constraint applies to, if identifiable; otherwise null
- `object`: the architectural element that the constraint forbids or requires, if identifiable; otherwise null

Return a JSON array of violations. If you find none, return an empty array.

## CPT+Optimized Condition Prompt

Same as CPT condition, with `{cpt_violation_report}` replaced by `{optimized_cpt_violation_report}`.

## Template Variables

| Variable | Source | Notes |
|---|---|---|
| `{adr_text}` | Concatenated ADR markdown files from target repo | Raw ADR content, unmodified |
| `{cpt_violation_report}` | Output of `violation list` command | Full CPT violation report |
| `{optimized_cpt_violation_report}` | Optimized/filterd CPT violation report | TBD: optimization strategy |

## Design Decisions

1. **No CPT-specific hints in baseline**: the baseline prompt does not mention graph traversal, constraint types, reachability, or any CPT concept. It treats ADRs as natural-language constraints, which is what a developer would actually read.
2. **Same task description across conditions**: the only difference is the injected CPT context. This isolates the variable (retrieval augmentation) while keeping the generation task identical.
3. **JSON output schema**: matches the generalized violation schema from the testing plan. `predicate`, `subject`, and `object` are nullable because LLM free-form output cannot always extract structured constraint triples; CPT fills these deterministically.
4. **Repo-agnostic**: no repo name, language, or domain-specific terms in the template. Placeholders inject repo-specific content at runtime.
5. **Model-agnostic**: no system prompt tricks, no chain-of-thought scaffolding, no few-shot examples. The prompt works with any instruction-following model.

## Acceptance Criteria Mapping

- [x] Prompt template is documented and frozen (this file)
- [x] Template asks LLM to find violations of architectural decisions
- [x] No CPT-specific hints in the baseline variant
- [x] Output schema matches the generalized violation schema (adr_id, location, description, predicate, subject, object)
- [ ] Template works across all planned models (1 frontier, 2 open) — verified during pilot runs