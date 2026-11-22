-- Skill Finder upgrade: paste ALL of this into Supabase > SQL Editor > New query > Run

alter table profiles add column if not exists verified boolean default false;
alter table profiles add column if not exists featured_until timestamptz;
alter table profiles add column if not exists created_at timestamptz default now();

create table if not exists admins (user_id uuid primary key references auth.users on delete cascade);
alter table admins enable row level security;
create policy "see own admin row" on admins for select using (auth.uid() = user_id);

create or replace function is_admin() returns boolean
language sql security definer stable as $$
  select exists (select 1 from admins where user_id = auth.uid())
$$;

create policy "admin edits profiles" on profiles for update using (is_admin());
create policy "admin deletes profiles" on profiles for delete using (is_admin());

-- Only the owner can verify or feature a profile
create or replace function guard_profile() returns trigger
language plpgsql security definer as $$
begin
  if not is_admin() then
    if tg_op = 'INSERT' then new.verified := false; new.featured_until := null;
    else new.verified := old.verified; new.featured_until := old.featured_until; end if;
  end if;
  return new;
end $$;
create trigger guard_profile_t before insert or update on profiles
  for each row execute function guard_profile();

-- Top banner for advertisers
create table if not exists banners (
  id bigint generated always as identity primary key,
  text text not null,
  link text,
  active boolean default true,
  created_at timestamptz default now()
);
alter table banners enable row level security;
create policy "all see banners" on banners for select using (true);
create policy "admin adds banners" on banners for insert with check (is_admin());
create policy "admin edits banners" on banners for update using (is_admin());
create policy "admin deletes banners" on banners for delete using (is_admin());

-- LATER, after you create your account inside the app, run this on its own
-- (replace the email with the one you used in the app) to make yourself the owner:
-- insert into admins (user_id) select id from auth.users where email = 'YOUR_APP_EMAIL';
