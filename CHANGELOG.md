## v0.0.9

- perf: avoid meaningless setting of flags by subscribers

## v0.0.8

- perf: Remove the redundant else
- perf: remove unnecessary dirty variable updates
- perf: avoid unnecessary property access
- perf: store value instead of version number in Link for dirty check

## v0.0.7

- fix: scope is coerced into type during propagation

## v0.0.6

- perf: avoid unnecessary assignment operations in checkDirty
- perf: reuse depSubs checkDirty

## v0.0.5

- docs: update readme
- perf: no recursive calls, performance improvement **17%**
- chore: add benchamrk test
- chore: add scope example

## v0.0.4

- docs: add doc comments
- fix: fix repo link

## v0.0.3

- docs: update readme

## v0.0.2

- feat: Complete implementation
- feat: Add compatibility feature (`.value` getter/setter prop)
