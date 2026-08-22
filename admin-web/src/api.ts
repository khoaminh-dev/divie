const API_BASE = import.meta.env.VITE_ADMIN_API_URL ?? '';
const TOKEN_KEY = 'divie_admin_token';

export interface AdminApiState {
  token: string;
  connected: boolean;
  error?: string;
  me?: AdminMe;
  overview?: AdminOverview;
  users: AdminUser[];
  sessions: AdminVoiceSession[];
  conversations: AdminConversation[];
  health?: AdminHealth;
  auditLogs: AdminAuditLog[];
}

export interface ListMeta {
  limit: number;
  offset: number;
  count: number;
}

export interface PaginatedResponse<T> {
  items: T[];
  meta: ListMeta;
}

export interface AdminMe {
  userId: string;
  role: string;
  authMode: string;
  profile?: {
    full_name?: string | null;
    email?: string | null;
    phone_number?: string | null;
    is_verified?: boolean | null;
    last_seen?: string | null;
  } | null;
}

export interface AdminOverview {
  users?: {
    totalSample?: number;
    activeSample?: number;
  };
  voice?: {
    activeSessions?: number;
    sessionsSample?: number;
    completedTurns?: number;
    errorTurns?: number;
    averageTotalMs?: number | null;
  };
  moderation?: {
    restrictedUsers?: number;
    suspendedUsers?: number;
    pendingReviews?: number;
    flaggedReviews?: number;
  };
}

export interface AdminUser {
  id: string;
  full_name?: string | null;
  email?: string | null;
  phone_number?: string | null;
  is_verified?: boolean | null;
  last_seen?: string | null;
  created_at?: string | null;
  premium_status?: Array<{ tier?: string; daily_usage_count?: number }>;
  role?: string | null;
  moderation_status?: string | null;
  moderation_reason?: string | null;
  moderation_note?: string | null;
  moderation_expires_at?: string | null;
}

export interface AdminVoiceTurn {
  id?: string;
  turn_id?: string;
  status?: string;
  user_text?: string;
  assistant_text?: string;
  latency?: { totalMs?: number };
  error_code?: string | null;
  started_at?: string;
  completed_at?: string | null;
}

export interface AdminVoiceSession {
  id?: string;
  client_session_id?: string;
  user_id?: string | null;
  language?: string;
  voice_profile?: string | null;
  status?: string;
  started_at?: string;
  ended_at?: string | null;
  end_reason?: string | null;
  voice_turns?: AdminVoiceTurn[];
  event_count?: number;
  provider_call_count?: number;
  latest_event_at?: string | null;
  review_status?: string | null;
  review_note?: string | null;
}

export interface AdminConversation extends AdminVoiceTurn {
  voice_sessions?: {
    client_session_id?: string;
    language?: string;
    voice_profile?: string | null;
  };
  review_status?: string | null;
  review_note?: string | null;
}

export interface AdminHealth {
  ok?: boolean;
  service?: string;
  version?: string;
  uptimeSec?: number;
  latencyMs?: number;
  dependencies?: Record<string, unknown>;
}

export interface AdminAuditLog {
  id?: string;
  actor_id?: string | null;
  actor_role?: string | null;
  action?: string;
  target_type?: string | null;
  target_id?: string | null;
  created_at?: string;
}

export interface AdminUserDetail extends AdminUser {
  role?: string | null;
  subscription_end_date?: string | null;
  usage_daily?: Array<{
    usage_date?: string;
    voice_sessions?: number;
    voice_turns?: number;
    groq_calls?: number;
    tts_calls?: number;
    audio_chunks?: number;
    error_count?: number;
  }>;
  recent_voice_sessions?: Array<{
    id?: string;
    client_session_id?: string;
    status?: string;
    started_at?: string;
    ended_at?: string | null;
  }>;
}

export interface AdminConversationDetail extends AdminConversation {
  voice_session?: AdminVoiceSession | null;
  related_events?: Array<{
    id?: string;
    event_type?: string;
    payload?: Record<string, unknown>;
    created_at?: string;
  }>;
  provider_calls?: Array<{
    id?: string;
    provider?: string;
    operation?: string;
    status?: string;
    latency_ms?: number | null;
    error_message?: string | null;
    created_at?: string;
  }>;
}

export interface AdminHealthMeasurement {
  id: string;
  user_id?: string | null;
  user_label?: string | null;
  user_email?: string | null;
  systolic_bp?: number | null;
  diastolic_bp?: number | null;
  heart_rate?: number | null;
  source?: string | null;
  ai_anomaly_flag?: boolean | null;
  notes?: string | null;
  measured_at?: string | null;
  created_at?: string | null;
}

export interface AdminHealthMeasurementDetail extends AdminHealthMeasurement {
  user_phone?: string | null;
  time_series?: Array<{
    id?: string;
    metric_type?: string;
    value?: number | null;
    unit?: string | null;
    measured_at?: string | null;
  }>;
}

export interface AdminChatParticipant {
  profile_id?: string;
  label?: string;
  joined_at?: string | null;
}

