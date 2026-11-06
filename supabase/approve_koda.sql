-- WhereToNext — approve the Koda username account
-- Run in: Supabase Dashboard → SQL Editor, AFTER creating the account under
-- Authentication → Users → Add user.
--
-- Create the account there with:
--   Email:  koda@wheretonext.app      (the app maps the username "Koda" to this)
--   Password: (set it in that form — it is never stored in this repo)
--   Auto Confirm User: ON             (no verification email is sent)
--
-- The wtn_handle_new_user trigger creates the profile automatically; this
-- just gives it a display name and flips the approval flag so the account
-- can actually get past the "Request Access" screen.

update wtn_profiles
   set name = coalesce(nullif(name,''), 'Koda'),
       approved = true
 where lower(email) = 'koda@wheretonext.app';

-- Confirm it worked — expect one row with approved = true
select id, email, name, approved from wtn_profiles
 where lower(email) = 'koda@wheretonext.app';
