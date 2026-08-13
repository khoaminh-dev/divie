import type { IncomingMessage, ServerResponse } from 'node:http';

type ChatMessage = {
  role: 'system' | 'user' | 'assistant';
  content: string | Array<Record<string, unknown>>;
};

const corsHeaders = {
  'Access-Control-Allow-Origin': process.env.CORS_ORIGIN ?? '*',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS'
};

function writeJson(res: ServerResponse, statusCode: number, body: unknown): void {
  res.writeHead(statusCode, { ...corsHeaders, 'Content-Type': 'application/json' });
  res.end(JSON.stringify(body));
}

async function readJson(req: IncomingMessage, maxBytes = 8_000_000): Promise<Record<string, unknown>> {
  const chunks: Buffer[] = [];
  let total = 0;
  for await (const chunk of req) {
    const buffer = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk);
    total += buffer.length;
    if (total > maxBytes) throw new Error('request_too_large');
    chunks.push(buffer);
  }
  const raw = Buffer.concat(chunks).toString('utf8').trim();
  if (!raw) return {};
  const parsed = JSON.parse(raw) as unknown;
  return parsed && typeof parsed === 'object' ? parsed as Record<string, unknown> : {};
}

function asMessages(value: unknown): ChatMessage[] | null {
  if (!Array.isArray(value)) return null;
  const messages = value.filter((item): item is ChatMessage => {
    if (!item || typeof item !== 'object') return false;
    const candidate = item as Record<string, unknown>;
    return (candidate.role === 'system' || candidate.role === 'user' || candidate.role === 'assistant')
      && (typeof candidate.content === 'string' || Array.isArray(candidate.content));
  });
  return messages.length > 0 ? messages : null;
}

function cleanAssistantText(value: string): string {
  return value.replace(/<think>[\s\S]*?<\/think>/gi, '').replace(/<think>[\s\S]*$/gi, '').trim();
}

async function callGroq(body: {
  messages: ChatMessage[];
  model?: string;
  temperature?: number;
  maxCompletionTokens?: number;
  responseFormat?: Record<string, unknown>;
}): Promise<{ ok: boolean; status: number; body: Record<string, unknown> }> {
  const apiKey = process.env.GROQ_API_KEY;
  if (!apiKey) return { ok: false, status: 503, body: { error: 'groq_not_configured' } };
  const model = body.model ?? process.env.GROQ_MODEL ?? 'llama-3.3-70b-versatile';
  const requestBody: Record<string, unknown> = {
    model,
    messages: body.messages,
    temperature: body.temperature ?? 0.4,
    max_completion_tokens: body.maxCompletionTokens ?? 512
  };
  if (model.includes('qwen')) {
    requestBody.reasoning_effort = 'none';
    requestBody.reasoning_format = 'hidden';
  }
  if (body.responseFormat) requestBody.response_format = body.responseFormat;
  const response = await fetch(process.env.GROQ_API_URL ?? 'https://api.groq.com/openai/v1/chat/completions', {
    method: 'POST',
    headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(requestBody)
  });
  const text = await response.text();
  let data: unknown = text;
  try { data = JSON.parse(text); } catch { /* preserve provider text */ }
  if (!response.ok) return { ok: false, status: response.status, body: { error: 'groq_request_failed', detail: data } };
  const rawContent = (data as { choices?: Array<{ message?: { content?: string } }> }).choices?.[0]?.message?.content;
  return { ok: true, status: 200, body: { success: true, content: typeof rawContent === 'string' ? cleanAssistantText(rawContent) : rawContent, raw: data } };
}

async function handleChat(req: IncomingMessage, res: ServerResponse): Promise<void> {
  if (req.method !== 'POST') return writeJson(res, 405, { error: 'method_not_allowed' });
  const body = await readJson(req, 1_000_000);
  const messages = asMessages(body.messages);
  if (!messages) return writeJson(res, 400, { error: 'missing_messages' });
  const result = await callGroq({
    messages,
    model: typeof body.model === 'string' ? body.model : undefined,
    temperature: typeof body.temperature === 'number' ? body.temperature : undefined,
    maxCompletionTokens: typeof body.maxCompletionTokens === 'number' ? body.maxCompletionTokens : undefined,
    responseFormat: body.responseFormat && typeof body.responseFormat === 'object' ? body.responseFormat as Record<string, unknown> : undefined
  });
  writeJson(res, result.status, result.body);
}

async function handleVision(req: IncomingMessage, res: ServerResponse): Promise<void> {
  if (req.method !== 'POST') return writeJson(res, 405, { error: 'method_not_allowed' });
  const body = await readJson(req);
  const imageBase64 = typeof body.imageBase64 === 'string' ? body.imageBase64.trim() : '';
  if (!imageBase64) return writeJson(res, 400, { error: 'missing_image' });
  const prompt = typeof body.prompt === 'string' && body.prompt.trim() !== ''
    ? body.prompt.trim()
    : 'Hãy nhận diện vật hoặc món đồ trong ảnh. Trả lời tiếng Việt thật ngắn, nêu tên đồ vật, màu sắc, trạng thái đáng chú ý, và cảnh báo an toàn nếu có.';
  const result = await callGroq({
    model: process.env.GROQ_VISION_MODEL ?? 'qwen/qwen3.6-27b',
    temperature: 0.1,
    maxCompletionTokens: 260,
    messages: [
      { role: 'system', content: 'Bạn là DiVie Vision, trợ lý nhận diện đồ vật cho người lớn tuổi. Trả lời tiếng Việt ngắn, rõ, không phóng đoán quá mức. Không hiển thị suy luận, không dùng markdown.' },
      { role: 'user', content: [{ type: 'text', text: prompt }, { type: 'image_url', image_url: { url: `data:image/jpeg;base64,${imageBase64}` } }] }
    ]
  });
  const content = (result.body as { content?: string }).content;
  if (result.ok && content) return writeJson(res, 200, { success: true, data: { description: content.trim() } });
  writeJson(res, result.status, result.body);
}