export interface AdminChatRoom {
  id: string;
  type?: string | null;
  name?: string | null;
  last_message_text?: string | null;
  last_message_time?: string | null;
  created_at?: string | null;
  participant_count?: number;
  message_count?: number;
  participants?: AdminChatParticipant[];
}

export interface AdminChatMessage {
  id?: string;
  sender_id?: string | null;
  sender_label?: string | null;
  type?: string | null;
  content?: string | null;
  status?: string | null;
  is_read?: boolean | null;
  is_edited?: boolean | null;
  is_deleted?: boolean | null;
  file_url?: string | null;
  file_type?: string | null;
  reply_to_id?: string | null;
  created_at?: string | null;
}

export interface AdminChatRoomDetail extends AdminChatRoom {
  messages?: AdminChatMessage[];
}

export function readStoredToken(): string {
  return sessionStorage.getItem(TOKEN_KEY) ?? '';
}

export function storeToken(token: string): void {
  if (token.trim()) {
    sessionStorage.setItem(TOKEN_KEY, token.trim());
    return;
  }
  sessionStorage.removeItem(TOKEN_KEY);
}

export async function loadAdminData(token: string): Promise<Omit<AdminApiState, 'token'>> {
  if (!token) {
    return {
      connected: false,
      error: 'Admin API token is not configured in this browser session.',
      users: [],
      sessions: [],
      conversations: [],
      auditLogs: [],
    };
  }

  const [me, overview, users, sessions, conversations, health, auditLogs] = await Promise.all([
    get<AdminMe>('/api/admin/me', token),
    get<AdminOverview>('/api/admin/overview', token),
    get<{ items: AdminUser[] }>('/api/admin/users', token),
    get<{ items: AdminVoiceSession[] }>('/api/admin/voice/sessions', token),
    get<{ items: AdminConversation[] }>('/api/admin/conversations', token),
    get<AdminHealth>('/api/admin/health', token),
    get<{ items: AdminAuditLog[] }>('/api/admin/audit-logs', token).catch(() => ({ items: [] })),
  ]);

  return {
    connected: true,
    me,
    overview,
    users: users.items,
    sessions: sessions.items,
    conversations: conversations.items,
    health,
    auditLogs: auditLogs.items,
  };
}

export async function fetchUsers(token: string, params: {
  search?: string;
  plan?: string;
  verified?: 'all' | 'verified' | 'review';
  sort?: string;
  dir?: 'asc' | 'desc';
  limit?: number;
  offset?: number;
} = {}): Promise<PaginatedResponse<AdminUser>> {
  return await get<PaginatedResponse<AdminUser>>(`/api/admin/users${toQuery(params)}`, token);
}

export async function fetchUserDetail(token: string, userId: string): Promise<AdminUserDetail> {
  return await get<AdminUserDetail>(`/api/admin/users/${encodeURIComponent(userId)}`, token);
}

export async function updateUserVerification(token: string, userId: string, isVerified: boolean): Promise<{ ok: boolean; item: AdminUserDetail }> {
  return await requestJson(`/api/admin/users/${encodeURIComponent(userId)}/verification`, token, {
    method: 'PATCH',
    body: JSON.stringify({ is_verified: isVerified }),
  }) as Promise<{ ok: boolean; item: AdminUserDetail }>;
}

export async function updateUserPlan(token: string, userId: string, tier: string, subscriptionEndDate?: string | null): Promise<{ ok: boolean; item: AdminUserDetail }> {
  return await requestJson(`/api/admin/users/${encodeURIComponent(userId)}/plan`, token, {
    method: 'PATCH',
    body: JSON.stringify({ tier, subscription_end_date: subscriptionEndDate ?? null }),
  }) as Promise<{ ok: boolean; item: AdminUserDetail }>;
}

export async function updateUserRole(token: string, userId: string, role: 'admin' | 'user'): Promise<{ ok: boolean; item: AdminUserDetail }> {
  return await requestJson(`/api/admin/users/${encodeURIComponent(userId)}/role`, token, {
    method: 'PATCH',
    body: JSON.stringify({ role }),
  }) as Promise<{ ok: boolean; item: AdminUserDetail }>;
}

export async function updateUserModeration(token: string, userId: string, status: string, reason?: string | null, note?: string | null, expiresAt?: string | null): Promise<{ ok: boolean; item: AdminUserDetail }> {
  return await requestJson(`/api/admin/users/${encodeURIComponent(userId)}/moderation`, token, {
    method: 'PATCH',
    body: JSON.stringify({ status, reason: reason ?? null, note: note ?? null, expires_at: expiresAt ?? null }),
  }) as Promise<{ ok: boolean; item: AdminUserDetail }>;
}

export async function fetchVoiceSessions(token: string, params: {
  search?: string;
  status?: string;
  sort?: string;
  dir?: 'asc' | 'desc';
  limit?: number;
  offset?: number;
} = {}): Promise<PaginatedResponse<AdminVoiceSession>> {
  return await get<PaginatedResponse<AdminVoiceSession>>(`/api/admin/voice/sessions${toQuery(params)}`, token);
}

