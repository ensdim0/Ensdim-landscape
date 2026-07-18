// Load environment from .env for local scripts
try {
  require('dotenv').config();
} catch (e) {
  // noop
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
  const { data, error } = await s.rpc('exec_sql', {
    sql: "ALTER TABLE public.visits ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();"
  });
  
  if (error) {
    console.log('RPC not available:', error.message);
    console.log('');
    console.log('Please run this SQL in the Supabase Dashboard SQL Editor:');
    console.log('ALTER TABLE public.visits ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();');
  } else {
    console.log('SUCCESS:', data);
  }
})();
