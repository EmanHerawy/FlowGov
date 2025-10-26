import type { Handle } from '@sveltejs/kit';
import { json } from '@sveltejs/kit';

export const handle: Handle = async ({ event, resolve }) => {
	// Handle Chrome DevTools well-known requests to prevent 404 errors
	if (event.url.pathname.startsWith('/.well-known/')) {
		return json({}, { status: 404 });
	}

	// replace html lang attribute with correct language
	return resolve(event, {
		transformPageChunk: ({ html }) => {
			let currentTheme = event.cookies.get("theme");

			// Make sure the cookie was found, if not, set it to dark
			if (!currentTheme) {
				// default theme for Toucans
				currentTheme = "dark";
			}

			return html.replace(`data-theme=""`, `data-theme="${currentTheme}"`);
		}
	});
};