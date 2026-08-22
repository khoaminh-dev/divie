import { createClient } from '@supabase/supabase-js';

const fallbackUrl = 'https://api.divie.site';
const fallbackAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzgzNzg0MDIwLCJleHAiOjIwOTkxNDQwMjB9.fPxsaTp7x0vgiPmKGUESNRXCA1l83L5flD2KmHMRID8';

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
