-- =====================================================================
-- MoroHunt — Migration 0008: Room members sidebar + admin kick
--
-- `session_participants` never had a DELETE policy at all, which meant
-- `leaveRoom()` could never actually remove a row — it only ever
-- unsubscribed the client locally, so every session's member list grew
-- forever and never reflected who was truly still in the room. Fixing
-- that is required for the new members sidebar to be accurate, and is
-- also the mechanism the admin-kick feature relies on.
-- =====================================================================

-- A user can always remove their own participant row (voluntary leave).
create policy "participants_delete_self" on public.session_participants
    for delete using (auth.uid() = user_id);

-- The room's creator (admin) can remove ANY participant row from a
-- session they created — this is the "kick" action.
create policy "participants_delete_by_admin" on public.session_participants
    for delete using (
        exists (
            select 1 from public.hunt_sessions hs
            where hs.id = session_participants.session_id
              and hs.creator_id = auth.uid()
        )
    );
