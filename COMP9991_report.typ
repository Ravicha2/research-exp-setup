#import "@preview/algorithmic:1.0.7"
#import "@preview/cetz:0.5.0"

#set document(
  title: "Real-Time Design-to-Code Consistency via Conflict-Aware Persistent Memory",
  author: ("Ravicha Suksawasdi Na Ayuthaya",),
  date: datetime(year: 2026, month: 7, day: 17),
)
#set page(paper: "a4", margin: (x: 2.2cm, y: 2.5cm), numbering: "1")
#set text(font: "New Computer Modern", size: 11pt, lang: "en")
#set par(justify: true, leading: 0.85em, first-line-indent: 1em)
#set heading(numbering: "1.1")
#show link: set text(fill: blue.darken(20%))

// Theorem/definition environments
#let thm-counter = counter("theorem")
#let make-env(kind) = (body, name: none) => {
  thm-counter.step()
  block(
    width: 100%,
    inset: 10pt,
    stroke: (left: 2pt + black),
    {
      context {
        let num = thm-counter.display()
        [*#kind #num*]
        if name != none [ _(#name)_]
        [*.* ]
      }
      if kind == "Theorem" or kind == "Lemma" { emph(body) } else { body }
    },
  )
}
#let theorem = make-env("Theorem")
#let lemma = make-env("Lemma")
#let definition = make-env("Definition")

#align(center)[
  #text(size: 1.5em, weight: "bold")[
    GraphRAG-Enhanced Architectural Compliance via Conflict-Aware Constraint Traversal
  ]
  #v(0.4em)
  #text(size: 0.9em, fill: black)[
    Ravicha Suksawasdi Na Ayuthaya (z5625225) \
    Supervisor: Jianwei Wang \
    Assessor: Zhengyi Yang \
    School of Computer Science and Engineering, UNSW \
    August 2026
  ]
]
#v(1em)

#align(left)[
  #text(size: 1.1em, weight: "bold")[Abstract]
  #v(0.3em)
]
Architectural Decision Records (ADRs) explain why software teams make certain structural choices, but because these documents recorded in natural languages, automated tools cannot check them. As systems grow and developers leave, the gap between the original plan and the actual code widens. Researchers call this "architectural drift." AI coding tools make this problem worse. They generate code faster, but the reasoning behind that code is often a guess rather than a deliberate choice.

This report presents a system that checks whether new code changes follow the rules written in plain-language ADRs. No single component is novel: Tree-sitter extracts syntax, LLMs extract constraints from prose, BFS computes reachability, and declarative conflict resolution orderings are well established. The contribution is the composition: an end-to-end pipeline that ingests ADRs and source code into an Architectural Decision Graph (ADG), scopes checks to a PR diff, traverses constraint edges to detect both direct and transitive violations, and resolves conflicts through a deterministic priority ordering (R1: supersession, R2: specificity, R3: recency, R4: human). Each violation report carries the full traversal path, the rule applied, and the rationale. No prior system combines diff-scoped graph traversal, declarative constraint triples with both positive and negative polarity, and deterministic conflict resolution over ADR-linked code.

The literature review looks at past work on ADRs, architectural drift, compliance tools, knowledge graphs, and conflicting rules. It finds a gap that no existing system fills: checking just the new code changes, searching the entire code graph, using rules that say what to do and what not to do, and settling rule conflicts in a fully predictable way. The report proposes a way to evaluate CPT by testing it against a standard AI model on real codebases that use ADRs, measuring how accurate it is, how many violations it catches, and what kinds of violations it finds.
#pagebreak()
#outline(title: "Contents", indent: auto)
#pagebreak()

// ============================================================
// 1. INTRODUCTION
// ============================================================
= Introduction

Software architecture is about both the structure of a system and the decisions behind it @tv09 @gmr15. When those decisions are documented at all, the documentation usually drifts away from what the code actually does, and the two are rarely brought back in line @tv09. This gap, called architectural drift or erosion, makes systems harder to maintain and evolve @gmr15 @tv09.

Architecture Decision Records (ADRs) are a lightweight fix: one short document per decision, kept alongside the code, so the rationale survives when developers leave. Their use on GitHub is growing year over year @buchgeher23. But ADRs are prose, invisible to automated checks, so the loop between what was decided and what was committed never closes on its own.

AI-assisted development makes this worse. Code generators and coding agents speed up the rate at which changes land, and the reasoning behind a change is increasingly a guess rather than a deliberate choice. Manual consistency checks that were already unsustainable for human-driven development @gmr15 become infeasible at the pace AI imposes. What was a slow drift becomes a fast one, and the "who decided this" trail that ADRs were meant to preserve is exactly the trail that AI-generated code does not produce.

