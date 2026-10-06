// Only the public HTTPS server address goes into the website, never credentials.
import { readFile, writeFile } from 'node:fs/promises';
const defaults = JSON.parse(await readFile(new URL('../web/receipt-config.json', import.meta.url), 'utf8'));
const value = process.env.RECEIPT_SERVER_URL?.trim() || defaults.serverUrl || null;
const provider = process.env.RECEIPT_PROVIDER?.trim() || defaults.provider || 'gemini';
if (!['gemini', 'openai'].includes(provider)) throw new Error('Unknown receipt provider.');
if (value) {
  const url = new URL(value);
  if (url.protocol !== 'https:' || url.username || url.password || url.search || url.hash || url.pathname !== '/') throw new Error('RECEIPT_SERVER_URL must be an HTTPS origin without credentials.');
}
await writeFile(new URL('../build/web/receipt-config.json', import.meta.url), JSON.stringify({ serverUrl: value, provider }));
