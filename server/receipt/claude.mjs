// Claude Haiku path: public requests that carry the Claude consent version, plus the
// operator comparison path. Requests with the older Gemini consent never reach this file.
import Anthropic from '@anthropic-ai/sdk';
import { receiptSchema, receiptInstructions, receiptRequest, parseImage, validateDraft,
  checkTranslationRequest, translationInstructions } from './contract.mjs';

export const CLAUDE_MODEL = 'claude-haiku-5-5';
// Consent to send receipts to Anthropic. A Google (gemini-free-*) consent is never accepted for it.
export const CLAUDE_CONSENT_VERSION = 'claude-haiku-v1';

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

const translationSchema = { type: 'object', additionalProperties: false, required: ['names'],
  properties: { names: { type: 'array', items: { type: 'string' } } } };

// Only the ordered item names are sent; validateTranslation enforces count and length.
export function claudeTranslationBody(data) {
  const request = checkTranslationRequest(data);
  return {
    model: CLAUDE_MODEL, max_tokens: 16000, system: translationInstructions(request),
    messages: [{ role: 'user', content: JSON.stringify(request.names) }],
    output_config: { effort: 'low', format: { type: 'json_schema', schema: translationSchema } },
  };
}

export function readClaude(message, validate = validateDraft) {
  if (message?.stop_reason === 'refusal') throw new Error('refusal');
  if (message?.stop_reason !== 'end_turn' || !Array.isArray(message.content)) throw new Error('incomplete_draft');
  const output = message.content.filter(block => block.type === 'text').map(block => block.text).join('');
  if (!output || output.length > 250_000) throw new Error('invalid_draft');
  return validate(JSON.parse(output));
}

const reasons = { 400: 'INVALID_REQUEST', 401: 'UNAUTHENTICATED', 403: 'PERMISSION_DENIED', 404: 'NOT_FOUND',
  413: 'INVALID_REQUEST', 429: 'RESOURCE_EXHAUSTED', 529: 'UNAVAILABLE' };

// Returns { result, usage } or { status, providerStatus?, reason }. No retries or fallback, same as Gemini.
export async function askClaude(body, apiKey, signal, fetch, validate = validateDraft) {
  const client = new Anthropic({ apiKey, maxRetries: 0, fetch });
  let message;
  try {
    message = await client.messages.create(body, { signal });
  } catch (error) {
    if (!(error instanceof Anthropic.APIError) || typeof error.status !== 'number') throw error; // abort/network → caller's 502/504
    return { status: error.status === 429 ? 429 : 502, providerStatus: error.status,
      reason: reasons[error.status] ?? (error.status >= 500 ? 'UNAVAILABLE' : 'UPSTREAM_ERROR') };
  }
  // Token counts only (no receipt data) so the operator can see real cost.
  const usage = { input_tokens: message?.usage?.input_tokens, output_tokens: message?.usage?.output_tokens };
  try { return { result: readClaude(message, validate), usage }; }
  catch (error) { return { status: 502, reason: error.message === 'refusal' ? 'REFUSAL' : 'INVALID_DRAFT' }; }
}
