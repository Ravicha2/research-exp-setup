# CPT Dry Run on python-tuf

**Date:** 2026-07-21  
**Commit:** 6889cfbffbb90a17930fbdedf12ae050be775fe3

## Pipeline Results

### seed build
- Nodes: 299
- Edges: 728
- Constraints extracted: 38 (0 errors)
- Constraint edges: 52
- External nodes: 9
- Dismissals cleared: 3 (from previous run)

### detect
- Compared: 5498726..6889cfb
- Changed files: 2 (both `.github/workflows/`)
- Changed FQNs: 0 (workflow files are not Python)
- Violations: 10
- Orphans: 0
- Self-loop constraints: 0

### violation list
- Total violations: 10
- Active (not dismissed): 10
- Dismissed: 0

## Violation Breakdown

| Predicate | Count | ADR IDs |
|---|---|---|
| prohibits_dependency | 5 | index (2), 0006 (2), 001 (1) |
| prohibits_implementation | 5 | 0008 (1), 0010 (2), 0006 (2) |

### All 10 Violations

| short_id | ADR | Predicate | Subject | Object | Matched FQN | Match |
|---|---|---|---|---|---|---|
| 27784 | 001 | prohibits_dependency | app.routes.* | app.models.* | app.routes.users | wildcard |
| fe825 | index | prohibits_dependency | tuf.api.metadata.Metadata | tuf.api.metadata.* | tuf.api.metadata.Metadata | exact |
| 8882b | 0008 | prohibits_implementation | tuf.api.metadata.Metadata | tuf.* | tuf.api.metadata.Metadata | exact |
| 6f124 | 0010 | prohibits_implementation | tuf.repository._repository.Repository | tuf.repository.* | tuf.repository._repository.Repository | exact |
| 851b8 | index | prohibits_dependency | tuf.api.metadata.* | tuf.api.metadata.Metadata | tuf.api.metadata.Metadata | exact |
| 71f51 | 0006 | prohibits_implementation | tuf.api.serialization.* | tuf.api.metadata.Metadata | tuf.api.serialization.json | exact |
| 7d1f5 | 0006 | prohibits_implementation | tuf.api.serialization.* | tuf.api.metadata.* | tuf.api.serialization.json | wildcard |
| aea92 | 0006 | prohibits_dependency | tuf.api.serialization.* | tuf.api.metadata.Metadata | tuf.api.serialization.json | exact |
| f9473 | 0006 | prohibits_dependency | tuf.api.serialization.* | tuf.api.metadata.* | tuf.api.serialization.json | wildcard |
| 53bc3 | 0010 | prohibits_implementation | tuf.repository.* | tuf.repository._repository.Repository | tuf.repository._repository | exact |

## Workload Estimate

- 10 violations to review per commit
- ~15 pilot commits planned = ~150 violation reviews (minus dedup across commits)
- Structural violations are constant across commits, so dedup will reduce total count significantly
- Violation 27784 (adr 001) references `app.routes.*` which appears to be from a Flask template ADR, not python-tuf specific. Likely a false positive from constraint extraction.

## Bugs Fixed During Dry Run

1. **Hidden directory crash**: `parse_repo` included `.github/` Python files, producing invalid FQNs starting with `.`. Fixed by excluding paths where any component starts with `.`.
2. **Missing import**: `filter_dismissed` was used but not imported in `main.py`. Added the import.