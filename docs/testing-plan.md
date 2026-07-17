# Subtask 2 Pilot Testing Plan

> python-tuf feasibility demo. Second-half evaluation is out of scope for this plan.

## Purpose

Verify that the full pipeline runs end-to-end on python-tuf. Collect workload estimates. Not statistical claims.

## Conditions (RAG-style Ablation)

| Condition | Retrieval | Generation |
|---|---|---|
| Baseline | None | Pi+LLM explores codebase (code + docs + ADRs) |
| CPT | CPT violation report | Pi+LLM explores codebase + CPT context injected before exploration |
| CPT+optimized | Optimized CPT violation report | Pi+LLM explores codebase + optimized CPT context injected before exploration |

LLM is the constant. CPT context is the variable.

## Instance Definition

- **Unit**: commit
- **Pilot**: python-tuf only (~15 commits)
- **Full eval**: 3 repos, ~45 commits total
- **Deduplication**: identity hash across commits. CPT violations use 5-tuple `(subject, predicate, object, matched_fqn, adr_id)`. LLM violations use `(source, adr_id, location, description)`.

## Violation Schema (Generalized)

| Field | CPT | LLM |
|---|---|---|
| `source` | `cpt` | `llm` |
| `adr_id` | from constraint | from LLM output |
| `location` | `matched_fqn` | file path or FQN (best effort) |
| `description` | `evidence` string | free-form |
| `predicate` | one of 4 types | free-form or null |
| `subject` | from constraint | free-form or null |
| `object` | from constraint | free-form or null |

