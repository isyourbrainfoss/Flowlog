# SLICE-A2: Vendored protocol docs

status: done
parallel_with: A3, A5

## Prerequisites

A1

## Scope

- `docs/protocols/pressensor-prs.md`
- `docs/protocols/decent-scale-ble.md`

## Done when

- [x] Pressensor PRS BLE UUIDs and notify format documented
- [x] Decent Scale BLE commands and FFF4 parse format documented
- [x] Links to official sources in doc headers

## Verify

```bash
test -f docs/protocols/pressensor-prs.md && test -f docs/protocols/decent-scale-ble.md
```

## Fixture

none
