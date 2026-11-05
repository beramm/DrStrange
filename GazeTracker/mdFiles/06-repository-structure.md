# Repository Structure

Status: Phase 2 module structure established
Last updated: 2026-11-03

## Current structure

```text
DrStrange/
├── README.md
├── GazeTracker/
│   ├── Package.swift
│   ├── README.md
│   ├── Sources/DrStrangeGazeTracker/
│   ├── Tests/DrStrangeGazeTrackerTests/
│   ├── DemoApp/
│   ├── Phase1Probe/
│   └── mdFiles/
└── Slicing/
```

Phase 2 established a local Swift Package product named `DrStrangeGazeTracker`, focused contract tests, and a minimal gaze-owned iPad demo host. The disposable `Phase1Probe/` remains separate evidence and is not a dependency of the production module. `Slicing/` remains outside gaze-team scope.

## Ownership

| Area | Owner | Notes |
| --- | --- | --- |
| `GazeTracker/` | Gaze-tracking team | Tracker source, calibration, tests, diagnostics, and documentation |
| `Slicing/` | UI/game team | Gaze-tracker work must not create or modify content here |
| Root project files | Shared/application lead | Integration configuration and repository-wide documentation |

## Selected direction: native Swift/iPadOS

The runtime decision is complete. No source layout was created during Phase 0; the exact package/framework/app-local form belongs to Phase 2 after the target-device capability spike.

Prefer a tracker module with framework-neutral public models, a physical-device demo host, and unit/integration tests. ARKit types should remain internal to the tracker boundary.

```text
GazeTracker/
├── mdFiles/
├── Sources/
├── Tests/
└── DemoApp/
```

The selected Phase 2 form is a Swift Package library with a framework-neutral `DrStrangeGazeTracker` contract target and a `DrStrangeGazeTrackerPlatform` adapter target containing the internal ARKit runtime. `DemoApp/` is a separate Xcode host that consumes the local package. Public contract tests build on macOS; the ARKit adapter and host build against the iOS device SDK.

## Repository hygiene observations

- `.DS_Store` is currently untracked at the repository root and should not become part of the application structure.
- Empty directories such as `Slicing/` are not preserved by Git unless they later contain a tracked placeholder or project content.
- Package and demo build outputs should remain outside the repository or ignored; the Phase 2 verification commands use temporary derived-data/scratch paths.
