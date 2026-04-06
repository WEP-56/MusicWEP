# Engineering Principles

## Delivery order

1. Windows desktop first
2. Android second
3. Shared domain and service layers before platform-specific UI glue

## File size limits

- Dart source files should stay under 300 lines when practical.
- When a file approaches the limit, split by responsibility instead of adding regions or placeholder comments.
- Generated code is the only exception.

## Architecture rules

- `core/`: platform, runtime, filesystem, and shared infrastructure
- `features/`: product capabilities with `domain`, `application`, `infrastructure`, and `presentation`
- Platform details must not leak into feature presentation code
- Runtime compatibility code must be isolated behind adapters

## Product rules

- No placeholder implementations
- No silent fallback behavior for failed plugin installation or execution
- Persist only data that is required for update, diagnostics, or user state recovery
- Every externally visible workflow must have a corresponding automated test when practical

## Platform strategy

- Windows is the primary validation target
- Android support must reuse the same domain and application services
- Platform-specific path, package info, and lifecycle behavior must come from dedicated abstractions