function parseJsonObject(value: string): Record<string, unknown> | null {
  const cleaned = value.replace(/^```(?:json)?/i, '').replace(/```$/i, '').trim();
  try {
    const parsed = JSON.parse(cleaned) as unknown;
    return parsed && typeof parsed === 'object' ? parsed as Record<string, unknown> : null;
  } catch {
    const match = cleaned.match(/\{[\s\S]*\}/);
    if (!match) return null;
    try { return JSON.parse(match[0]) as Record<string, unknown>; } catch { return null; }
  }
}

function numberInRange(value: unknown, min: number, max: number): number | null {
  const parsed = typeof value === 'number' ? value : Number(value);
  return Number.isFinite(parsed) && parsed >= min && parsed <= max ? Math.round(parsed) : null;
}

async function handleBloodPressureOcr(req: IncomingMessage, res: ServerResponse): Promise<void> {
  if (req.method !== 'POST') return writeJson(res, 405, { error: 'method_not_allowed' });
  const body = await readJson(req, 8_000_000);
  const imageBase64 = typeof body.imageBase64 === 'string' ? body.imageBase64.trim() : '';
  if (!imageBase64) return writeJson(res, 400, { error: 'missing_image', message: 'Thiếu ảnh cần đọc.' });
  if (imageBase64.length > 6_000_000) return writeJson(res, 413, { error: 'image_too_large', message: 'Ảnh quá lớn.' });
  const mimeType = typeof body.mimeType === 'string' && /^image\/(jpeg|png|webp)$/i.test(body.mimeType) ? body.mimeType : 'image/jpeg';
  const result = await callGroq({
    model: process.env.GROQ_VISION_MODEL ?? 'qwen/qwen3.6-27b',
    temperature: 0,
    maxCompletionTokens: 220,
    responseFormat: { type: 'json_object' },
    messages: [
      { role: 'system', content: 'Bạn là OCR máy đo huyết áp. Đọc đúng số hiển thị, không suy đoán. Chỉ trả JSON hợp lệ, không markdown, theo schema: {"systolic":number|null,"diastolic":number|null,"pulse":number|null,"confidence":number,"rawText":"string"}. confidence từ 0 đến 1.' },
      { role: 'user', content: [{ type: 'text', text: 'Đọc máy đo huyết áp trong ảnh. Nếu ảnh không rõ, trả null cho giá trị không chắc.' }, { type: 'image_url', image_url: { url: `data:${mimeType};base64,${imageBase64}` } }] }
    ]
  });
  if (!result.ok) return writeJson(res, result.status, result.body);
  const raw = (result.body as { content?: string }).content ?? '';
  const parsed = parseJsonObject(raw);
  if (!parsed) return writeJson(res, 422, { error: 'ocr_unreadable', message: 'Không đọc được số từ ảnh.', rawText: raw });
  const measurement = {
    systolic: numberInRange(parsed.systolic, 50, 260),
    diastolic: numberInRange(parsed.diastolic, 30, 180),
    pulse: numberInRange(parsed.pulse, 25, 240),
    confidence: Math.max(0, Math.min(1, Number(parsed.confidence) || 0)),
    rawText: typeof parsed.rawText === 'string' ? parsed.rawText.slice(0, 500) : raw.slice(0, 500)
  };
  if (measurement.systolic === null && measurement.diastolic === null && measurement.pulse === null) {
    return writeJson(res, 422, { error: 'ocr_unreadable', message: 'Không tìm thấy chỉ số huyết áp rõ ràng.', measurement });
  }
  writeJson(res, 200, { ok: true, measurement, requiresConfirmation: true });
}

export default async function handler(req: IncomingMessage, res: ServerResponse): Promise<void> {
  if (req.method === 'OPTIONS') return writeJson(res, 204, {});
  const path = new URL(req.url ?? '/', 'http://localhost').pathname;
  try {
    if (path === '/health' || path === '/api/health') return writeJson(res, 200, { ok: true, service: 'divie-voice-backend', runtime: 'vercel-serverless', groq: process.env.GROQ_API_KEY ? 'configured' : 'missing', visionModel: process.env.GROQ_VISION_MODEL ?? 'qwen/qwen3.6-27b', ts: Date.now() });
    if (path === '/ready') return writeJson(res, 200, { ok: true });
    if (path === '/api/ai/chat' || path === '/api/ai/intent') return handleChat(req, res);
    if (path === '/api/vision/describe') return handleVision(req, res);
    if (path === '/ocr/blood-pressure' || path === '/api/ocr/blood-pressure') return handleBloodPressureOcr(req, res);
    if (path === '/openai/realtime/client-secret') return writeJson(res, 503, { error: 'openai_realtime_disabled', message: 'DiVie is configured for Groq text + local TTS.' });
    return writeJson(res, 404, { error: 'not_found' });
  } catch (error) {
    return writeJson(res, error instanceof Error && error.message === 'request_too_large' ? 413 : 500, { error: error instanceof Error && error.message === 'request_too_large' ? 'request_too_large' : 'internal_error', message: error instanceof Error ? error.message : 'Unexpected error' });
  }
}
