// Operator-only Claude Haiku comparison path. The public app keeps using Gemini.
import Anthropic from '@anthropic-ai/sdk';
import { receiptSchema, receiptInstructions, receiptRequest, parseImage, validateDraft } from './contract.mjs';

export const CLAUDE_MODEL = 'claude-haiku-5-5';

// Structured outputs reject length/count limits; validateDraft still enforces them.
const strip = value => Array.isArray(value) ? value.map(strip) : value && typeof value === 'object' ?
  Object.fromEntries(Object.entries(value).filter(([key]) => key !== 'maxItems' && key !== 'maxLength').map(([key, v]) => [key, strip(v)])) : value;
export const claudeSchema = strip(receiptSchema);

export function claudeBody(image) {
  const { type, data } = parseImage(image);
  return {
    model: CLAUDE_MODEL, max_tokens: 16000, system: receiptInstructions,
    messages: [{ role: 'user', content: [
      { type: 'image', source: { type: 'base64', media_type: `image/${type}`, data } },
      { type: 'text', text: receiptRequest },
    ] }],
    // Low effort: extraction needs little reasoning, and it keeps latency and cost down.
    output_config: { effort: 'low', format: { type: 'json_schema', schema: claudeSchema } },
  };
}

export function readClaude(message) {
  if (message?.stop_reason === 'refusal') throw new Error('refusal');
  if (message?.stop_reason !== 'end_turn' || !Array.isArray(message.content)) throw new Error('incomplete_draft');
  const output = message.content.filter(block => block.type === 'text').map(block => block.text).join('');
  if (!output || output.length > 250_000) throw new Error('invalid_draft');
  return validateDraft(JSON.parse(output));
}

const reasons = { 400: 'INVALID_REQUEST', 401: 'UNAUTHENTICATED', 403: 'PERMISSION_DENIED', 404: 'NOT_FOUND',
  413: 'INVALID_REQUEST', 429: 'RESOURCE_EXHAUSTED', 529: 'UNAVAILABLE' };

// Returns { draft } or { status, providerStatus?, reason }. No retries or fallback, same as Gemini.
export async function recognizeWithClaude(body, apiKey, signal, fetch) {
  const client = new Anthropic({ apiKey, maxRetries: 0, fetch });
  let message;
  try {
    message = await client.messages.create(body, { signal });
  } catch (error) {
    if (!(error instanceof Anthropic.APIError) || typeof error.status !== 'number') throw error; // abort/network → caller's 502/504
    return { status: error.status === 429 ? 429 : 502, providerStatus: error.status,
      reason: reasons[error.status] ?? (error.status >= 500 ? 'UNAVAILABLE' : 'UPSTREAM_ERROR') };
  }
  try { return { draft: readClaude(message) }; }
  catch (error) { return { status: 502, reason: error.message === 'refusal' ? 'REFUSAL' : 'INVALID_DRAFT' }; }
}
