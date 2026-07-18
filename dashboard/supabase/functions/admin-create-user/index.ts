
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
  let supabaseAdmin: any = null
  let createdUserId: string | null = null

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

    supabaseAdmin = createClient(
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

    let { email, password, fullName, role, phone, assignedLineId, assignmentStartDate, assignmentEndDate } = await req.json()
    const normalizedPhone = typeof phone === 'string' ? phone.trim() : '';
    const normalizedEmail = typeof email === 'string' ? email.trim().toLowerCase() : '';
    const actualPhone = normalizedPhone.replace(/[^0-9+]/g, '') || null;
    const providedEmail = normalizedEmail || null;

    if (!password || !fullName || !actualPhone) {
      return new Response(JSON.stringify({ error: 'Missing required fields' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      })
    }

    if (providedEmail && !providedEmail.includes('@')) {
      return new Response(JSON.stringify({
        error: 'Invalid email',
        message: 'Email must be a valid email address when provided.'
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      });
    }

    const { data: existingPhone, error: existingPhoneError } = await supabaseAdmin
      .from('users')
      .select('id')
      .eq('phone', actualPhone)
      .maybeSingle();

    if (existingPhoneError) {
      throw existingPhoneError;
    }

    if (existingPhone) {
      return new Response(JSON.stringify({
        error: 'رقم الهاتف مستخدم بالفعل',
        code: 'PHONE_ALREADY_EXISTS',
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      });
    }

    if (providedEmail) {
      const { data: existingEmail, error: existingEmailError } = await supabaseAdmin
        .from('users')
        .select('id')
        .eq('email', providedEmail)
        .maybeSingle();

      if (existingEmailError) {
        throw existingEmailError;
      }

      if (existingEmail) {
        return new Response(JSON.stringify({
          error: 'البريد الإلكتروني مستخدم بالفعل',
          code: 'EMAIL_ALREADY_EXISTS',
        }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 400,
        });
      }
    }

    const actualEmail = providedEmail || `${actualPhone}@bustanamari.com`;

    let user;

    const { data: createData, error: createError } = await supabaseAdmin.auth.admin.createUser({
      email: actualEmail,
      password,
      email_confirm: true,
      app_metadata: { role: role || 'client' },
      user_metadata: { fullName, role: role || 'client', phone: actualPhone }
    })

    if (createError) {
      if (createError.message?.includes("already has been registered") || createError.status === 422) {
        const duplicateError = providedEmail
          ? { error: 'البريد الإلكتروني مستخدم بالفعل', code: 'EMAIL_ALREADY_EXISTS' }
          : { error: 'رقم الهاتف مستخدم بالفعل', code: 'PHONE_ALREADY_EXISTS' };

        return new Response(JSON.stringify({
          ...duplicateError,
          message: 'لا يمكن إنشاء مستخدم بنفس البريد الإلكتروني أو رقم الهاتف.'
        }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 400,
        });
      }

      throw createError;
    }

    user = createData.user;
    if (!user) {
      throw new Error('Failed to create auth user');
    }

    createdUserId = user.id;

    const targetRole = role || 'client';

    const { error: profileUpsertError } = await supabaseAdmin
      .from('users')
      .upsert({
        id: user.id,
        full_name: fullName,
        email: actualEmail,
        phone: actualPhone,
        assigned_line_id: targetRole === 'supervisor' ? (assignedLineId || null) : null,
        assignment_start_date: targetRole === 'supervisor' ? (assignmentStartDate || null) : null,
        assignment_end_date: targetRole === 'supervisor' ? (assignmentEndDate || null) : null,
      }, { onConflict: 'id' });

    if (profileUpsertError) {
      if (profileUpsertError.code === '23505') {
        const duplicateField = String(profileUpsertError.message || '').toLowerCase().includes('phone')
          ? 'phone'
          : 'email';

        return new Response(JSON.stringify({
          error: duplicateField === 'phone' ? 'رقم الهاتف مستخدم بالفعل' : 'البريد الإلكتروني مستخدم بالفعل',
          code: duplicateField === 'phone' ? 'PHONE_ALREADY_EXISTS' : 'EMAIL_ALREADY_EXISTS',
          message: 'لا يمكن إنشاء مستخدم بنفس البريد الإلكتروني أو رقم الهاتف.'
        }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 400,
        });
      }

      throw profileUpsertError;
    }

    const { data: roleData, error: roleLookupError } = await supabaseAdmin
      .from('roles')
      .select('id')
      .eq('name', targetRole)
      .single();

    if (roleLookupError || !roleData) {
      throw roleLookupError || new Error('Target role not found');
    }

    const { error: deleteRoleError } = await supabaseAdmin
      .from('user_roles')
      .delete()
      .eq('user_id', user.id);

    if (deleteRoleError) {
      throw deleteRoleError;
    }

    const { error: insertRoleError } = await supabaseAdmin
      .from('user_roles')
      .insert({
        user_id: user.id,
        role_id: roleData.id
      });

    if (insertRoleError) {
      throw insertRoleError;
    }

    if (targetRole === 'supervisor' && assignedLineId) {
      const { error: updateErr } = await supabaseAdmin
        .from('users')
        .update({
          assigned_line_id: assignedLineId,
          assignment_start_date: assignmentStartDate || null,
          assignment_end_date: assignmentEndDate || null
        })
        .eq('id', user.id);
      if (updateErr) throw updateErr;
    }

    return new Response(JSON.stringify({ 
      ...user, 
      role: targetRole,
      success: true,
      message: 'User created successfully'
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })

  } catch (error: any) {
    console.error('admin-create-user error:', error);
    try {
      if (createdUserId && supabaseAdmin) {
        const { error: deleteErr } = await supabaseAdmin.auth.admin.deleteUser(createdUserId);
        if (deleteErr) {
          console.error('Rollback delete failed:', deleteErr);
        }
      }
    } catch (rollbackErr) {
      console.error('Rollback exception:', rollbackErr);
    }

    return new Response(JSON.stringify({ 
      error: error?.message || 'Internal server error',
      details: error?.code || error?.toString(),
      success: false
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    })
  }
})