This work closes that loop. It builds an Architectural Decision Graph (ADG) from source code and ADR documents, then uses Constraint Path Traversal (CPT) to detect violations of architectural constraints at PR review time. Conflicting constraints are resolved through a deterministic priority ordering that reduces false positives, and every violation report includes the full traversal path, the rule applied, and the rationale.

The original thesis topic framed this work as GraphRAG-Enhanced Memory Management for Intelligent Agents, with three subtasks: graph-based memory representation, relation-aware memory retrieval, and selective forgetting. Table @table-reframe shows how these subtasks map to this work's design.

#figure(
  table(
    columns: (1fr, 2fr),
    stroke: 0.5pt,
    inset: (x: 8pt, y: 5pt),
    table.hline(stroke: 1.5pt),
    table.header([*Original Subtask*], [*This Research Reframe*]),
    table.hline(stroke: 0.5pt),
    [Graph-Based Memory Representation],
    [ADG: Unified graph encoding syntactic structure + semantic constraints.],
    [Relation-Aware Memory Retrieval],
    [CPT traversal: walks from code diff, detecting vioaltion via constraint-edge traversal.],
    [Selective Forgetting and Memory Optimization],
    [R1-R4 conflict resolution as false-positive reduction. Incremental graph computation, MDS pruning, crystallization, and version-based pruning *are planned future literature review topics*, not yet specified.],
    table.hline(stroke: 1.5pt),
  ),
  caption: [Mapping from the original thesis subtasks to the design.],
) <table-reframe>

The research question is whether deterministic graph retrieval over ADRs can provide precise, recallable architectural compliance at PR review time, and what open problems remain for AI-assisted development. This report surveys the relevant literature (Section 2), presents the theoretical framework and algorithm design (Section 3), describes the implementation (Section 4), outlines the evaluation framework (Section 5), and details the plan for COMP9992 (Section 6).

// ============================================================
// 2. LITERATURE REVIEW
// ============================================================
= Literature Review

The literature relevant to this work spans five thematic areas: ADRs and architectural drift, static analysis and compliance tools, knowledge graphs and code retrieval, constraint conflict resolution, and transitive violation detection. Each area is surveyed below with emphasis on what prior work provides and where the gap lies.

== Architectural Decision Records and Drift

An ADR captures one architectural decision (context, decision, status, consequences) in a short document. Nygard's template dominates on GitHub; structured variants such as MADR add fields for options and trade-offs @buchgeher23. ADRs are lightweight and kept alongside code, but they remain prose: invisible to automated compliance checks.

Drift is the gradual divergence of implementation from documented architecture; erosion is the more severe case where undocumented changes degrade the architecture itself. Empirical studies link drift to delayed maintenance and knowledge loss @tv09 @gmr15. The recurring finding is that documentation and code evolve on separate timelines: decisions recorded late or never, rarely reconciled.

Three datasets underpin this work: Buchgeher et al. @buchgeher23 catalogue 6,362 ADRs across 921 repos; ADRMiner @adrminer adds text mining across 4,326 ADRs in 547 repos; Su et al. @su2026 provide 109 repos and 980 ADRs, pre-filtered for quality, representing the strongest work on LLM-based ADR violation detection (strong on explicit violations, weak on implicit ones).

== Static Analysis and Architectural Compliance

#figure(
  table(
    columns: (auto, 1fr, 1fr, 1fr),
    align: left,
    stroke: 0.5pt,
    inset: (x: 9pt, y: 4pt),
    table.hline(stroke: 1.5pt),
    table.header([*Tool*], [*What it detects*], [*Limitation*], [*What this work addresses*]),
    table.hline(stroke: 0.5pt),
    [SonarQube], [Code quality rules, code smells, security hotspots], [Symptom-level; not decision-aware; no ADR memory], [Decision-graph retrieval, not rule-pattern matching],
    [CodeRabbit], [Natural-language diff comments], [Probabilistic; no decision memory; high noise], [Persistent ADR memory; traversable decision path],
    [ArchLintor @archlintor2024], [Declarative forbidden/required rules with absence detection], [Whole-project static check; no diff scope; direct dependency check only], [Diff-scoped per-commit evaluation with reachability over the code graph],
    [ArdoCo @fuchss25], [LLM-recovered traceability links between arch docs and code FQNs], [Recovers links only; does not enforce ADR constraints at CI], [Borrows ArdoCo for seeding, then enforces ADR constraints at commit time],
    [SHACL/SPARQL @shacl], [Declarative constraints + graph reachability over RDF], [RDF triple store only; no code graph; no diff scope; no ADR semantics; no priority-ordered conflict resolution], [Same declarative + reachability primitive, applied to a code graph, diff-scoped, ADR-aware, with priority-ordered resolution],
    table.hline(stroke: 1.5pt),
  ),
  caption: [Comparison of static analysis and compliance tools.],
) <table-compliance>

