# API Reference

The reference below documents the latest published version. Generate the API
for the current checkout with `dart doc --output build/api`.

| Library | Purpose | Runnable example |
| --- | --- | --- |
| [Surface API](https://pub.dev/documentation/alien_signals/latest/alien_signals/) | Ready-to-use signals, computed values, effects, scopes, batching, and manual notification. | [Basic usage](../example/main.dart) |
| [Preset API](https://pub.dev/documentation/alien_signals/latest/preset/) | Concrete node types, dependency tracking, scheduling, and cleanup helpers for custom surface APIs. | [Custom value accessors](../example/preset_playground.dart) |
| [System API](https://pub.dev/documentation/alien_signals/latest/system/) | Dependency graph types and propagation operations for custom primitives. | [Manual graph](../example/system.dart) |

The API comments include snippets from those executable examples. See the
[guide](guide.md) for choosing a layer and understanding value and lifecycle
semantics, or the [recipes](recipes.md) for specific usage patterns.
