-- contracts.code was UNIQUE across the whole table (from before multi-tenancy
-- existed), so two different companies (tenants) both picking the same
-- sequential code — e.g. "NO-0001" for their first contract — collide with
-- a 409 conflict, even though each tenant only ever sees its own contracts.
-- Scope the uniqueness to (tenant_id, code) instead, matching how RLS and
-- the app already scope everything else per tenant.

ALTER TABLE public.contracts DROP CONSTRAINT IF EXISTS contracts_code_key;
ALTER TABLE public.contracts ADD CONSTRAINT contracts_tenant_code_key UNIQUE (tenant_id, code);