Table @table-compliance compares five tools from three categories: industry linters, academic rule checkers, and systems that declare graph constraints. No previous system stores decisions as a searchable graph that is checked during CI with a full record of the path it took and the reasons why.

== Knowledge Graphs and Code Retrieval

=== Graph Structure

The convention that dominates both static-analysis and architecture-compliance literature is the fully qualified name (FQN): a dotted path from root package to module, class, function, or method.

Terra and Valente @tv09 define a dependency constraint language where every rule references its subjects and objects by qualified name: a typed relation between two FQN patterns with wildcards for hierarchical scope. this research adopts this shape: a `ConstraintEdge` carries a subject pattern, a predicate, and an object pattern, joined to code through FQN matching. Greifenberg, Mueller, and Rumpe @gmr15 extend the same primitive to plugin-based systems: DepCoL models plugins, packages, and classes as nodes identified by qualified names, with architectural restrictions as typed edges and a consistency checker that walks the graph. Together, @tv09 and @gmr15 establish the modelling choice this work builds on: _nodes keyed by FQN, code relationships as typed edges, architectural constraints as edges whose endpoints are FQN patterns over those nodes_.

The NL-to-structured-model translation that bridges prose ADRs to this graph rests on Keim et al. @keim2023, who extract typed model elements from natural-language architecture documentation with F1 0.81 on traceability link recovery and 0.93 accuracy on detecting absent model elements.

=== Bridging Natural-Language ADRs to the Code Graph

ADR constraint endpoints are prose, not FQN patterns. The ArdoCo line addresses this seam: TransArC @keim2024 inserts a component-based Software Architecture Model (SAM) between documentation and code, composing SAD-to-SAM and SAM-to-code trace recovery transitively into SAD-to-code links, reaching weighted-average F1 of 0.87. Fuchss et al. @fuchss25 remove the SAM requirement: an LLM extracts component names from the SAD and scores their resemblance to code FQNs through a composable tree of heuristics (name, package, path resemblance, subpackage filters, provided-interface correspondence), reaching F1 0.86 with GPT-4o.

This research suggests a direct change. The current `fqn_matches_pattern` binary match should be replaced by a scored heuristic tree, like the one ArdoCo uses. This tree would work in three parts:

- Standalone heuristics would return a confidence score for each pair of an ADR endpoint pattern and a code FQN.
- Dependent heuristics would filter results based on the graph structure.
- Aggregations would combine these scores.

=== Constraint Path Traversal and Graph Reachability

The current this research implementation computes reachability over the full code-graph adjacency for every commit: BFS from each subject FQN to determine whether a prohibited or required dependency path exists. This is correct but unoptimised. The literature on incremental and bounded graph computation, surveyed below, is a planned future review to determine whether the full-graph cost can be reduced without sacrificing precision.

Fan, Hu, and Tian @fan2022 establish the boundedness framework for incremental graph computation: when an incremental algorithm's cost is polynomial in the size of the change alone, the computation is _bounded_. Fan et al. @fan2011 give complexity results for graph simulation (optimal linear-time for unit updates), bounded simulation (unbounded in general), and subgraph isomorphism (intractable and unbounded). The 2-hop labelling approach on SCC-condensed DAGs reduces reachability queries to set intersection, providing a natural scalability path if BFS proves to be the bottleneck in practice.

Seedat et al. @seedat2024 propose explicit bounded k-hop horizons with per-hop decay for change impact analysis, the closest prior art to diff-scoped graph traversal. The gap is that Seedat propagates an impact set, not a downstream architectural rule check.

== AI-Assisted Development and Compliance

The Sentinel system @sentinel2025 is the closest operational comparison to this research: an autonomous agent that monitors ADR conformance at commit level, achieving 83% true-positive rate. However, Sentinel uses LLM agents for pattern detection without graph traversal, and does not provide deterministic traversal paths or conflict resolution.

