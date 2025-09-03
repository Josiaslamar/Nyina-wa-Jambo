import { serve } from "https://deno.land/std/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
);

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
      },
    });
  }

  try {
    // Get authorization header
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Unauthorized - No token provided' }), { 
        status: 401,
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' }
      });
    }

    // Verify the requesting user is authenticated and is an admin
    const token = authHeader.replace('Bearer ', '');
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);
    
    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'Invalid or expired token' }), { 
        status: 401,
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' }
      });
    }

    // Check if user is admin
    const { data: profile, error: profileError } = await supabase
      .from('user_profiles')
      .select('role, full_name')
      .eq('id', user.id)
      .eq('is_active', true)
      .single();

    if (profileError || profile?.role !== 'admin') {
      return new Response(JSON.stringify({ error: 'Admin access required' }), { 
        status: 403,
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' }
      });
    }

    // Parse request body
    const { email, password, fullName, role, username, phone, address } = await req.json();

    // Validate required fields
    if (!email || !password || !fullName || !role) {
      return new Response(JSON.stringify({ 
        error: 'Missing required fields: email, password, fullName, and role are required' 
      }), { 
        status: 400,
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' }
      });
    }

    // Validate role
    const validRoles = ['admin', 'receptionist', 'customer'];
    if (!validRoles.includes(role)) {
      return new Response(JSON.stringify({ 
        error: `Invalid role. Must be one of: ${validRoles.join(', ')}` 
      }), { 
        status: 400,
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' }
      });
    }

    // Create user with admin privileges
    const { data: userData, error: createError } = await supabase.auth.admin.createUser({
      email: email,
      password: password,
      email_confirm: true, // Skip email confirmation
      user_metadata: {
        full_name: fullName,
        role: role
      }
    });

    if (createError) {
      throw new Error(`User creation failed: ${createError.message}`);
    }

    // Create user profile
    const { error: profileInsertError } = await supabase
      .from("user_profiles")
      .insert({
        id: userData.user.id,
        username: username || email.split('@')[0],
        full_name: fullName,
        role: role,
        phone: phone || null,
        address: address || null,
        created_by: user.id, // The admin who created this user
        is_active: true
      });

    if (profileInsertError) {
      // If profile creation fails, we should clean up the auth user
      // Note: In production, you might want to implement a rollback mechanism
      console.error('Profile creation failed:', profileInsertError);
      throw new Error(`Profile creation failed: ${profileInsertError.message}`);
    }

    // Return success response
    return new Response(JSON.stringify({ 
      success: true, 
      user: {
        id: userData.user.id,
        email: userData.user.email,
        full_name: fullName,
        role: role,
        created_at: userData.user.created_at
      },
      message: `User ${fullName} created successfully`
    }), {
      status: 201,
      headers: { 
        "Content-Type": "application/json",
        'Access-Control-Allow-Origin': '*'
      },
    });

  } catch (err) {
    console.error('Admin create user error:', err);
    
    return new Response(JSON.stringify({ 
      error: err.message || 'An unexpected error occurred',
      success: false 
    }), { 
      status: 500,
      headers: { 
        "Content-Type": "application/json",
        'Access-Control-Allow-Origin': '*'
      }
    });
  }
});