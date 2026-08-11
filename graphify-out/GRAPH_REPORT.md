# Graph Report - securiace-whmcs-pdf-invoice-template-complex  (2026-08-11)

## Corpus Check
- 33 files · ~27,137 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 178 nodes · 153 edges · 32 communities (30 shown, 2 thin omitted)
- Extraction: 98% EXTRACTED · 2% INFERRED · 0% AMBIGUOUS · INFERRED: 3 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `36c269f1`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- [[_COMMUNITY_Community 0|Community 0]]
- [[_COMMUNITY_Community 1|Community 1]]
- [[_COMMUNITY_Community 2|Community 2]]
- [[_COMMUNITY_Community 3|Community 3]]
- [[_COMMUNITY_Community 4|Community 4]]
- [[_COMMUNITY_Community 5|Community 5]]
- [[_COMMUNITY_Community 6|Community 6]]
- [[_COMMUNITY_Community 7|Community 7]]
- [[_COMMUNITY_Community 8|Community 8]]
- [[_COMMUNITY_Community 9|Community 9]]
- [[_COMMUNITY_Community 11|Community 11]]
- [[_COMMUNITY_Community 12|Community 12]]
- [[_COMMUNITY_Community 13|Community 13]]
- [[_COMMUNITY_Community 14|Community 14]]
- [[_COMMUNITY_Community 30|Community 30]]

## God Nodes (most connected - your core abstractions)
1. `SecuriacePdfProfileSnapshotService` - 16 edges
2. `Living handoff` - 14 edges
3. `Securiace WHMCS PDF Document Templates` - 13 edges
4. `Dynamic WHMCS PDF suite modernization` - 10 edges
5. `Invoice UI/UX and Runtime Audit` - 9 edges
6. `Invoice naming and numbering decision` - 7 edges
7. `WHMCS PDF Suite Compatibility and Deployment Record` - 7 edges
8. `Upgrade-safe PDF theme operations` - 7 edges
9. `Work packages` - 6 edges
10. `main()` - 4 edges

## Surprising Connections (you probably didn't know these)
- `securiace_pdf_profile_activate()` --calls--> `SecuriacePdfProfileSnapshotService`  [INFERRED]
  modules/addons/securiace_pdf_profile/securiace_pdf_profile.php → modules/addons/securiace_pdf_profile/lib/SnapshotService.php
- `securiace_pdf_profile_output()` --calls--> `SecuriacePdfProfileSnapshotService`  [INFERRED]
  modules/addons/securiace_pdf_profile/securiace_pdf_profile.php → modules/addons/securiace_pdf_profile/lib/SnapshotService.php
- `securiace_pdf_profile_upgrade()` --calls--> `SecuriacePdfProfileSnapshotService`  [INFERRED]
  modules/addons/securiace_pdf_profile/securiace_pdf_profile.php → modules/addons/securiace_pdf_profile/lib/SnapshotService.php

## Import Cycles
- None detected.

## Communities (32 total, 2 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.10
Nodes (5): DateTimeImmutable, SecuriacePdfProfileSnapshotService, securiace_pdf_profile_activate(), securiace_pdf_profile_output(), securiace_pdf_profile_upgrade()

### Community 1 - "Community 1"
Cohesion: 0.12
Nodes (15): 1. Shared resolver, 2. Invoice integration, 3. Quote and batch profiles, 4. Lifecycle and numbering, 5. Snapshots and diagnostics, Architectural decision, Document lifecycle, Dynamic WHMCS PDF suite modernization (+7 more)

### Community 2 - "Community 2"
Cohesion: 0.14
Nodes (6): TCPDF, FixtureInvoiceModel, FixtureThrowingBarcodePdf, prepareInvoiceRuntimeFixture(), renderBatchFixtures(), renderFixture()

### Community 3 - "Community 3"
Cohesion: 0.13
Nodes (14): Contract markers, Current environment handoff, Deployment handoff, Future GST transition, Invoice download incident contract, Living handoff, Next-maintainer start, Pull-request maintenance (+6 more)

### Community 4 - "Community 4"
Cohesion: 0.14
Nodes (13): Browser preview, Compatibility, Install the modern invoice template, Install the modern quote template, Legacy runtime repair, License, Modern invoice behavior, Modern quote behavior (+5 more)

### Community 5 - "Community 5"
Cohesion: 0.17
Nodes (11): Acceptance matrix for the WHMCS phase, Design contract for the preview, Implementation and renderer findings, Information and interaction rules, Invoice UI/UX and Runtime Audit, Outcome, Production acceptance boundary, Runtime and data integrity (+3 more)

### Community 6 - "Community 6"
Cohesion: 0.20
Nodes (9): Controlled PDF surface, Invoice, Quote, Release-branch policy, Rendering and compatibility decisions, Source-contract findings, Standard production deployment, Verification matrix (+1 more)

### Community 7 - "Community 7"
Cohesion: 0.25
Nodes (7): Approved WHMCS settings, Decision, GST number rule and format capacity, GST-registration transition gate, Invoice naming and numbering decision, Primary sources, Why the references differ

### Community 8 - "Community 8"
Cohesion: 0.25
Nodes (6): creditRows, outstandingOnly, paidOnly, stateButtons, states, taxRows

### Community 9 - "Community 9"
Cohesion: 0.33
Nodes (5): Deployment and rollback, Living handoff, Verification, What, Why

### Community 11 - "Community 11"
Cohesion: 0.40
Nodes (4): Data boundary, Immutable issuer snapshots, Installation, Recovery

### Community 12 - "Community 12"
Cohesion: 0.70
Nodes (4): assertWhmcsInvoiceTemplateRepaired(), backupWhmcsInvoiceTemplate(), main(), repairWhmcsInvoiceTemplate()

### Community 30 - "Community 30"
Cohesion: 0.25
Nodes (7): Package contract, Purpose, Required acceptance matrix, Rollback, Staging installation, Upgrade-safe PDF theme operations, WHMCS upgrade gate

## Knowledge Gaps
- **84 isolated node(s):** `DateTimeImmutable`, `states`, `stateButtons`, `paidOnly`, `outstandingOnly` (+79 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **2 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Are the 3 inferred relationships involving `SecuriacePdfProfileSnapshotService` (e.g. with `securiace_pdf_profile_activate()` and `securiace_pdf_profile_output()`) actually correct?**
  _`SecuriacePdfProfileSnapshotService` has 3 INFERRED edges - model-reasoned connections that need verification._
- **What connects `DateTimeImmutable`, `states`, `stateButtons` to the rest of the system?**
  _84 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.10476190476190476 - nodes in this community are weakly interconnected._
- **Should `Community 1` be split into smaller, more focused modules?**
  _Cohesion score 0.125 - nodes in this community are weakly interconnected._
- **Should `Community 2` be split into smaller, more focused modules?**
  _Cohesion score 0.14166666666666666 - nodes in this community are weakly interconnected._
- **Should `Community 3` be split into smaller, more focused modules?**
  _Cohesion score 0.13333333333333333 - nodes in this community are weakly interconnected._
- **Should `Community 4` be split into smaller, more focused modules?**
  _Cohesion score 0.14285714285714285 - nodes in this community are weakly interconnected._