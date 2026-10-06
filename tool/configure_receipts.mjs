// Only the public HTTPS server address goes into the website, never credentials.
import { writeFile } from 'node:fs/promises';
const value = process.env.RECEIPT_SERVER_URL?.trim() || null;
if (value) {
  const url = new URL(value);
  if (url.protocol !== 'https:' || url.username || url.password || url.search || url.hash || url.pathname !== '/') throw new Error('RECEIPT_SERVER_URL must be an HTTPS origin without credentials.');
}
await writeFile(new URL('../build/web/receipt-config.json', import.meta.url), JSON.stringify({ serverUrl: value }));
