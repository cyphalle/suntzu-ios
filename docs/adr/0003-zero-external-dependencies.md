# ADR-0003 — Zero external dependencies in the core

- **Status**: accepted
- **Date**: M0
- **Related SPEC**: §2 Tech stack, §0 consignes (point 4)

## Context

Swift / SPM makes adding dependencies cheap. The temptation list: a JSON
serializer shim, a property-based testing library, a collections extension
package, a logging façade, a random-number library. Each one is a small win
today and a supply-chain commitment forever.

## Decision

**`SunTzuCore` has zero third-party dependencies.** Only Apple's standard
library and `Foundation` (for `UUID`, `tanh`). Tests use `XCTest` only.

- RNG → hand-rolled `SeededRNG` (xorshift64) in `Util/SeededRNG.swift`.
- JSON serialization → `Codable` synthesis only.
- Property-style testing → loop + `XCTAssert*` inside `InvariantTests`.

## Consequences

**Positive**

- `swift build` runs in seconds with no package fetch.
- No risk of a transitive dependency pulling in a different `Sendable`
  policy or breaking Swift 6 strict concurrency.
- The whole core is self-contained enough to vendor elsewhere (e.g. into a
  server-side eval job) without orchestrating package resolution.

**Negative**

- No off-the-shelf property-based testing → our `InvariantTests` manually
  loops 100 seeds. A library (`SwiftCheck`) would give better shrinking.
  Accepted because the manual loop already catches regressions in practice.
- We re-implement common algorithms (uniform-int RNG via modulo, shuffle
  via `Array.shuffled(using:)`). None are performance-critical.

## Scope

This ADR applies to `SunTzuCore`. The iOS app target (M13+) will import
SwiftUI / SpriteKit from Apple's SDK, which are allowed but still not
third-party packages.
