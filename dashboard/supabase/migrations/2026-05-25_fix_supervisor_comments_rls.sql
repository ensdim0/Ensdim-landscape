-- Fix: supervisor RLS policy on client_comments was missing the block_id → zone_id path.
-- Contracts can link to a zone either directly (zone_id) or via block_id → blocks.zone_id.
-- The old policy only checked zone_id, so contracts using the block path were invisible.

DROP POLICY IF EXISTS "Supervisors read assigned visit comments" ON public.client_comments;

CREATE POLICY "Supervisors read assigned visit comments"
  ON public.client_comments
  FOR SELECT
  USING (
    client_comments.visit_id IS NOT NULL
    AND EXISTS (
      SELECT 1
      FROM public.visits        v
      JOIN public.contracts     c  ON c.id  = v.contract_id
      LEFT JOIN public.zones    zd ON zd.id = c.zone_id
      LEFT JOIN public.blocks   b  ON b.id  = c.block_id
      LEFT JOIN public.zones    zb ON zb.id = b.zone_id
      JOIN public.users         u  ON u.assigned_line_id = COALESCE(zd.line_id, zb.line_id)
      WHERE v.id   = client_comments.visit_id
        AND u.id   = auth.uid()
        AND COALESCE(zd.line_id, zb.line_id) IS NOT NULL
    )
  );
