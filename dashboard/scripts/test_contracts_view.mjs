import { config } from 'dotenv';
config();
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(process.env.VITE_SUPABASE_URL, process.env.VITE_SUPABASE_ANON_KEY);

async function run() {
  const { data, error } = await supabase.from('contracts_view').select('client_name, client_email').limit(1);
  console.log('DATA:', data);
  if (error) console.error('ERROR:', error);
}
run();
