-- Logical-replication publication that the PowerSync service reads changes from (ADR-0004).
-- Add every table that should sync to devices here.
create publication powersync for table public.moves, public.expenses;
