# RediM8 Architecture

## Layering

RediM8 follows a strict dependency direction:

```text
Views
  -> ViewModels
  -> AppState
  -> Systems
  -> Services
  -> Persistence / hardware / OS frameworks
```

The most important rule is that dependency flow only moves downward.

## Runtime Systems

`AppState` is the runtime coordinator. It owns the active app systems and wires shared events between them:

- `PreparednessSystem`
- `SignalSystem`
- `MapSystem`
- `VaultSystem`
- `PowerSystem`

Each system owns orchestration for one domain and talks to services, not to sibling systems.

## Boundary Rules

These rules are intentional and should be preserved:

1. `AppState` may depend on any system.
2. Systems may depend on services, shared models, and Apple frameworks.
3. Systems must not depend on `AppState`.
4. Systems must not depend on sibling systems directly.
5. Services must not depend on `AppState` or systems.

This is the desired graph:

```text
AppState
  -> PreparednessSystem
  -> SignalSystem
  -> MapSystem
  -> VaultSystem
  -> PowerSystem
```

This is explicitly not allowed:

```text
SignalSystem -> MapSystem
MapSystem -> PreparednessSystem
PreparednessSystem -> SignalSystem
PowerSystem -> AppState
```

## Cross-System Communication

If one domain needs data from another domain, use one of these patterns:

1. `AppState` coordinates the event and updates the relevant systems.
2. A shared model is passed down from `AppState`.
3. A service emits state that multiple systems can observe independently.

Avoid direct system-to-system references even if it feels convenient in the moment. Those shortcuts turn the system layer back into a tangled service graph.

## Lifecycle

All systems conform to `AppSystem`:

- `start()`
- `stop()`

`AppState` starts them centrally. This gives us one place to evolve lifecycle behavior later for:

- background refresh
- emergency session resets
- transport restarts
- future LoRa / satellite / responder bridge setup

## Practical Guidance

When adding a feature:

1. Decide which system owns the orchestration.
2. Put runtime behavior in that system.
3. Keep implementation details in services.
4. Let `AppState` handle only coordination across domains.

When a change feels like it needs two systems to talk directly, stop and route it through `AppState` or a shared service/model instead.

## Guardrails

The test suite includes an architecture boundary test that scans files under `RediM8/Systems/` and fails if a system source file references:

- `AppState`
- any sibling system type

That test is meant to keep these boundaries honest as the project grows.
