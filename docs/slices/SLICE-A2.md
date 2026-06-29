# SLICE-A2: Vendored protocol docs

status: pending
parallel_with: A3, A5

## Prerequisites

A1

## Scope

- `docs/protocols/pressensor-prs.md`
- `docs/protocols/decent-scale-ble.md`

## Done when

- [ ] Pressensor PRS BLE UUIDs and notify format documented
- [ ] Decent Scale BLE commands and FFF4 parse format documented
- [ ] Links to official sources in doc headers

## Verify

```bash
test -f docs/protocols/pressensor-prs.md && test -f docs/protocols/decent-scale-ble.md
```

## Fixture

none
