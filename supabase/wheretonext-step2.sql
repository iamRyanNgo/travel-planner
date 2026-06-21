-- WhereToNext — Step 2
-- Run AFTER wheretonext.sql (requires wtn_trip_members to exist)

do $$ begin
  if not exists (select 1 from pg_policies where policyname='wtn_profiles_member_read' and tablename='wtn_profiles') then
    create policy wtn_profiles_member_read on wtn_profiles for select using (
      exists (
        select 1 from wtn_trip_members a
        join wtn_trip_members b on b.trip_id = a.trip_id
        where a.user_id = auth.uid() and b.user_id = id
      )
    );
  end if;
end $$;