The broader landscape includes CodeRabbit (probabilistic diff comments with no decision memory) and LLM-based code review tools that lack persistent ADR-aware memory. The common absence across all approaches is a traversable graph of decisions checked deterministically at CI time.

== Constraint Conflict Resolution

Constraint conflict resolution has mature formalisms in AI planning (constraining plans to remove harmful interactions @steelinsworth1992), constraint programming (nogood recording via "reasoning from last conflicts" @lecoutre2009), and causal discovery (ASP-based resolution of conflicting statistical constraints @hyttinen2014).

For this research, the specific form is: when multiple ADRs impose conflicting constraints on the same code region, which wins? The R1-R4 system (superseded status, specificity, recency, human decision) draws from the specificity ordering in dependency constraint languages @tv09 and the temporal ordering in ADR status conventions. Mohammadi et al. @mohammadi2025 provide the metric framework: precision, relative coverage, and violation-type breakdown map to the capability and reliability dimensions of their two-dimensional LLM agent evaluation taxonomy.

== Dependency Role Classification and Noise Suppression

Pure graph topology (CALLS, IMPORTS, CONTAINS, INHERITS edges) cannot distinguish `pytest` from `flask`. The literature converges on a two-layer approach: topological graph as a base, semantic role overlay to classify _why_ a dependency exists. For this research, `DependencyRole` classification (DEV_TOOL, INFRASTRUCTURE, APPLICATION, INTERNAL) at graph construction time, using package metadata, is a lookup problem rather than an inference problem. Filtering DEV_TOOL nodes from architectural violation checks directly suppresses the most common class of false positives.

// ============================================================
// 3. THEORETICAL FRAMEWORK AND ALGORITHM DESIGN
// ============================================================
= Theoretical Framework and Algorithm Design

This section presents the theoretical contributions: the Architectural Decision Graph model, the CPT algorithm, the R1-R4 conflict resolution framework, and the specificity scoring scheme. The prototype is implemented in Python 3.12 with Neo4j as the persistent graph store and Tree-sitter for syntactic parsing, containerised via Docker Compose for reproducibility.

== Code and ADR Extraction

The ADG is constructed through a dual-track ingestion pipeline. Track A extracts syntactic structure from source code; Track B extracts semantic constraints from ADR documents and grounds them to the code graph through substring matching.

#figure(
  cetz.canvas({
    import cetz.draw: *

    let a-fill = blue.lighten(92%)
    let a-stroke = blue.darken(25%) + 0.8pt
    let b-fill = orange.lighten(90%)
    let b-stroke = orange.darken(25%) + 0.8pt
    let m-fill = green.lighten(82%)
    let m-stroke = green.darken(25%) + 0.8pt
    let sub = (size: 0.68em, fill: luma(90))

    // Track A: Syntactic
    rect((0, 3.2), (2.6, 4.2), name: "src", fill: a-fill, stroke: a-stroke, radius: 0.15)
    content("src", text(size: 0.85em)[*Source Code*])

    rect((5, 2.6), (9, 4.8), name: "fqn", fill: a-fill, stroke: a-stroke, radius: 0.15)
    content((7, 4.3), text(size: 0.85em)[*FQN Nodes*])
    content((7, 3.7), text(..sub)[modules, classes, functions,])
    content((7, 3.1), text(..sub)[methods, external packages])

    line("src.east", "fqn.west", mark: (end: ">"), stroke: a-stroke)
    content((3.7, 4), anchor: "south", text(size: 0.7em, weight: "bold")[Tree-sitter])

    // Track B: Semantic
    rect((-1, 0.2), (2, 1.2), name: "adr", fill: b-fill, stroke: b-stroke, radius: 0.15)
    content("adr", text(size: 0.85em)[*ADR Documents*])

    rect((4, -0.2), (7.8, 1.8), name: "sym", fill: b-fill, stroke: b-stroke, radius: 0.15)
    content((5.9, 1.3), text(size: 0.85em)[*SymbolicConstraint*])
    content((5.9, 0.5), text(..sub)[general\_name, specific\_name])

    line("adr.east", "sym.west", mark: (end: ">"), stroke: b-stroke)
    content((3, 1), anchor: "south", text(size: 0.7em, weight: "bold")[LLM])

    rect((9.2, 0), (12.4, 1.6), name: "res", fill: b-fill, stroke: b-stroke, radius: 0.15)
    content((10.8, 1.1), text(size: 0.85em)[*Symbolic Resolver*])
    content((10.8, 0.3), text(..sub)[substring matching])

    line("sym.east", "res.west", mark: (end: ">"), stroke: b-stroke)

    // ADG merge box
    rect((13.8, 1.6), (16.2, 3.4), name: "adg", fill: m-fill, stroke: m-stroke, radius: 0.15)
    content((15, 2.8), text(size: 0.95em)[*ADG*])
    content((15, 2.1), text(size: 0.75em)[$(V, E, C)$])

    line((9, 3.7), (13.8, 3), mark: (end: ">"), stroke: a-stroke)
    content((10.8, 3.8), anchor: "south", text(size: 0.65em, fill: blue.darken(25%))[$V, E$])

    line("res.east", (13.8, 2.1), mark: (end: ">"), stroke: b-stroke)
    content((13, 1.2), anchor: "north", text(size: 0.65em, fill: orange.darken(25%))[$C$])

    // Track labels
    content((-0.3, 3.7), anchor: "east", text(size: 0.75em, weight: "bold", fill: blue.darken(25%))[Track A:])
    content((-0.3, 3.3), anchor: "east", text(size: 0.65em, fill: blue.darken(25%))[Syntactic])
    content((-1.3, 0.7), anchor: "east", text(size: 0.75em, weight: "bold", fill: orange.darken(25%))[Track B:])
    content((-1.3, 0.3), anchor: "east", text(size: 0.65em, fill: orange.darken(25%))[Semantic])
  }),
  caption: [Dual-track ingestion pipeline: Track A builds the code graph from source; Track B extracts constraints from ADRs and grounds them to the code graph via substring matching.],
) <fig-pipeline>

