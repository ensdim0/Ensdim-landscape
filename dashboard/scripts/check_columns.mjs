// Load environment for local dev scripts
try {
  // Use ESM-compatible dotenv loader if available
  await import('dotenv/config');
} catch (e) {
  // ignore when not available in CI/runtime environments
}

import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = process.env.VITE_SUPABASE_URL || process.env.SUPABASE_URL;
const SUPABASE_ANON_KEY = process.env.VITE_SUPABASE_ANON_KEY || process.env.SUPABASE_ANON_KEY;

if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
  console.error('Missing Supabase environment variables. Set VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY (or SUPABASE_URL / SUPABASE_ANON_KEY).');
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

const tests = ['phone_number', 'car_number', 'custody_phone', 'vehicle_number'];

for (const col of tests) {
  const { data, error } = await supabase.from('geographic_lines').select(col).limit(1);
  console.log(`Column "${col}": ${error ? '❌ NOT FOUND - ' + error.message : '✅ EXISTS'}`);
}

const { data, error } = await supabase.from('geographic_lines').select('*').limit(1);
if (data && data[0]) {
  console.log('\nActual columns:', Object.keys(data[0]).join(', '));
  console.log('Sample row:', JSON.stringify(data[0], null, 2));
}

const { error: isActiveErr } = await supabase.from('geographic_lines').select('is_active').limit(1);
console.log(`\nColumn "is_active": ${isActiveErr ? '❌ NOT FOUND' : '✅ EXISTS'}`);
const { error: statusErr } = await supabase.from('geographic_lines').select('status').limit(1);
console.log(`Column "status": ${statusErr ? '❌ NOT FOUND' : '✅ EXISTS'}`);
