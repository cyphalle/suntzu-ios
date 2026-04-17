# Sun Tzu iOS

Native iOS implementation of *Sun Tzu* (Alan M. Newman / Asmodee–Nexus, 2008).
Personal, non-commercial project.

## Status

Scaffold milestone **M0** complete. Following the plan in `SPEC.md` §12.

## Stack

- Swift 6, iOS 17+
- Core engine: pure Swift Package (`SunTzuCore`), zero external deps, XCTest only
- UI (from M13): SwiftUI + SpriteKit
- Deterministic: xorshift64 seeded RNG, immutable value types

## Layout

```
Sources/SunTzuCore/{Domain,Rules,Setup,Util}/   # pure game engine
Tests/SunTzuCoreTests/                          # XCTest
SPEC.md                                         # full implementation spec
```

## Build & test

```sh
swift build
swift test
```
