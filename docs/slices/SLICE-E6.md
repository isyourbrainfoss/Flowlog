# SLICE-E6: Accessibility pass

status: done
parallel_with: E1, E5

## Prerequisites

A5, C3

## Scope

- `app/flowlog a11y labels`
- `packages/flowlog_charts colorblind palette`

## Done when

- [x] Semantics labels on controls
- [x] High contrast option stub
- [x] Colour-blind safe chart colors

## Verify

```bash
cd app/flowlog && flutter test
```

## Fixture

none
