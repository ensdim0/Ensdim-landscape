
// @ts-nocheck
// Callable only by a platform owner (users.is_platform_owner = true).
// Creates a new tenant (company) plus its first admin user in one step.
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

function slugify(input: string): string {
  const base = input
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')

  // Arabic (or any non-Latin) company names have no a-z0-9 characters at
  // all, so `base` collapses to an empty string — fall back to a random
  // slug instead of failing validation.
  if (base) return base
  return `company-${crypto.randomUUID().slice(0, 8)}`
}

serve(async (req: Request) => {
  const origin = req.headers.get('origin')
  const corsHeaders = getCorsHeaders(origin)
  let supabaseAdmin: any = null
  let createdUserId: string | null = null
  let createdTenantId: string | null = null

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

    supabaseAdmin = createClient(supabaseUrl, serviceRoleKey)

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

    const { companyName, companySlug, adminFullName, adminEmail, adminPhone, adminPassword } = await req.json()

    const name = typeof companyName === 'string' ? companyName.trim() : ''
    const fullName = typeof adminFullName === 'string' ? adminFullName.trim() : ''
    const email = typeof adminEmail === 'string' ? adminEmail.trim().toLowerCase() : ''
    const phone = typeof adminPhone === 'string' ? adminPhone.trim().replace(/[^0-9+]/g, '') : ''
    const slug = slugify(typeof companySlug === 'string' && companySlug.trim() ? companySlug : name)

    if (!name || !slug || !fullName || !email || !phone || !adminPassword) {
      return new Response(JSON.stringify({ error: 'Missing required fields' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      })
    }

    const { data: existingSlug } = await supabaseAdmin
      .from('tenants')
      .select('id')
      .eq('slug', slug)
      .maybeSingle()

    if (existingSlug) {
      return new Response(JSON.stringify({ error: 'Slug already in use', code: 'SLUG_ALREADY_EXISTS' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      })
    }

    const { data: tenantRow, error: tenantError } = await supabaseAdmin
      .from('tenants')
      .insert({ name, slug, status: 'active' })
      .select('id, name, slug, status, created_at')
      .single()

    if (tenantError || !tenantRow) {
      throw tenantError || new Error('Failed to create tenant')
    }

    createdTenantId = tenantRow.id

    const { data: createData, error: createError } = await supabaseAdmin.auth.admin.createUser({
      email,
      password: adminPassword,
      email_confirm: true,
      app_metadata: { role: 'admin' },
      user_metadata: { fullName, role: 'admin', phone, tenant_id: createdTenantId },
    })

    if (createError) {
      throw createError
    }

    const user = createData.user
    if (!user) {
      throw new Error('Failed to create admin auth user')
    }

    createdUserId = user.id

    const { error: profileUpsertError } = await supabaseAdmin
      .from('users')
      .upsert({ id: user.id, full_name: fullName, email, phone, tenant_id: createdTenantId }, { onConflict: 'id' })

    if (profileUpsertError) {
      throw profileUpsertError
    }

    const { data: adminRole, error: adminRoleError } = await supabaseAdmin
      .from('roles')
      .select('id')
      .eq('name', 'admin')
      .single()

    if (adminRoleError || !adminRole) {
      throw adminRoleError || new Error('Admin role not found')
    }

    // handle_new_user() always assigns the default 'client' role on auth.users
    // insert — remove it first so this user ends up with exactly one role
    // (otherwise users_view's join returns 2 rows and .maybeSingle() on the
    // dashboard silently falls back to role "client").
    const { error: deleteRoleError } = await supabaseAdmin
      .from('user_roles')
      .delete()
      .eq('user_id', user.id)

    if (deleteRoleError) {
      throw deleteRoleError
    }

    const { error: roleInsertError } = await supabaseAdmin
      .from('user_roles')
      .insert({ user_id: user.id, role_id: adminRole.id })

    if (roleInsertError) {
      throw roleInsertError
    }

    return new Response(JSON.stringify({
      success: true,
      tenant: tenantRow,
      admin: { id: user.id, email, fullName, phone },
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (error: any) {
    console.error('platform-create-company error:', error)
    try {
      if (createdUserId && supabaseAdmin) {
        await supabaseAdmin.auth.admin.deleteUser(createdUserId)
      }
      if (createdTenantId && supabaseAdmin) {
        await supabaseAdmin.from('tenants').delete().eq('id', createdTenantId)
      }
    } catch (rollbackErr) {
      console.error('platform-create-company rollback exception:', rollbackErr)
    }

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
