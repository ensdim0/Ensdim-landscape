
// @ts-nocheck
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

  if (isLocalDevOrigin(origin)) {
    return true
  }

  if (allowedOrigins.includes('*') || allowedOrigins.includes(origin)) {
    return true
  }

  if (!hasExplicitAllowedOrigins) {
    // Safe fallback for environments that forgot to configure ALLOWED_ORIGINS.
    try {
      const parsed = new URL(origin)
      const isLocalhost =
        (parsed.hostname === 'localhost' || parsed.hostname === '127.0.0.1')
        && parsed.protocol === 'http:'
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

    const supabaseAdmin = createClient(
      supabaseUrl,
      serviceRoleKey
    )

    const {
      data: { user: callerUser },
      error: authError,
    } = await supabaseAdmin.auth.getUser(accessToken)

    if (authError || !callerUser) {
      return new Response(JSON.stringify({
        error: 'Unauthorized',
        message: authError?.message || 'Invalid or expired access token',
        details: authError?.code || authError?.status || null,
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 401,
      })
    }

    const appMetadataRole = String((callerUser as any)?.app_metadata?.role ?? '').toLowerCase()
    let hasAdminRole = appMetadataRole === 'admin'

    if (!hasAdminRole) {
      const { data: adminRoleRow } = await supabaseAdmin
        .from('roles')
        .select('id')
        .eq('name', 'admin')
        .maybeSingle()

      if (adminRoleRow) {
        const { data: callerAdminRole } = await supabaseAdmin
          .from('user_roles')
          .select('user_id')
          .eq('user_id', callerUser.id)
          .eq('role_id', adminRoleRow.id)
          .maybeSingle()

        hasAdminRole = Boolean(callerAdminRole)
      }
    }

    if (!hasAdminRole) {
      return new Response(JSON.stringify({ error: 'Forbidden', message: 'Admin role required' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 403,
      })
    }

    const { id } = await req.json()
    if (!id) {
      return new Response(JSON.stringify({ error: 'Missing user id' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      })
    }

    await supabaseAdmin.from('user_roles').delete().eq('user_id', id)

    await supabaseAdmin.from('users').update({ deleted_at: new Date().toISOString() }).eq('id', id)

    const { error: deleteError } = await supabaseAdmin.auth.admin.deleteUser(id)
    if (deleteError) throw deleteError

    return new Response(JSON.stringify({ success: true }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })

  } catch (error: any) {
    return new Response(JSON.stringify({ error: 'Internal server error' }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    })
  }
})