export async function fetchVoiceSessionDetail(token: string, sessionId: string): Promise<AdminVoiceSession> {
  return await get<AdminVoiceSession>(`/api/admin/voice/sessions/${encodeURIComponent(sessionId)}`, token);
}

export async function updateVoiceSessionReview(token: string, sessionId: string, status: string, note?: string): Promise<{ ok: boolean; item: AdminVoiceSession }> {
  return await requestJson(`/api/admin/voice/sessions/${encodeURIComponent(sessionId)}/review`, token, {
    method: 'PATCH',
    body: JSON.stringify({ status, note: note ?? '' }),
  }) as Promise<{ ok: boolean; item: AdminVoiceSession }>;
}

export async function fetchConversations(token: string, params: {
  search?: string;
  status?: string;
  sort?: string;
  dir?: 'asc' | 'desc';
  limit?: number;
  offset?: number;
} = {}): Promise<PaginatedResponse<AdminConversation>> {
  return await get<PaginatedResponse<AdminConversation>>(`/api/admin/conversations${toQuery(params)}`, token);
}

export async function fetchConversationDetail(token: string, conversationId: string): Promise<AdminConversationDetail> {
  return await get<AdminConversationDetail>(`/api/admin/conversations/${encodeURIComponent(conversationId)}`, token);
}

export async function updateConversationReview(token: string, conversationId: string, status: string, note?: string): Promise<{ ok: boolean; item: AdminConversationDetail }> {
  return await requestJson(`/api/admin/conversations/${encodeURIComponent(conversationId)}/review`, token, {
    method: 'PATCH',
    body: JSON.stringify({ status, note: note ?? '' }),
  }) as Promise<{ ok: boolean; item: AdminConversationDetail }>;
}

export async function fetchAuditLogs(token: string, params: {
  search?: string;
  sort?: string;
  dir?: 'asc' | 'desc';
  limit?: number;
  offset?: number;
} = {}): Promise<PaginatedResponse<AdminAuditLog>> {
  return await get<PaginatedResponse<AdminAuditLog>>(`/api/admin/audit-logs${toQuery(params)}`, token);
}

export async function fetchHealthMeasurements(token: string, params: {
  search?: string;
  anomaly?: 'all' | 'anomaly' | 'normal';
  sort?: string;
  dir?: 'asc' | 'desc';
  limit?: number;
  offset?: number;
} = {}): Promise<PaginatedResponse<AdminHealthMeasurement>> {
  return await get<PaginatedResponse<AdminHealthMeasurement>>(`/api/admin/health-measurements${toQuery(params)}`, token);
}

export async function fetchHealthMeasurementDetail(token: string, sessionId: string): Promise<AdminHealthMeasurementDetail> {
  return await get<AdminHealthMeasurementDetail>(`/api/admin/health-measurements/${encodeURIComponent(sessionId)}`, token);
}

export async function fetchChatRooms(token: string, params: {
  search?: string;
  type?: string;
  sort?: string;
  dir?: 'asc' | 'desc';
  limit?: number;
  offset?: number;
} = {}): Promise<PaginatedResponse<AdminChatRoom>> {
  return await get<PaginatedResponse<AdminChatRoom>>(`/api/admin/chat/rooms${toQuery(params)}`, token);
}

export async function fetchChatRoomDetail(token: string, roomId: string): Promise<AdminChatRoomDetail> {
  return await get<AdminChatRoomDetail>(`/api/admin/chat/rooms/${encodeURIComponent(roomId)}`, token);
}

export async function deleteChatMessage(token: string, messageId: string): Promise<{ ok: boolean; item: AdminChatMessage }> {
  return await requestJson(`/api/admin/chat/messages/${encodeURIComponent(messageId)}`, token, {
    method: 'DELETE',
  }) as Promise<{ ok: boolean; item: AdminChatMessage }>;
}

async function get<T>(path: string, token: string): Promise<T> {
  return await requestJson(path, token) as T;
}

async function requestJson(path: string, token: string, init: RequestInit = {}): Promise<unknown> {
  const response = await fetch(`${API_BASE}${path}`, {
    ...init,
    headers: {
      Authorization: `Bearer ${token}`,
      ...(init.body ? { 'Content-Type': 'application/json' } : {}),
      ...(init.headers ?? {}),
    },
  });

  if (!response.ok) {
    const body = await response.json().catch(() => ({ message: response.statusText })) as { message?: string };
    throw new Error(body.message ?? `Request failed with ${response.status}`);
  }

  return await response.json() as unknown;
}

function toQuery(params: Record<string, string | number | undefined>): string {
  const search = new URLSearchParams();
  for (const [key, value] of Object.entries(params)) {
    if (value !== undefined && value !== '') {
      search.set(key, String(value));
    }
  }
  const output = search.toString();
  return output ? `?${output}` : '';
}
