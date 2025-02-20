## v0.2.2

test: notify duplicate effect in subs
refactor: remove unneeded subs property access

## v0.2.1

chore: cleanup avoid link setter
refactor: remove unneeded flags check in processComputedUpdate
refactor: simplify logic in processComputedUpdate
refactor: clean SubscriberFlags factory
fix: safe clean link
pref: Avoid meaningless type conversions


## v0.2.0

- refactor: Independent reactive system to avoid pollution conflicts

## v0.1.0

- feat: add `isDirty` and `runInnerEffects` utils
- perf: exit edge case condition early in propagate if possible
- refactor: combined flags for a subscriber in a notified state
- refactor: reduce if branch
- refactor: no longer use activeTrackId, activeScopeTrackId
- refactor: move batch logic out of system

## v0.0.17

- refactor: sync upstream

## v0.0.16

- refactor: streamline propagate function and remove nextSub intermediate variable
- fix: newLink with late final

## v0.0.15

- pref: flatten`if` branches in propagate function
- refactor: change `link` returns void
- fix: handle recursed effects correctly

## v0.0.14

- avoid invalid doc comments

## v0.0.13

- refactor: avoid meaningless interface constraints
- refactor: avoid unnecessary casts

## v0.0.12

- refactor: remove _alwaysTrue
- refactor: repalce >> 2 for readability
- fix: Null check operator used on a null value
- feat: add setActiveScope
- feat: add untrack
- feat: add untrackScope

## v0.0.11

- refactor: enhance condition check in shallowPropagate for SubscriberFlags
- perf: remove all unnecessary flags assignments

## v0.0.10

- feat: sync upstream push-pull model
- refactor: update condition in shallowPropagate to use ToCheckDirty flag
- refactor: rename RunInnerEffects flag to InnerEffectsPending in SubscriberFlags
- refactor: rename CanPropagate flag to Recursed in SubscriberFlags
- pref: remove canPropagate intermediate variable

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