*Track A* uses Tree-sitter to parse source code into a graph of fully qualified name (FQN) nodes. These nodes connect using structural edges like CALLS, IMPORTS, CONTAINS, and INHERITS. Some imports come from outside the repository and cannot be resolved internally. These external packages are labeled with a `DependencyRole`, such as DEV_TOOL, INFRASTRUCTURE, APPLICATION, or INTERNAL based on their package metadata, and are added to the graph as EXTERNAL nodes.

*Track B* uses an LLM to pull `SymbolicConstraint` triples from Architecture Decision Records (ADRs). Each constraint has a subject, a predicate, and an object. The predicate states a rule: PROHIBITS_DEPENDENCY, REQUIRES_DEPENDENCY, PROHIBITS_IMPLEMENTATION, or REQUIRES_IMPLEMENTATION. The subject and object each carry a general role and a specific role. A symbolic resolver then links these text descriptions to actual code graph FQN nodes in three stages.
1. *A general match*: it matches the general role exactly or with wildcards against module FQNs.
2. *A specific narrow*: it matches the specific role against the descendants of those general matches using substrings. It prioritizes exact matches, then prefix overlaps, and finally substring containments.
3. *A fallback*: if the general match fails, it matches the specific role against all nodes in the code graph using substrings. The final `ConstraintEdge` triples record the subject FQN pattern, the object FQN pattern, the predicate, and the source ADR.

== Constraint Path Traversal (CPT)

CPT is the detection engine that checks whether the code graph violates the constraints extracted from ADRs. Given an ADG $= (V, E, C)$ (nodes, edges, constraint edges) and a diff listing changed FQNs, CPT produces a set of violations.

#definition(name: "Constraint Path Traversal")[
  Given an ADG $(V, E, C)$ and a diff $Delta$, CPT returns a set of violations:
  $
    "CPT"(V, E, C, Delta) = "resolve"(S(V, E, C) union T(V, E, C, Delta))
  $
  where $S$ checks structural (PROHIBITS) predicates against the full graph, $T$ checks change-triggered (REQUIRES) predicates against changed FQNs, and $"resolve"$ deduplicates and suppresses lower-specificity conflicts.
]

The algorithm operates in three phases.

*Phase 1: Constraint matching.* Each `ConstraintEdge` carries a subject pattern and an object pattern (e.g., `app.service.*` and `app.repo.*`). CPT matches these patterns against all FQN nodes in the ADG. A constraint is *active* only if both its subject and object patterns match at least one node; constraints where either side matches nothing are *orphans*, reported separately as potential configuration errors.

*Phase 2: Reachability checks.* All traversal uses the same two edge-kind sets, chosen by predicate flavour:
$ K_"dep" = \{"CONTAINS", "IMPORTS", "CALLS", "INHERITS"\}, quad K_"impl" = \{"CONTAINS", "CALLS"\} $
Dependency predicates (`_DEPENDENCY`) traverse $K_"dep"$; implementation predicates (`_IMPLEMENTATION`) traverse $K_"impl" subset.eq K_"dep"$, which excludes `IMPORTS` and `INHERITS` because implementing a module does not follow import chains.