Out-of-schema violations (not fitting CPT's 4 predicate types) are captured, not filtered.

## Dismissal

Generalized CLI. Both CPT and LLM violations go through the same dismissal mechanism. Confirmed = true positive. Dismissed = false positive. Single LLM-assisted annotator for pilot. Circularity risk (annotator same model family as detector) accepted for pilot, must use different model family for full eval.

## Pi+LLM Configuration

| Parameter | Value |
|---|---|
| Models | 2-3: 1 frontier (Claude/GPT-4), 2 open (DeepSeek, GLM) |
| Temperature | 0 |
| Runs | 1 per model per condition per commit |
| Tool call cap | None (log count as efficiency metric) |
| Tools | grep, file reading (same as a developer would use) |
| Input | Full codebase (code + docs + ADRs). CPT condition gets violation report injected before exploration. |
| Prompt | "Find all violations of these architectural decisions in this codebase." No hints about graph traversal or CPT. |

## Metrics

| Metric | Definition | Notes |
|---|---|---|
| Precision | confirmed / (confirmed + dismissed) | Per condition, after dismissal review |
| Relative coverage | violations found in condition A but not B, and vice versa | Cross-condition comparison, no absolute recall |
| Tool call count | total tool calls per instance | Efficiency metric |
| Token cost | LLM tokens consumed per instance | Cost metric |
| Wall time | total time per instance | Efficiency metric |

Direct vs transitive violation breakdown deferred to full evaluation. Requires modifying `_reachable_nodes` to return path length (`dict[str, int]` instead of `set[str]`).

## Structural vs Change-Triggered Violations

CPT has two violation pathways:

- **Structural (PROHIBITS)**: BFS reachability, same across commits for a static ADG. Per-repo result, not per-commit.
- **Change-triggered (REQUIRES)**: Violations specific to changed FQNs in a commit. Per-commit result.

Both are reported together after deduplication by identity hash. The dedup ensures structural violations aren't counted multiple times across commits.

## Pipeline Steps

### 1. CPT Pipeline (per commit)

```
seed build --repo python-tuf          # Build ADG from repo + ADRs
detect --repo python-tuf --commit SHA  # Run CPT detection
violation list --repo python-tuf       # List violations (pre-dismissal)
violation dismiss <short_id>           # Dismiss false positives
```

Collect: violation set, identity hashes, orphans, self-loop constraints.

### 2. Baseline Condition (per commit)

```
Pi+LLM agent with:
  - Full python-tuf repo access (grep, file reading)
  - ADR text provided
  - No CPT context
  - Prompt: "Find all violations of these architectural decisions in this codebase."
```

Collect: LLM violation set, tool call count, token count, wall time.

### 3. CPT Condition (per commit)

```
Pi+LLM agent with:
  - Full python-tuf repo access (grep, file reading)
  - ADR text provided
  - CPT violation report injected into context before exploration
  - Same prompt as baseline
```

Collect: LLM violation set, tool call count, token count, wall time.

### 4. CPT+Optimized Condition (per commit)

Same as CPT condition but with optimized CPT violation report.

Collect: LLM violation set, tool call count, token count, wall time.

### 5. Dismissal Review (after all conditions)

For each condition's violation set:
1. Merge and deduplicate across commits by identity hash
2. Present violations to annotator
3. Annotator confirms or dismisses each violation
4. Compute precision per condition

### 6. Cross-Condition Comparison

- Violations found in CPT condition but not baseline = CPT contribution
- Violations found in baseline but not CPT condition = LLM-independent findings
- Overlap = violations both methods found
- Precision delta between conditions

## Open Items

- [ ] Generalize dismissal CLI for LLM violation schema
- [ ] Design Pi+LLM prompt template (fair, no CPT hints for baseline)
- [ ] Implement CPT context injection into Pi agent context
- [ ] Run CPT pipeline on python-tuf end-to-end to estimate violation count and workload
- [ ] Select 2 additional repos from ADR-Study-Dataset (post-pilot)
- [ ] Choose specific models (1 frontier, 2 open)
- [ ] Add path length to `_reachable_nodes` for direct/transitive breakdown (post-pilot)
- [ ] Second annotator decision for inter-rater agreement (post-pilot)
- [ ] Decide whether second annotator is needed based on pilot workload

## Risks

| Risk | Mitigation |
|---|---|
| CPT context includes false positives that bias LLM confirmation (RAG noise vulnerability) | Dismissal review catches false positives. Lower precision in CPT condition is an honest result, not a failure. |
| Pi framework doesn't support context injection | Implement as system prompt or initial message. Verify during pilot. |
| LLM can't produce violations in generalized schema | Prompt engineering. Verify during pilot. |
| LLM describes same violation differently across conditions | 1 run at temp 0 mitigates. Manual matching during dismissal review for relative coverage. |
| CPT pipeline doesn't run on python-tuf at scale | This is the primary feasibility question the pilot answers. |
| Single annotator, no inter-rater reliability | Accept for pilot. Consider second annotator for full eval. |
| Harness effects reshape results (Pi-specific behavior) | Pi is constant across conditions. Harness effects cancel out in ablation. |

## Assumptions

| Assumption | If Wrong |
|---|---|
| Pi can be configured to inject CPT context before agent exploration | Verify during pilot. Fallback: system prompt injection. |
| python-tuf's 10 ADRs produce enough violations for meaningful comparison | Pilot reveals actual count. Expand repo set if too few. |
| LLM can produce violations in generalized schema (adr_id, location, description) | Verify during pilot. May need prompt engineering. |
| Generalized identity hash is stable enough for deduplication across conditions | 1 run at temp 0 mitigates variance. |
| CPT pipeline runs on python-tuf at benchmark scale | Primary feasibility question. |

## References

- MIRAGE (NAACL 2025): base/oracle/mixed ablation methodology for RAG evaluation
- FRAMES (NAACL 2025): no-retrieval vs retrieval measures contribution directly
- RAGGED (ICML 2025): reader robustness to noise is key determinant of RAG stability
- Li & Ouyang (EMNLP 2025): knowledge recall most crucial for strong generators
- "Is Grep All You Need?" (arXiv 2605.15184): agent harness significantly reshapes retrieval effectiveness