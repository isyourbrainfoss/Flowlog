# Slices

One markdown file per agent task. Naming: `SLICE-{ID}.md` (e.g. `SLICE-A3.md`).

| File | Purpose |
|------|---------|
| [`../BACKLOG.md`](../BACKLOG.md) | Master table with status |
| [`../PARALLEL.md`](../PARALLEL.md) | Which slices to spawn together |
| [`../AGENT_GUIDE.md`](../AGENT_GUIDE.md) | How to execute a slice |

Regenerate all slice stubs from manifest:

```bash
python3 tool/generate_slices.py
```

**Warning:** Regenerating overwrites slice files and resets `status` to manifest defaults. Edit `tool/generate_slices.py` or patch files after regen.