+ *Phase 2.1: Structural check (PROHIBITS).* For every matched subject-object pair of a `PROHIBITS_*` constraint, CPT runs a breadth-first search from the subject FQN over the relevant $K$ set. If the object FQN (or a descendant) is reachable, a structural violation is emitted. No diff is needed: the violation exists regardless of what changed.

+ *Phase 2.2: Change-triggered check (REQUIRES).* For each changed FQN $Delta_i$, CPT identifies the relevant subject matches of each `REQUIRES_*` constraint, then BFS from $Delta_i$ over the relevant $K$ set. If none of the object pattern's matches are reachable, a violation is emitted: the changed code must depend on (or implement) something matching the object pattern but does not

*Phase 3: Resolution.* The raw violation set is deduplicated, collapsed (module-level violations subsume their children for the same constraint), and then resolved via the R1-R4 conflict rules described below.

== Conflict Resolution: R1-R4

When multiple ADRs impose conflicting constraints on the same code region, this research resolves them through a priority-ordered system:

#figure(
  cetz.canvas({
    import cetz.draw: *

    let blue-fill = blue.lighten(92%)
    let blue-stroke = blue.darken(25%) + 0.8pt
    let orange-fill = orange.lighten(90%)
    let orange-stroke = orange.darken(25%) + 0.8pt
    let green-fill = green.lighten(82%)
    let green-stroke = green.darken(25%) + 0.8pt
    let sub = (size: 0.68em, fill: luma(90))
    let arr = (end: ">")
    let bw = 5.8  // box width
    let bh = 0.75 // box height
    let gap = 0.55 // vertical gap
    let y = 0 // running y, top-down

    // Raw violations
    rect((0, y), (bw, y - bh), name: "raw", fill: luma(95%), stroke: luma(60%) + 0.8pt, radius: 0.15)
    content("raw", text(size: 0.85em)[*Raw Violations*])
    y -= bh + gap

    // Pre-resolution: Dedup (blue)
    rect((0, y), (bw, y - bh), name: "dedup", fill: blue-fill, stroke: blue-stroke, radius: 0.15)
    content((bw / 2, y - 0.2), text(size: 0.77em)[*Exact Deduplication*])
    content((bw / 2, y - bh + 0.2), text(..sub)[same (subject, predicate, object, matched FQN)])
    line("raw.south", "dedup.north", mark: arr)
    y -= bh + gap

    // Pre-resolution: Collapse (blue)
    rect((0, y), (bw, y - bh), name: "collapse", fill: blue-fill, stroke: blue-stroke, radius: 0.15)
    content((bw / 2, y - 0.2), text(size: 0.77em)[*Module-Level Collapse*])
    content((bw / 2, y - bh + 0.2), text(..sub)[parent FQN absorbs children])
    line("dedup.south", "collapse.north", mark: arr)
    y -= bh + gap

    // R1 (orange)
    rect((0, y), (bw, y - bh), name: "r1", fill: orange-fill, stroke: orange-stroke, radius: 0.15)
    content((bw / 2, y - 0.2), text(size: 0.77em)[*R1: Explicit Supersession*])
    content((bw / 2, y - bh + 0.2), text(..sub)[ADR declares override])
    line("collapse.south", "r1.north", mark: arr)
    y -= bh + gap

    // R2 (orange)
    rect((0, y), (bw, y - bh), name: "r2", fill: orange-fill, stroke: orange-stroke, radius: 0.15)
    content((bw / 2, y - 0.2), text(size: 0.77em)[*R2: Specificity Wins*])
    content((bw / 2, y - bh + 0.2), text(..sub)[higher specificity $arrow.r$ higher priority])
    line("r1.south", "r2.north", mark: arr)
    y -= bh + gap

    // R3 (orange)
    rect((0, y), (bw, y - bh), name: "r3", fill: orange-fill, stroke: orange-stroke, radius: 0.15)
    content((bw / 2, y - 0.2), text(size: 0.77em)[*R3: Recency Wins*])
    content((bw / 2, y - bh + 0.2), text(..sub)[higher adr\_id $arrow.r$ higher priority])
    line("r2.south", "r3.north", mark: arr)
    y -= bh + gap

    // R4 (orange)
    rect((0, y), (bw, y - bh), name: "r4", fill: orange-fill, stroke: orange-stroke, radius: 0.15)
    content((bw / 2, y - 0.2), text(size: 0.77em)[*R4: Human Review*])
    content((bw / 2, y - bh + 0.2), text(..sub)[flag unresolved])
    line("r3.south", "r4.north", mark: arr)
    y -= bh + gap

    // Final violations
    rect((0, y), (bw, y - bh), name: "final", fill: green-fill, stroke: green-stroke, radius: 0.15)
    content("final", text(size: 0.85em)[*Final Violations*])
    line("r4.south", "final.north", mark: arr)

    // Side labels
    content((bw + 0.3, -0.375), anchor: "west", text(size: 0.7em, fill: blue.darken(30%), weight: "bold")[Pre-resolution])
    line((bw + 0.2, -bh), (bw + 0.2, -2 * bh - gap + bh), stroke: blue.darken(25%) + 0.6pt)

    content((bw + 0.3, -0.375 - 3 * (bh + gap)), anchor: "west", text(size: 0.7em, fill: orange.darken(30%), weight: "bold")[R1-R4])
    line((bw + 0.2, -3 * (bh + gap) - bh), (bw + 0.2, -7 * (bh + gap)), stroke: orange.darken(25%) + 0.6pt)
  }),
  caption: [Resolution pipeline: pre-resolution steps (blue) clean the raw violation set; R1-R4 rules (orange) resolve remaining conflicts by priority.],
) <fig-resolution>

