// Load environment from .env for local scripts (dev only)
try {
  require('dotenv').config();
} catch (e) {
  // noop: dotenv is a dev dependency and may not be present in some environments
}

const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = process.env.VITE_SUPABASE_URL || process.env.SUPABASE_URL;
const SUPABASE_ANON_KEY = process.env.VITE_SUPABASE_ANON_KEY || process.env.SUPABASE_ANON_KEY;

if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
  console.error('Missing Supabase environment variables. Set VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY (or SUPABASE_URL / SUPABASE_ANON_KEY) in your environment or .env file.');
  process.exit(1);
}

const s = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

(async () => {
  const { data, error } = await s
    .from('visits')
    .update({ status: 'in_progress' })
    .eq('id', 'c51e3489-3e9b-4e2d-b8b9-63c9e7d312ed')
    .select('*')
    .single();
  
  if (error) {
    console.log('Update ERROR:', JSON.stringify(error, null, 2));
  } else {
    console.log('Update SUCCESS:', JSON.stringify(data, null, 2));
  }
})();
