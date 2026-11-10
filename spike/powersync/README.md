# Sync spike (ADR-0004)

Throwaway harness that proved PowerSync for Relo's offline-first sync. Results are in [docs/adr/0004-offline-first-sync.md](../../docs/adr/0004-offline-first-sync.md).

```bash
supabase start                 # from the repo root
docker-compose up -d           # from this folder: PowerSync service + its storage database
./run-spike.sh                 # fresh test user, then every scenario end to end
```

- `harness/`: Swift command-line tool (PowerSync Swift SDK + a minimal Supabase connector)
- `config/`: PowerSync service and sync config
- `.state/`: git-ignored; local test session and simulated device databases