#definition(name: "Specificity score")[
  The specificity of an FQN pattern is:
  $ "specificity"(p) = cases(
    d(p) + 1 & "if" p "is exact (no wildcard)",
    d(p) & "if" p "ends with .*",
  ) $
  where $d(p)$ is the dot-depth of the pattern after stripping the `.*` suffix. Examples: `app.db.query` yields 3.0 (exact), `app.services.*` yields 1.5 (one wildcard), `app.*` yields 0.5 (broad wildcard).
]

The resolution pipeline uses two pieces of ADR metadata: the numeric `adr_id` (which encodes recency and supports R3) and the `specificity` score (which supports R2). ADRs marked `SUPERSEDED` or `REJECTED` are excluded from constraint extraction, so stale ADRs never enter the pipeline. Every surviving violation carries the full 5-tuple `(subject, predicate, object, matched_fqn, adr_id)`, which serves as a stable identity key for dismissal: once a developer dismisses a violation, it stays dismissed across re-runs even as the ADG evolves.

== The Novelty Claim

No prior system combines all four of this research's pillars:
// TODO: add more later
#figure(
  table(
    columns: (auto, auto, auto, auto, auto, auto),
    stroke: 0.5pt,
    inset: (x: 4pt, y: 3pt),
    table.hline(stroke: 1.5pt),
    table.header([*System*], [*Diff-driven*], [*Graph traversal*], [*Declarative triples*], [*Both polarities*], [*Per-commit*]),
    table.hline(stroke: 0.5pt),
    [*This research*], [yes], [yes], [yes], [yes], [yes],
    [Seedat et al. @seedat2024], [yes], [yes], [no], [no], [n/a],
    [Dart Sentinel @sentinel2025], [yes], [no], [partial], [no], [yes],
    table.hline(stroke: 1.5pt),
  ),
  caption: [Novelty comparison: no prior system combines all four pillars.],
) <table-novelty>

Each component has prior art; the combination does not.

// ============================================================
// 5. EVALUATION FRAMEWORK
// ============================================================
= Evaluation Framework

// == Research Questions

// The evaluation addresses three research questions:

// + _RQ1 (Effectiveness)_: Does CPT detect architectural violations that an LLM baseline misses, particularly transitive violations?
// + _RQ2 (Precision)_: What is the precision of CPT-detected violations, measured through human review?
// + _RQ3 (Optimization trade-offs)_: Do optimisations (MDS pruning, crystallization, version-based pruning) trade precision for speed/token savings, and by how much?

== Evaluation Design

=== CPT Detection vs Pi+LLM Baseline

The baseline is a Pi agent harness with state-of-the-art LLMs (2-3 models: one frontier, two open/affordable). Pi provides tool access (grep, file reading) with a 20 tool-call cap. Both CPT and Pi receive the same ADR text and repo file tree. The prompt gives no hints about graph traversal or CPT.

Metrics:

