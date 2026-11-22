-- Skill Finder: paste ALL of this into Supabase > SQL Editor > New query > Run

create table profiles (
  id uuid primary key references auth.users on delete cascade,
  name text not null,
  job text not null,
  city text,
  country text,
  phone text,
  description text,
  photos text[] default '{}',
  last_active timestamptz default now(),
  rating_avg numeric default 0,
  rating_count int default 0
);
alter table profiles enable row level security;
create policy "anyone can read profiles" on profiles for select using (true);
create policy "create own profile" on profiles for insert with check (auth.uid() = id);
create policy "edit own profile" on profiles for update using (auth.uid() = id);

create table ratings (
  profile_id uuid references profiles on delete cascade,
  rater uuid references auth.users on delete cascade,
  stars int check (stars between 1 and 5),
  primary key (profile_id, rater)
);
alter table ratings enable row level security;
create policy "anyone can read ratings" on ratings for select using (true);
create policy "rate others" on ratings for insert with check (auth.uid() = rater and rater <> profile_id);
create policy "change own rating" on ratings for update using (auth.uid() = rater);

create or replace function refresh_rating() returns trigger
language plpgsql security definer as $$
begin
  update profiles set
    rating_avg = (select avg(stars) from ratings where profile_id = new.profile_id),
    rating_count = (select count(*) from ratings where profile_id = new.profile_id)
  where id = new.profile_id;
  return new;
end $$;
create trigger on_rating after insert or update on ratings
  for each row execute function refresh_rating();

-- Photo storage
insert into storage.buckets (id, name, public) values ('photos', 'photos', true)
  on conflict do nothing;
create policy "anyone can see photos" on storage.objects for select using (bucket_id = 'photos');
create policy "upload to own folder" on storage.objects for insert to authenticated
  with check (bucket_id = 'photos' and (storage.foldername(name))[1] = auth.uid()::text);
