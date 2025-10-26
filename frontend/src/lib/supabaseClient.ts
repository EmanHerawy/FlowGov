import { createClient } from '@supabase/supabase-js';
import { env } from '$env/dynamic/public';
import type { Database } from '../../supabase/database.types';

export const supabase = createClient<Database>(
	env.PUBLIC_SUPABASE_URL,
	env.PUBLIC_SUPABASE_ANON_KEY,
	{
		auth: {
			storageKey: 'flowgov-supabase-auth',
			autoRefreshToken: true,
			persistSession: true
		}
	}
);
export const botSupabase = createClient(
	env.PUBLIC_BOT_SUPABASE_URL,
	env.PUBLIC_BOT_SUPABASE_ANON_KEY,
	{
		auth: {
			storageKey: 'flowgov-bot-supabase-auth',
			autoRefreshToken: true,
			persistSession: true
		}
	}
);
