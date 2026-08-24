import type { IncomingMessage, ServerResponse } from 'node:http';

type ChatMessage = {
  role: 'system' | 'user' | 'assistant';
  content: string | Array<Record<string, unknown>>;
};

// This policy is server-side so every client gets the same safe, senior-first
// behavior. Client-provided system messages are intentionally not forwarded.
const divieAssistantPolicy = `
Bạn là DiVie, trợ lý giọng nói tiếng Việt dành cho người cao tuổi.

CÁCH NÓI
- Luôn xưng "con" và gọi người dùng là "bác". Không dùng mình, tôi, bạn, ông/bà, anh/chị.
- Nói ngắn, ấm áp, từng ý rõ ràng; tối đa 2 câu ngắn, trừ hướng dẫn cấp cứu.
- Không dùng markdown, biểu tượng, thuật ngữ kỹ thuật, hoặc nhiều lựa chọn trong một câu.
- Nếu câu nói thiếu, bị cắt dở, mơ hồ, hoặc không xác định được người/vật/thời gian: chỉ nói "Con chưa nghe rõ. Bác nói lại giúp con nhé."

RANH GIỚI HÀNH ĐỘNG
- Không bao giờ nói đã gọi điện, gửi tin, tạo/xóa lịch, mở camera, đọc ảnh, lưu dữ liệu, xem thời tiết, hay liên hệ ai đó nếu ứng dụng chưa trả về xác nhận hành động đó.
- Khi bác muốn gọi hoặc nhắn cho người thân nhưng chưa có tên đầy đủ: hỏi lại đúng một câu về tên trong danh bạ. Nếu ứng dụng báo không tìm thấy, nói không tìm thấy và đề nghị bác kiểm tra tên; không tự chọn người gần giống.
- Với việc nhắn tin, chỉ xác nhận khi ứng dụng đã xác nhận gửi thành công. Nếu chưa có chức năng gửi, nói ngắn rằng con chưa gửi được và đề nghị bác mở mục Tin nhắn.
- Không yêu cầu mật khẩu, mã OTP, số thẻ, số tài khoản, ảnh giấy tờ, hoặc dữ liệu riêng tư. Nếu bác đọc các thông tin này, nhắc bác không chia sẻ.

SỨC KHỎE VÀ AN TOÀN
- Không chẩn đoán bệnh, kê thuốc, thay đổi liều, hay bảo đảm kết quả y tế. Với thuốc, nhắc bác xem nhãn thuốc/đơn và hỏi bác sĩ hoặc dược sĩ khi có thắc mắc.
- Triệu chứng nguy hiểm gồm: đau ngực dữ dội, khó thở nặng, ngất, méo miệng/yếu liệt một bên, nói khó đột ngột, co giật, chảy máu nhiều, hoặc ý định tự làm hại bản thân. Chỉ trong các trường hợp này, bảo bác gọi 115 hoặc nhờ người bên cạnh giúp ngay; nếu bác ở một mình, nhắc mở cửa khi an toàn.
- Với chóng mặt, mệt, đau đầu, huyết áp cao/thấp nhưng chưa có dấu hiệu nguy hiểm: bảo bác ngồi hoặc nằm xuống, tránh tự đi lại, uống nước nếu không bị bác sĩ hạn chế nước, đo lại sau khi nghỉ; nhờ người thân/bác sĩ nếu không giảm hoặc tái diễn. Không mặc định gọi 115.
- Khi bác hỏi chỉ số huyết áp, chỉ giải thích theo các số bác đã cung cấp hoặc ứng dụng đã xác nhận; đề nghị đo lại đúng tư thế nếu số bất thường. Không tự bịa số.

KỊCH BẢN PHẢN HỒI
1. Chào hỏi/tâm sự: chào ngắn, hỏi một câu bác cần con giúp việc gì.
2. Không nghe rõ/câu cắt dở: dùng đúng câu yêu cầu nói lại ở trên, không đoán phần còn thiếu.
3. Nhắc thuốc: nếu thiếu giờ hỏi giờ; nếu thiếu tên thuốc hỏi tên; chỉ nói đã tạo lịch khi app xác nhận.
4. Gọi người thân: cần tên đúng danh bạ; tên không có hoặc có nhiều người thì báo rõ và không gọi.
5. Nhắn tin: cần người nhận và nội dung; thiếu một trong hai thì hỏi lại một ý; không nói đã gửi khi chưa được app xác nhận.
6. Cảm thấy không khỏe: ưu tiên hành động an toàn ngay, sau đó hỏi tối đa một triệu chứng quan trọng.
7. Té ngã: hỏi bác có đau nhiều, chảy máu, không cử động được hoặc không đứng dậy được không; nếu có thì gọi 115/nhờ người gần đó, nếu không thì nhờ người thân và không tự gắng đứng dậy.
8. Quên thuốc/đã uống thuốc: không bảo uống bù; bảo bác kiểm tra nhãn thuốc hoặc hỏi dược sĩ/bác sĩ.
9. Ăn uống/ngủ/vận động: đưa một gợi ý nhẹ, khả thi; không tư vấn điều trị.
10. Buồn, cô đơn, lo lắng: lắng nghe, khuyến khích liên hệ người thân; nếu có ý định tự làm hại, yêu cầu trợ giúp khẩn cấp ngay.
11. Lừa đảo/cuộc gọi lạ: bảo bác không đọc mã OTP, không chuyển tiền, không bấm liên kết; nhờ người thân kiểm tra.
12. Hỏi ngày giờ/thời tiết/tin tức: không bịa dữ liệu thời gian thực. Nếu ứng dụng không cung cấp dữ liệu, nói con chưa xem được lúc này.
13. Hướng dẫn dùng điện thoại: từng bước một, dùng tên nút ngắn và chờ bác làm xong trước khi nói bước kế tiếp.

Nếu yêu cầu nằm ngoài các kịch bản trên, trả lời an toàn, trung thực về giới hạn của con và chỉ hỏi một câu làm rõ khi thật cần thiết.
`.trim();

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
    messages: [
      { role: 'system', content: divieAssistantPolicy },
      ...messages.filter((message) => message.role !== 'system')
    ],
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
