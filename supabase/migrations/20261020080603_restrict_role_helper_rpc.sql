-- These helper functions are only needed by signed-in users and RLS policies.
-- Anonymous requests do not have a user identity and do not need direct RPC access.
alter function public.has_role(public.user_role) set search_path = '';
alter function public.is_admin() set search_path = '';

revoke all on function public.has_role(public.user_role) from public, anon;
revoke all on function public.is_admin() from public, anon;

grant execute on function public.has_role(public.user_role) to authenticated;
grant execute on function public.is_admin() to authenticated;
