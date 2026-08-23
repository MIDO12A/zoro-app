import { createClient } from '@supabase/supabase-js';
import WebSocket from 'ws';
import { config } from './index';

if (!config.supabase.url || !config.supabase.serviceKey) {
  throw new Error('SUPABASE_URL and SUPABASE_SERVICE_KEY must be set');
}

export const supabase = createClient(config.supabase.url, config.supabase.serviceKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false,
  },
  realtime: {
    transport: WebSocket,
  },
});
