
// @ts-nocheck
// Callable only by a platform owner (users.is_platform_owner = true).
// Permanently deletes a tenant (company) and every row that belongs to it —
// contracts, visits, payments, photos, users, everything. Irreversible.
// Requires the caller to pass the tenant's exact slug as confirmSlug so a
// misclick can't wipe the wrong company.
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const rawAllowedOrigins = (Deno.env.get('ALLOWED_ORIGINS') ?? '').trim()
const hasExplicitAllowedOrigins = rawAllowedOrigins.length > 0
const allowedOrigins = (hasExplicitAllowedOrigins
  ? rawAllowedOrigins
  : 'http://localhost:5173,http://localhost:3000')
  .split(',')
  .map((origin) => origin.trim())
  .filter(Boolean)

function isLocalDevOrigin(origin: string): boolean {
  try {
    const parsed = new URL(origin)
    return parsed.protocol === 'http:'
      && (parsed.hostname === 'localhost' || parsed.hostname === '127.0.0.1' || parsed.hostname === '[::1]' || parsed.hostname === '::1')
  } catch {
    return false
  }
}

function isAllowedOrigin(origin: string | null): boolean {
  if (!origin) return false
  if (isLocalDevOrigin(origin)) return true
  if (allowedOrigins.includes('*') || allowedOrigins.includes(origin)) return true
  if (!hasExplicitAllowedOrigins) {
    try {
      const parsed = new URL(origin)
      const isLocalhost = (parsed.hostname === 'localhost' || parsed.hostname === '127.0.0.1') && parsed.protocol === 'http:'
      return parsed.protocol === 'https:' || isLocalhost
    } catch {
      return false
    }
  }
  return false
}

function getCorsHeaders(origin: string | null) {
  const safeOrigin = isAllowedOrigin(origin) ? origin : 'null'
  return {
    'Access-Control-Allow-Origin': safeOrigin,
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Vary': 'Origin',
  }
}

function extractBearerToken(headerValue: string | null): string {
  if (!headerValue) return ''
  const match = headerValue.match(/^Bearer\s+(.+)$/i)
  return match?.[1]?.trim() ?? ''
}

serve(async (req: Request) => {
  const origin = req.headers.get('origin')
  const corsHeaders = getCorsHeaders(origin)

  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders, status: 200 })
  }

  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 405,
    })
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

    if (!supabaseUrl || !serviceRoleKey) {
      return new Response(JSON.stringify({ error: 'Server misconfiguration' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500,
      })
    }

    const authHeader = req.headers.get('Authorization') ?? req.headers.get('authorization')
    const accessToken = extractBearerToken(authHeader)

    if (!accessToken) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 401,
      })
    }

    const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey)

    const {
      data: { user: callerUser },
      error: authError,
    } = await supabaseAdmin.auth.getUser(accessToken)

    if (authError || !callerUser) {
      return new Response(JSON.stringify({ error: 'Unauthorized', message: authError?.message || 'Invalid or expired access token' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 401,
      })
    }

    const { data: callerProfile } = await supabaseAdmin
      .from('users')
      .select('is_platform_owner')
      .eq('id', callerUser.id)
      .maybeSingle()

    if (!callerProfile?.is_platform_owner) {
      return new Response(JSON.stringify({ error: 'Forbidden', message: 'Platform owner required' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 403,
      })
    }

    const { tenantId, confirmSlug } = await req.json()

    if (!tenantId || !confirmSlug) {
      return new Response(JSON.stringify({ error: 'Missing tenantId or confirmSlug' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      })
    }

    const { data: tenantRow, error: tenantError } = await supabaseAdmin
      .from('tenants')
      .select('id, slug, name')
      .eq('id', tenantId)
      .maybeSingle()

    if (tenantError || !tenantRow) {
      return new Response(JSON.stringify({ error: 'Not found', message: 'Tenant not found' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 404,
      })
    }

    if (String(confirmSlug).trim() !== tenantRow.slug) {
      return new Response(JSON.stringify({ error: 'Confirmation mismatch', message: 'confirmSlug does not match the tenant slug' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      })
    }

    // Collect every auth user that belongs to this tenant BEFORE the cascade
    // delete removes their public.users profile.
    const { data: tenantUsers } = await supabaseAdmin
      .from('users')
      .select('id')
      .eq('tenant_id', tenantId)

    const userIds: string[] = (tenantUsers ?? []).map((u: { id: string }) => u.id)

    // Deleting the tenant row cascades through every table that references
    // tenant_id (contracts, visits, payments, photos, public.users, ...) —
    // see 2026-07-26_tenant_cascade_delete.sql.
    const { error: deleteTenantError } = await supabaseAdmin
      .from('tenants')
      .delete()
      .eq('id', tenantId)

    if (deleteTenantError) {
      throw deleteTenantError
    }

    // Clean up the auth.users accounts themselves (not covered by the
    // public-schema cascade). Best effort — report any failures rather than
    // rolling back, since the business data is already gone at this point.
    const failures: Array<{ id: string; message: string }> = []
    for (const userId of userIds) {
      const { error: deleteUserError } = await supabaseAdmin.auth.admin.deleteUser(userId)
      if (deleteUserError) {
        failures.push({ id: userId, message: deleteUserError.message })
      }
    }

    return new Response(JSON.stringify({
      success: true,
      deletedTenant: tenantRow,
      deletedUserCount: userIds.length - failures.length,
      failures,
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (error: any) {
    console.error('platform-delete-company error:', error)
    return new Response(JSON.stringify({
      error: error?.message || 'Internal server error',
      details: error?.code || error?.toString(),
      success: false,
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    })
  }
})
