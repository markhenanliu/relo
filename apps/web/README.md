# Relo web companion

Next.js (App Router) + TypeScript + Tailwind CSS. Desktop-shaped tasks: label printing, expense tables, document upload, exports. See [docs/architecture.md](../../docs/architecture.md) §4.

```bash
cp .env.example .env.local   # fill in from `supabase status`
npm install
npm run dev                  # http://localhost:3000
npm test                     # Vitest, including shared test vectors in /schemas
```
