# Changelog

All notable changes to Jev are documented here.

## [0.3.1] - 2026-10-03

### Added

- `Select-Jev` to keep original pipeline inputs that reach a yes/no probability threshold.
- `Add-JevAnnotation` to enrich pipeline inputs with named answers using `Invoke-Jev`.
- `Examples/Pipelines` with a reply-triage example that selects messages before annotating them.
- GitHub Actions workflow to validate the module manifest and run Pester tests on pushes, pull requests, and manual runs.

### Fixed

- `Test-Jev` binds the first positional argument to `Question` and the second to `Threshold`, leaving `State` for pipeline input or `-State`.

## [0.3.0] - 2026-10-02

### Added

- `Test-Jev` for pipeline-friendly yes/no checks that return a Boolean at a caller-selected probability threshold.
- Teaching-focused PowerShell demos ported from ThinkThen, with sample inputs and a categorized demos index.

### Documentation

- Documented `Test-Jev` behavior, thresholds, and per-input live requests.

## [0.2.0] - 2026-09-24

### Added

- `Invoke-Jev -AsJson` to return the merged result as JSON text; combine with `-Raw` to serialize the raw Jev response.
- `New-JevYesNoQuestion` as a friendly way to create a Noul question with explicit true and false criteria.
- `.Jev()` on arrays to evaluate each record against a plain-language condition.
- A two-incident README demo that displays `page` or `do not page`, plus a fuller paging example with an uncertainty review outcome.
- Examples for deal decisions, Excel queues, notes, release notes, standups, and PowerShell command discovery.

### Documentation

- Clarified that Noul returns a probability and that the paging cutoff is an example policy.

## [0.1.0] - 2026-09-22

First preview release of the Jev PowerShell module.

### Added

- `Invoke-Jev` for sending structured questions and input to the Jev decision model.
- `New-JevQuestion` with Noul, Choice, and Score question types.
- Question parameters aligned with the Jev payload keys: `Name`, `Type`, `Instructions`, and `Criteria`.
- Retry, timeout, and mock support for the API client and its tests.
- QuickStart, refund triage, security incident, and semantic log triage examples.
- Pester tests, an MIT license, and helper scripts for local installation and Gallery publication.

### Changed

- `Invoke-Jev` documents `-State` as the input parameter, matching Jev's request payload. `-InputObject` remains available as a compatibility alias.
- `Invoke-Jev` now enriches pipeline output with the original state and Jev response details by default. Use `-Raw` for the unmodified Jev response.
- Named Jev answers are promoted to top-level properties in the merged output while the full `answers` object remains available.
