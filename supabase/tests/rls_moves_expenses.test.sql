-- pgTAP tests: row-level security on moves and expenses.
-- Run with `supabase test db`. Each test runs in a transaction that is rolled back.
begin;

create extension if not exists pgtap with schema extensions;

select plan(17);

-- Fixtures (as the postgres superuser) ---------------------------------------
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@example.test'),
  ('22222222-2222-2222-2222-222222222222', 'bob@example.test');

insert into public.moves (id, user_id, name) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'Alice: Boston to Chicago');

insert into public.expenses (user_id, move_id, amount_cents, occurred_on, merchant, category_id) values
  ('11111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 8742, '2026-11-20', 'Hardware store', 'packing');

-- Every table in public has RLS enabled ---------------------------------------
select is_empty(
  $$ select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity $$,
  'every table in public has row-level security enabled'
);

-- Signed-out clients ----------------------------------------------------------
set local role anon;
select throws_ok($$ select * from public.moves $$, '42501', null, 'anon cannot read moves');
select throws_ok($$ select * from public.expenses $$, '42501', null, 'anon cannot read expenses');
reset role;

-- Alice sees her own data -----------------------------------------------------
set local role authenticated;
set local request.jwt.claims to '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';

select is((select count(*)::int from public.moves), 1, 'Alice sees her move');
select is((select count(*)::int from public.expenses), 1, 'Alice sees her expense');
select lives_ok(
  $$ insert into public.expenses (move_id, amount_cents, occurred_on, category_id)
     values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 2500, '2026-11-21', 'fuel') $$,
  'Alice can add an expense to her move (user_id defaults to auth.uid())'
);
select throws_ok(
  $$ insert into public.expenses (move_id, amount_cents, occurred_on, category_id)
     values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', -1, '2026-11-21', 'fuel') $$,
  '23514', null, 'negative amounts are rejected'
);

-- Bob cannot see or touch Alice's data -----------------------------------------
set local request.jwt.claims to '{"sub": "22222222-2222-2222-2222-222222222222", "role": "authenticated"}';

select is_empty($$ select * from public.moves $$, 'Bob cannot see Alice''s moves');
select is_empty($$ select * from public.expenses $$, 'Bob cannot see Alice''s expenses');

-- RLS hides rows rather than raising errors, so a blocked update/delete touches zero rows.
select is_empty(
  $$ update public.moves set name = 'hijacked' returning id $$,
  'Bob cannot update Alice''s move'
);
select is_empty(
  $$ delete from public.expenses returning id $$,
  'Bob cannot delete Alice''s expenses'
);

select throws_ok(
  $$ insert into public.moves (user_id, name) values ('11111111-1111-1111-1111-111111111111', 'spoofed') $$,
  '42501', null, 'Bob cannot create a move owned by Alice'
);
select throws_ok(
  $$ insert into public.expenses (move_id, amount_cents, occurred_on, category_id)
     values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 100, '2026-11-21', 'fuel') $$,
  '23503', null, 'Bob cannot attach an expense to Alice''s move (composite foreign key)'
);
select throws_ok(
  $$ insert into public.expenses (user_id, move_id, amount_cents, occurred_on, category_id)
     values ('11111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 100, '2026-11-21', 'fuel') $$,
  '42501', null, 'Bob cannot insert an expense claiming to be Alice'
);

select lives_ok(
  $$ insert into public.moves (id, name) values ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Bob: Austin to Denver') $$,
  'Bob can create his own move'
);
select throws_ok(
  $$ update public.moves set user_id = '11111111-1111-1111-1111-111111111111' where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' $$,
  '42501', null, 'Bob cannot give his move to Alice'
);

-- Alice's data is unchanged -----------------------------------------------------
reset role;
select is(
  (select name from public.moves where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  'Alice: Boston to Chicago', 'Alice''s move is unchanged'
);

select * from finish();
rollback;
