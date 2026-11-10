import { createBrowserClient } from "@supabase/ssr";

/** Supabase client for Client Components. Access is enforced by RLS in Postgres, not here. */
export function createClient() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  if (!url || !key) {
    throw new Error("Missing NEXT_PUBLIC_SUPABASE_URL or NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY. Copy .env.example to .env.local.");
  }
  return createBrowserClient(url, key);
}