#figure(
  table(
    columns: (auto, 1fr, 1fr),
    stroke: 0.5pt,
    inset: (x: 6pt, y: 4pt),
    table.hline(stroke: 1.5pt),
    table.header([*Metric*], [*Definition*], [*Notes*]),
    table.hline(stroke: 0.5pt),
    [Precision], [confirmed / total reported], [From human review],
    [Relative coverage], [violations found by CPT but not LLM, and vice versa], [No absolute recall (no oracle). Avoids the oracle problem @mohammadi2025],
    [Violation type breakdown], [direct vs transitive per method], [Headline result: CPT should dominate on transitive violations],
    table.hline(stroke: 1.5pt),
  ),
  caption: [Evaluation metrics for Subtask 2.],
) <table-metrics>

Ground truth is established via human review: confirmed violations are true positives, dismissed violations are false positives. This follows the single-annotator pattern common in SE benchmarks (cf. SWE-bench's gold patch validation) and avoids the annotation burden identified by de Silva and Balasubramaniam @desilva2018 as a barrier to architecture conformance checking adoption.

=== Subtask 3: Ablation of Optimisations

The baseline is the full pipeline with R1-R4 resolution. Ablation tests whether the system works correctly without these optimization. Future optimisations (MDS pruning, crystallization, version-based pruning) are planned literature review topics that will be added as ablation rows once specified:

#figure(
  table(
    columns: (auto, 1fr, 1fr, 1fr),
    stroke: 0.5pt,
    inset: (x: 6pt, y: 4pt),
    table.hline(stroke: 1.5pt),
    table.header([*Arm*], [*Input*], [*Output*], [*Metric*]),
    table.hline(stroke: 0.5pt),
    [Baseline], [Commit diff + repo + ADRs], [Code-review agent (Pi) report], [Precision, recall, token usage, time taken],
    [CPT, no optimization], [diff + repo + ADRs + violation findings], [Code-review agent (Pi) report], [Precision, recall, token usage, time taken],
    [CPT, with optimization], [diff + repo + ADRs + violation findings], [Code-review agent (Pi) report], [Precision, recall, token usage, time taken],
    table.hline(stroke: 1.5pt),
  ),
  caption: [Evaluation arms for Subtask 3.],
) <table-ablation>

=== Dataset

A repository qualifies if it has 3+ ADRs with identifiable PROHIBITS/REQUIRES constraints, is a Python codebase, has code-inferable constraints, contains at least one violated ADR, and is publicly available. The target is 5 repositories with 25-50 violation instances.

The primary source is the ADR-Study-Dataset @buchgeher23 (921 repos, 6,362 ADRs), supplemented by Su et al. @su2026 (109 repos, 980 ADRs). `python-tuf` (10 ADRs, Nygard format, checkable constraints, 1,712 GitHub stars) is confirmed as the first repository; additional repositories will be selected from the ADR-Study-Dataset filtered for Python and 3+ code-inferable ADRs.

For R1-R4 validation, the strategy is to first curate naturally occurring conflicts from real repos, then inject synthetic conflict ADRs if fewer than approximately 10 natural conflicts are found across all repos. Only the conflicting ADR text is synthetic; the code and structural context remain real.

// ============================================================
// 6. PLANNED FURTHER WORK
// ============================================================
= Planned Further Work

// ============================================================
// 7. CONCLUSION
// ============================================================
= Conclusion

This report has presented this research, a system that closes the loop between architectural decisions recorded as ADRs and the code that implements them. The literature review identified a gap that no prior system fills: the combination of per-commit diff-driven scoping, full-graph traversal with multi-source BFS, declarative constraint triples with both positive and negative polarity, and deterministic conflict resolution. The theoretical framework formalises this gap as the ADG model and the CPT algorithm, with R1-R4 resolution providing false-positive reduction and specificity scoring providing a principled ordering for ambiguous constraints.

The implementation demonstrates that the approach is feasible: the dual-track pipeline (Tree-sitter for syntax, LLM for semantics) constructs the ADG; the symbolic resolver bridges natural-language ADR text to FQN patterns; the CPT engine detects both structural and change-triggered violations; and the resolution pipeline applies R1-R4 with dismissal for human oversight.

The evaluation framework, designed but not yet executed, proposes a direct comparison against an LLM baseline (Pi+LLM) on real-world repositories with ADRs, measuring precision, relative coverage, and violation-type breakdown. The ablation study will first test R1-R4 correctness, then evaluate potential optimisations (MDS pruning, crystallization, version-based pruning) once specified through further literature review.

The remaining 10 weeks of work are clearly defined: benchmark execution, optimisation literature review and ablation, and the heuristic resolution upgrade that replaces binary pattern matching with the scored ArdoCo-style tree.

// ============================================================
// REFERENCES
// ============================================================
#bibliography("refs.yml", title: "References", style: "ieee")