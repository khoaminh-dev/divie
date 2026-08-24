import { createClient } from '@supabase/supabase-js';

const fallbackUrl = 'https://urvauveiaudpqdattvxf.supabase.co';
const fallbackAnonKey = 'sb_publishable_20Zu3KRfuZgOdhCxP28bLw_G2YYXGgR';

export const supabase = createClient(
  import.meta.env.VITE_SUPABASE_URL ?? fallbackUrl,
  import.meta.env.VITE_SUPABASE_ANON_KEY ?? fallbackAnonKey,
  {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
      detectSessionInUrl: true,
    },
  },
);
