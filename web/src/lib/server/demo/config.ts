/**
 * Demo showcase detection.
 *
 * Automatically enables showcase mode when DEMO_MODE=true or when deployed on
 * Vercel/Netlify without an explicit API_URL backend configured.
 */
export function isDemoMode(): boolean {
	if (process.env.DEMO_MODE === 'true') return true;
	if (process.env.DEMO_MODE === 'false') return false;
	return Boolean((process.env.VERCEL || process.env.NETLIFY) && !process.env.API_URL);
}
