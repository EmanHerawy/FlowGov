import { supabase } from '$lib/supabaseClient';

export async function fetchFlowPrice() {
	try {
		const { data, error } = await supabase.from('price_api').select('price').eq('id', 1);
		if (error || !data || data.length === 0) {
			console.error('Error fetching Flow price:', error);
			return 0; // Return 0 as fallback
		}
		return data[0].price;
	} catch (error) {
		console.error('Error fetching Flow price:', error);
		return 0; // Return 0 as fallback
	}
}
