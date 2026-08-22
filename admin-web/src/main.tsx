import { StrictMode, useEffect, useMemo, useState, type ReactNode } from 'react';
import { createRoot } from 'react-dom/client';
import type { Session } from '@supabase/supabase-js';
import {
  Activity,
  AlertTriangle,
  Bell,
  CheckCircle2,
  ChevronDown,
  Clock3,
  FileText,
  Gauge,
  Headphones,
  HeartPulse,
  LayoutDashboard,
  LoaderCircle,
  LockKeyhole,
  LogOut,
  Menu,
  MessageSquare,
  Mic2,
  MoreHorizontal,
  Search,
  Trash2,
  ServerCog,
  Settings,
  ShieldCheck,
  SlidersHorizontal,
  Sparkles,
  UserRoundPlus,
  Users,
  X,
} from 'lucide-react';
import './styles.css';
import {
  deleteChatMessage,
  fetchAuditLogs,
  fetchChatRoomDetail,
  fetchChatRooms,
  fetchConversationDetail,
  fetchConversations,
  fetchHealthMeasurementDetail,
  fetchHealthMeasurements,
  fetchUserDetail,
  fetchUsers,
  fetchVoiceSessionDetail,
  fetchVoiceSessions,
  loadAdminData,
  storeToken,
  updateUserModeration,
  updateConversationReview,
  updateUserPlan,
  updateUserRole,
  updateUserVerification,
  updateVoiceSessionReview,
  type AdminApiState,
  type AdminAuditLog,
  type AdminChatRoom,
  type AdminChatRoomDetail,
  type AdminConversation,
  type AdminConversationDetail,
  type AdminHealthMeasurement,
  type AdminHealthMeasurementDetail,
  type AdminUser,
  type AdminUserDetail,
  type AdminVoiceSession,
  type PaginatedResponse,
  readStoredToken,
} from './api';
import { supabase } from './supabase';
import divieLogo from './assets/logo-divie.png';

type Page = 'Dashboard' | 'Users' | 'Voice Operations' | 'Conversations' | 'Health Records' | 'Chat' | 'System Health' | 'Audit Logs';
type AuthStatus = 'loading' | 'signed-out' | 'signed-in';
type RemoteState<T> = {
  loading: boolean;
  error?: string;
  items: T[];
  count: number;
  limit: number;
  offset: number;
};

const PAGE_SIZE = 20;

const nav: { label: Page; icon: typeof LayoutDashboard }[] = [
  { label: 'Dashboard', icon: LayoutDashboard },
  { label: 'Users', icon: Users },
  { label: 'Voice Operations', icon: Mic2 },
  { label: 'Conversations', icon: FileText },
  { label: 'Health Records', icon: HeartPulse },
  { label: 'Chat', icon: MessageSquare },
  { label: 'System Health', icon: Activity },
  { label: 'Audit Logs', icon: ShieldCheck },
];

function App() {
  const [page, setPage] = useState<Page>('Dashboard');
  const [mobile, setMobile] = useState(false);
  const [authStatus, setAuthStatus] = useState<AuthStatus>('loading');
  const [authError, setAuthError] = useState<string>();
  const [authBusy, setAuthBusy] = useState(false);
  const [session, setSession] = useState<Session | null>(null);
  const [hasLoaded, setHasLoaded] = useState(false);
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [apiState, setApiState] = useState<AdminApiState>({
    token: readStoredToken(),
    connected: false,
    users: [],
    sessions: [],
    conversations: [],
    auditLogs: [],
  });

  const adminName = apiState.me?.profile?.full_name
    || session?.user.user_metadata.full_name
    || session?.user.email
    || 'Admin';
  const adminRole = apiState.me?.role ?? 'viewer';
  const adminInitials = initials(adminName);

  const refreshDashboard = async (token = session?.access_token ?? apiState.token) => {
    setIsRefreshing(true);
    if (!token) {
      setApiState((current) => ({
        ...current,
        token: '',
        connected: false,
        error: 'Bạn cần đăng nhập bằng tài khoản admin để mở dữ liệu hệ thống.',
        me: undefined,
        users: [],
        sessions: [],
        conversations: [],
        auditLogs: [],
      }));
      setHasLoaded(true);
      setIsRefreshing(false);
      return;
    }

    try {
      const data = await loadAdminData(token);
      storeToken(token);
      setApiState({ token, ...data });
      setAuthError(undefined);
      setAuthStatus('signed-in');
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Cannot connect to admin API.';
      setApiState((current) => ({ ...current, token, connected: false, error: message }));
      setAuthError(message);
    } finally {
      setHasLoaded(true);
      setIsRefreshing(false);
    }
  };

  useEffect(() => {
    let mounted = true;

    const bootstrap = async () => {
      const { data } = await supabase.auth.getSession();
      if (!mounted) {
        return;
      }

      setSession(data.session ?? null);
      if (data.session?.access_token) {
        await refreshDashboard(data.session.access_token);
      } else {
        setAuthStatus('signed-out');
        await refreshDashboard(readStoredToken());
      }
    };

    void bootstrap();

    const { data: subscription } = supabase.auth.onAuthStateChange((_event, nextSession) => {
      setSession(nextSession);
      if (nextSession?.access_token) {
        void refreshDashboard(nextSession.access_token);
      } else {
        const storedToken = readStoredToken();
        if (storedToken) {
          void refreshDashboard(storedToken);
          return;
        }
        setApiState((current) => ({ ...current, token: '', connected: false, me: undefined }));
        setAuthStatus('signed-out');
      }
    });

    return () => {
      mounted = false;
      subscription.subscription.unsubscribe();
    };
  }, []);

  const signIn = async (email: string, password: string) => {
    setAuthBusy(true);
    setAuthError(undefined);
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    setAuthBusy(false);
    if (error) {
      setAuthError(error.message);
      return;
    }
    setAuthStatus('signed-in');
  };

  const signInWithToken = async (token: string) => {
    setAuthBusy(true);
    setAuthError(undefined);
    await refreshDashboard(token);
    setAuthBusy(false);
  };

  const signOut = async () => {
    setAuthBusy(true);
    await supabase.auth.signOut();
    storeToken('');
    setAuthBusy(false);
    setAuthStatus('signed-out');
  };

  return (
    <div className="app">
      <aside className={mobile ? 'sidebar open' : 'sidebar'}>
        <div className="brand">
          <div className="brandMark">
            <img src={divieLogo} alt="DiVie" />
          </div>
          <div>
            <strong>DiVie</strong>
            <span>Admin console</span>
          </div>
          <button className="iconOnly close" onClick={() => setMobile(false)} aria-label="Close menu">
            <X size={18} />
          </button>
        </div>

        <div className="navTitle">OPERATIONS</div>
        {nav.map(({ label, icon: Icon }) => (
          <button aria-label={label} className={page === label ? 'navItem active' : 'navItem'} onClick={() => { setPage(label); setMobile(false); }} key={label}>
            <Icon size={18} />
            <span>{label}</span>
          </button>
        ))}

        <div className="sideStatus">
          <span><i /> {apiState.connected ? 'Live data' : authStatus === 'loading' ? 'Checking session' : 'Sign in required'}</span>
          <strong>admin.divie.site</strong>
          <small>{apiState.connected ? 'Admin API connected' : 'Supabase admin session'}</small>
        </div>

        <div className="sideBottom">
          <button className="navItem"><Settings size={18} /><span>Settings</span></button>
          <button className="navItem" onClick={() => void signOut()} disabled={authBusy}><LogOut size={18} /><span>Sign out</span></button>
          <div className="adminMini">
            <div className="avatar">{adminInitials}</div>
            <div>
              <strong>{trim(adminName, 24)}</strong>
              <span>{adminRole}</span>
            </div>
            <ChevronDown size={15} />
          </div>
        </div>
      </aside>

      <main className="main">
        <header>
          <button className="iconOnly menu" onClick={() => setMobile(true)} aria-label="Open menu"><Menu /></button>
          <div className="titleBlock">
            <p className="eyebrow">DiVie / {page}</p>
            <h1>{page}</h1>
          </div>
          <div className="headerActions">
            <button className="ghostButton"><SlidersHorizontal size={16} />Filters</button>
            <button className="iconButton" aria-label="Notifications"><Bell size={18} /><i /></button>
            <div className="headerUser"><div className="avatar">{adminInitials}</div><span>{trim(adminName, 18)}</span><ChevronDown size={15} /></div>
          </div>
        </header>

        <ApiConnection
          state={apiState}
          authStatus={authStatus}
          authBusy={authBusy}
          authError={authError}
          session={session}
          isRefreshing={isRefreshing}
          onRefresh={() => void refreshDashboard()}
          onSignIn={signIn}
          onTokenSignIn={signInWithToken}
          onSignOut={signOut}
        />

        {page === 'Dashboard' && <Dashboard apiState={apiState} isRefreshing={isRefreshing} setPage={setPage} />}
        {page === 'Users' && <UsersPage token={apiState.token} connected={apiState.connected} onChanged={() => void refreshDashboard()} />}
        {page === 'Voice Operations' && <VoiceOperationsPage token={apiState.token} connected={apiState.connected} />}
        {page === 'Conversations' && <ConversationsPage token={apiState.token} connected={apiState.connected} />}
        {page === 'Health Records' && <HealthRecordsPage token={apiState.token} connected={apiState.connected} />}
        {page === 'Chat' && <ChatPage token={apiState.token} connected={apiState.connected} />}
        {page === 'System Health' && <HealthPage apiState={apiState} hasLoaded={hasLoaded} />}
        {page === 'Audit Logs' && <AuditPage token={apiState.token} connected={apiState.connected} />}
      </main>
    </div>
  );
}

function ApiConnection({
  state,
  authStatus,
  authBusy,
  authError,
  session,
  isRefreshing,
  onRefresh,
  onSignIn,
  onTokenSignIn,
  onSignOut,
}: {
  state: AdminApiState;
  authStatus: AuthStatus;
  authBusy: boolean;
  authError?: string;
  session: Session | null;
  isRefreshing: boolean;
  onRefresh: () => void;
  onSignIn: (email: string, password: string) => Promise<void>;
  onTokenSignIn: (token: string) => Promise<void>;
  onSignOut: () => Promise<void>;
}) {
  const [email, setEmail] = useState(session?.user.email ?? '');
  const [password, setPassword] = useState('');
  const [adminToken, setAdminToken] = useState('');

  useEffect(() => {
    setEmail(session?.user.email ?? '');
  }, [session?.user.email]);

  if (authStatus === 'loading') {
    return <section className="apiBar"><div><strong>Checking admin session…</strong><span>Đang khôi phục phiên đăng nhập và đồng bộ dữ liệu hệ thống.</span></div></section>;
  }

  if (authStatus !== 'signed-in') {
    return (
      <section className="apiBar authCard">
        <div>
          <strong>Đăng nhập admin để mở bảng điều khiển thật</strong>
          <span>{authError ?? state.error ?? 'Dùng đúng tài khoản đã được cấp quyền trong hệ thống DiVie admin members.'}</span>
        </div>
        <form className="apiControls authForm" onSubmit={(event) => { event.preventDefault(); void onSignIn(email.trim(), password); }}>
          <input value={email} onChange={(event) => setEmail(event.target.value)} placeholder="Email admin" type="email" autoComplete="email" />
          <input value={password} onChange={(event) => setPassword(event.target.value)} placeholder="Mật khẩu" type="password" autoComplete="current-password" />
          <button className="primary" type="submit" disabled={authBusy || !email.trim() || !password}>{authBusy ? 'Đang đăng nhập…' : 'Đăng nhập'}</button>
        </form>
        <form className="apiControls authForm" onSubmit={(event) => { event.preventDefault(); void onTokenSignIn(adminToken.trim()); }}>
          <input value={adminToken} onChange={(event) => setAdminToken(event.target.value)} placeholder="Admin API token" type="password" autoComplete="off" />
          <button className="ghostButton" type="submit" disabled={authBusy || !adminToken.trim()}>{authBusy ? 'Đang kiểm tra…' : 'Dùng token'}</button>
        </form>
      </section>
    );
  }

  return (
    <section className={state.connected ? 'apiBar connected' : 'apiBar'}>
      <div>
        <strong>{state.connected ? 'Đã kết nối DiVie Admin API' : 'Đã đăng nhập nhưng chưa đọc được dữ liệu'}</strong>
        <span>{state.connected ? `Đang dùng phiên của ${session?.user.email ?? 'admin'}.` : state.error ?? 'Phiên đã có, đang chờ làm mới dữ liệu.'}</span>
      </div>
      <div className="apiControls">
        <button className="ghostButton" onClick={onRefresh} disabled={isRefreshing}>
          {isRefreshing ? <LoaderCircle size={14} className="spin" /> : null}
          Refresh
        </button>
        <button className="ghostButton" onClick={() => void onSignOut()}>Đăng xuất</button>
      </div>
    </section>
  );
}

function Dashboard({ apiState, isRefreshing, setPage }: { apiState: AdminApiState; isRefreshing: boolean; setPage: (page: Page) => void }) {
  const stats = buildDashboardStats(apiState);
  const attentionItems = buildAttentionItems(apiState);

  return (
    <div className="content">
      <section className="opsHeader">
        <div>
          <span className={`liveBadge ${apiState.connected ? '' : 'warningText'}`}><i /> {apiState.connected ? 'Realtime control plane connected' : 'Not connected to production data'}</span>
          <p>{apiState.connected ? 'Dữ liệu trên màn hình đang lấy trực tiếp từ hệ thống vận hành.' : apiState.error ?? 'Đăng nhập để mở dữ liệu thật.'}</p>
        </div>
        <div className="quickActions">
          <button className="primary" onClick={() => setPage('System Health')}>
            {isRefreshing ? <LoaderCircle size={16} className="spin" /> : <Sparkles size={16} />}
            Kiểm tra hệ thống
          </button>
        </div>
      </section>

      <div className="metrics">
        <Metric icon={Users} label="Người dùng" value={formatNumber(stats.userCount)} trend={`${formatNumber(stats.activeUsers)} đang có tín hiệu hoạt động`} />
        <Metric icon={Headphones} label="Phiên voice" value={formatNumber(stats.sessionCount)} trend={`${formatNumber(stats.activeSessions)} đang mở`} />
        <Metric icon={Clock3} label="Độ trễ trung bình" value={stats.avgResponse} trend={stats.avgResponseMeta} good={stats.avgResponse !== '—'} />
        <Metric icon={AlertTriangle} label="Turn lỗi" value={String(stats.errorTurns)} trend={stats.errorTurns ? `${stats.pendingReviews} mục đang chờ review` : 'Chưa ghi nhận lỗi'} warning={stats.errorTurns > 0 || stats.pendingReviews > 0} />
      </div>

      <div className="dashboardGrid">
        <section className="panel chartPanel">
          <div className="panelHead">
            <div><h2>Product progress</h2><p>Admin console hiện đã có read + detail + action thật</p></div>
          </div>
          <div className="stackList">
            <KeyValue label="Users list" value="server filter + paging" />
            <KeyValue label="User detail" value="live panel + verify action" />
            <KeyValue label="Voice session detail" value="live panel" />
            <KeyValue label="Conversation detail" value="events + provider calls" />
            <KeyValue label="Audit logs" value="server search + paging" />
          </div>
        </section>

        <div className="rightRail">
          <section className="panel compactPanel">
            <div className="panelHead">
              <div><h2>Operational snapshot</h2><p>Những gì backend đang thực sự trả về</p></div>
            </div>
            <div className="stackList">
              <KeyValue label="Admin role" value={apiState.me?.role ?? '—'} />
              <KeyValue label="Auth mode" value={apiState.me?.authMode ?? '—'} />
              <KeyValue label="Audit records loaded" value={formatNumber(apiState.auditLogs.length)} />
              <KeyValue label="Recent voice snapshot" value={formatNumber(apiState.sessions.length)} />
              <KeyValue label="Suspended users" value={formatNumber(apiState.overview?.moderation?.suspendedUsers ?? 0)} />
              <KeyValue label="Flagged reviews" value={formatNumber(apiState.overview?.moderation?.flaggedReviews ?? 0)} />
            </div>
          </section>

          <section className="panel compactPanel">
            <div className="panelHead">
              <div><h2>Attention</h2><p>Danh sách sinh từ dữ liệu thật</p></div>
              <span className="count">{attentionItems.length}</span>
            </div>
            {attentionItems.length > 0 ? (
              <div className="issueList">
                {attentionItems.map((item) => <Issue key={item.title} tone={item.tone} title={item.title} meta={item.meta} />)}
              </div>
            ) : (
              <EmptyState icon={CheckCircle2} title="Không có cảnh báo" body="Hiện chưa thấy lỗi voice, sự cố health hay bất thường đáng chú ý từ dữ liệu đang tải." compact />
            )}
          </section>
        </div>
      </div>
    </div>
  );
}

function UsersPage({ token, connected, onChanged }: { token: string; connected: boolean; onChanged: () => void }) {
  const [query, setQuery] = useState('');
  const [plan, setPlan] = useState<'all' | 'premium' | 'family' | 'free'>('all');
  const [verified, setVerified] = useState<'all' | 'verified' | 'review'>('all');
  const [sort, setSort] = useState<'created_at' | 'last_seen' | 'full_name'>('created_at');
  const [sortDir, setSortDir] = useState<'asc' | 'desc'>('desc');
  const [state, setState] = useState<RemoteState<AdminUser>>(emptyRemoteState());
  const [selectedUserId, setSelectedUserId] = useState<string>();
  const [detail, setDetail] = useState<Loadable<AdminUserDetail>>({ loading: false });
  const [actionBusy, setActionBusy] = useState(false);
  const [planDraft, setPlanDraft] = useState('free');
  const [roleDraft, setRoleDraft] = useState<'admin' | 'user'>('user');
  const [subscriptionDraft, setSubscriptionDraft] = useState('');
  const [moderationStatus, setModerationStatus] = useState('active');
  const [moderationReason, setModerationReason] = useState('');
  const [moderationNote, setModerationNote] = useState('');
  const [moderationUntil, setModerationUntil] = useState('');

  useEffect(() => {
    if (!connected || !token) {
      return;
    }
    void loadPage(0);
  }, [token, connected, query, plan, verified, sort, sortDir]);

  useEffect(() => {
    if (!selectedUserId || !token) {
      setDetail({ loading: false });
      return;
    }
    void loadDetail(selectedUserId);
  }, [selectedUserId, token]);

  const loadPage = async (offset = state.offset) => {
    setState((current) => ({ ...current, loading: true, error: undefined }));
    try {
      const response = await fetchUsers(token, {
        search: query || undefined,
        plan: plan === 'all' ? undefined : plan,
        verified,
        sort,
        dir: sortDir,
        limit: PAGE_SIZE,
        offset,
      });
      setState(toRemoteState(response));
    } catch (error) {
      setState((current) => ({ ...current, loading: false, error: asMessage(error) }));
    }
  };

  const loadDetail = async (userId: string) => {
    setDetail({ loading: true });
    try {
      const item = await fetchUserDetail(token, userId);
      setPlanDraft(item.premium_status?.[0]?.tier ?? 'free');
      setRoleDraft((item.role ?? 'user').toLowerCase() === 'admin' ? 'admin' : 'user');
      setSubscriptionDraft(item.subscription_end_date ? item.subscription_end_date.slice(0, 10) : '');
      setModerationStatus(item.moderation_status ?? 'active');
      setModerationReason(item.moderation_reason ?? '');
      setModerationNote(item.moderation_note ?? '');
      setModerationUntil(item.moderation_expires_at ? item.moderation_expires_at.slice(0, 10) : '');
      setDetail({ loading: false, item });
    } catch (error) {
      setDetail({ loading: false, error: asMessage(error) });
    }
  };

  const toggleVerification = async () => {
    if (!selectedUserId || !detail.item) {
      return;
    }
    setActionBusy(true);
    try {
      const next = !detail.item.is_verified;
      const response = await updateUserVerification(token, selectedUserId, next);
      setDetail({ loading: false, item: { ...detail.item, ...response.item, is_verified: next } });
      await loadPage(state.offset);
      onChanged();
    } catch (error) {
      setDetail((current) => ({ ...current, error: asMessage(error) }));
    } finally {
      setActionBusy(false);
    }
  };

  const savePlan = async () => {
    if (!selectedUserId) return;
    setActionBusy(true);
    try {
      const response = await updateUserPlan(token, selectedUserId, planDraft, subscriptionDraft ? new Date(subscriptionDraft).toISOString() : null);
      setDetail({ loading: false, item: response.item });
      await loadPage(state.offset);
      onChanged();
    } catch (error) {
      setDetail((current) => ({ ...current, error: asMessage(error) }));
    } finally {
      setActionBusy(false);
    }
  };

  const saveRole = async () => {
    if (!selectedUserId) return;
    setActionBusy(true);
    try {
      const response = await updateUserRole(token, selectedUserId, roleDraft);
      setDetail({ loading: false, item: response.item });
      await loadPage(state.offset);
      onChanged();
    } catch (error) {
      setDetail((current) => ({ ...current, error: asMessage(error) }));
    } finally {
      setActionBusy(false);
    }
  };

  const saveModeration = async () => {
    if (!selectedUserId) return;
    setActionBusy(true);
    try {
      const response = await updateUserModeration(
        token,
        selectedUserId,
        moderationStatus,
        moderationReason,
        moderationNote,
        moderationUntil ? new Date(moderationUntil).toISOString() : null,
      );
      setDetail({ loading: false, item: response.item });
      await loadPage(state.offset);
      onChanged();
    } catch (error) {
      setDetail((current) => ({ ...current, error: asMessage(error) }));
    } finally {
      setActionBusy(false);
    }
  };

  const rows = state.items.map((user) => {
    const name = user.full_name || user.email || user.phone_number || user.id;
    const userPlan = (user.premium_status?.[0]?.tier ?? 'free').toLowerCase();
    const userRole = (user.role ?? 'user').toLowerCase();
    return [
      <button className="rowLink" onClick={() => setSelectedUserId(user.id)}><div className="userCell"><div className="avatar pale">{initials(name)}</div><div><strong>{name}</strong><span>{user.email ?? user.phone_number ?? user.id}</span></div></div></button>,
      <span className={userPlan === 'premium' ? 'premium' : userPlan === 'family' ? 'family' : 'free'}>{userPlan}</span>,
      <span className={userRole === 'admin' ? 'premium' : 'muted'}>{userRole}</span>,
      <StatusPill label={user.moderation_status && user.moderation_status !== 'active' ? user.moderation_status : user.is_verified ? 'Active' : 'Review'} />,
      <span className="muted">{formatDate(user.last_seen ?? user.created_at)}</span>,
      String(user.premium_status?.[0]?.daily_usage_count ?? 0),
      <button className="iconOnly rowMenu" onClick={() => setSelectedUserId(user.id)}><MoreHorizontal size={17} /></button>,
    ];
  });

  return (
    <>
      <div className="content">
        <div className="pageTools">
          <div className="search"><Search size={17} /><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search users by name, email, or phone..." /></div>
          <div className="toolGroup">
            <FilterButton active={plan === 'all'} onClick={() => setPlan('all')}>All plans</FilterButton>
            <FilterButton active={plan === 'premium'} onClick={() => setPlan('premium')}>Premium</FilterButton>
            <FilterButton active={plan === 'family'} onClick={() => setPlan('family')}>Family</FilterButton>
            <FilterButton active={plan === 'free'} onClick={() => setPlan('free')}>Free</FilterButton>
            <FilterButton active={verified === 'all'} onClick={() => setVerified('all')}>All status</FilterButton>
            <FilterButton active={verified === 'verified'} onClick={() => setVerified('verified')}>Verified</FilterButton>
            <FilterButton active={verified === 'review'} onClick={() => setVerified('review')}>Review</FilterButton>
            <button className="select" onClick={() => setSort(sort === 'created_at' ? 'last_seen' : sort === 'last_seen' ? 'full_name' : 'created_at')}>Sort: {sort}</button>
            <button className="select" onClick={() => setSortDir(sortDir === 'asc' ? 'desc' : 'asc')}>{sortDir.toUpperCase()}</button>
            <button className="ghostButton" onClick={() => exportRowsAsCsv('users', ['id', 'name', 'email', 'phone', 'verified', 'plan'], state.items.map((user) => [user.id, user.full_name ?? '', user.email ?? '', user.phone_number ?? '', String(Boolean(user.is_verified)), user.premium_status?.[0]?.tier ?? 'free']))}>Export CSV</button>
          </div>
        </div>

        <section className="panel">
          <div className="panelHead">
            <div><h2>All users <span className="count">{state.count}</span></h2><p>Server-side filter, pagination, detail panel và verify action thật</p></div>
            <button className="ghostButton" onClick={() => void loadPage(state.offset)} disabled={state.loading}>
              {state.loading ? <LoaderCircle size={14} className="spin" /> : <UserRoundPlus size={16} />}
              Reload
            </button>
          </div>
          <RemoteTable headers={['USER', 'PLAN', 'ROLE', 'STATUS', 'LAST ACTIVE', 'USAGE', '']} state={state} rows={rows} emptyTitle="Không có user phù hợp" emptyBody="Thử đổi bộ lọc hoặc từ khóa tìm kiếm." />
          <Pagination meta={state} onPage={(offset) => void loadPage(offset)} />
        </section>
      </div>

      <Drawer open={Boolean(selectedUserId)} title="User detail" onClose={() => setSelectedUserId(undefined)}>
        <DetailState state={detail}>
          {(item) => (
            <div className="drawerBody">
              <KeyValue label="Name" value={item.full_name ?? '—'} />
              <KeyValue label="Email" value={item.email ?? '—'} />
              <KeyValue label="Phone" value={item.phone_number ?? '—'} />
              <KeyValue label="Plan" value={item.premium_status?.[0]?.tier ?? 'free'} />
              <KeyValue label="Role" value={item.role ?? 'user'} />
              <KeyValue label="Access" value={item.moderation_status ?? 'active'} />
              <KeyValue label="Subscription end" value={formatDate(item.subscription_end_date)} />
              <KeyValue label="Access until" value={formatDate(item.moderation_expires_at)} />
              <KeyValue label="Verified" value={item.is_verified ? 'true' : 'false'} />
              <KeyValue label="Last active" value={formatDate(item.last_seen ?? item.created_at)} />
              <div className="drawerSection">
                <div className="drawerActions">
                  <button className="primary" onClick={() => void toggleVerification()} disabled={actionBusy}>
                    {actionBusy ? <LoaderCircle size={14} className="spin" /> : null}
                    {item.is_verified ? 'Mark review' : 'Mark verified'}
                  </button>
                </div>
              </div>
              <div className="drawerSection">
                <strong>Plan settings</strong>
                <div className="formStack">
                  <select className="inputLike" value={planDraft} onChange={(event) => setPlanDraft(event.target.value)}>
                    <option value="free">free</option>
                    <option value="premium">premium</option>
                    <option value="family">family</option>
                  </select>
                  <input className="inputLike" type="date" value={subscriptionDraft} onChange={(event) => setSubscriptionDraft(event.target.value)} />
                  <button className="primary" onClick={() => void savePlan()} disabled={actionBusy}>
                    {actionBusy ? <LoaderCircle size={14} className="spin" /> : null}
                    Save plan
                  </button>
                </div>
              </div>
              <div className="drawerSection">
                <strong>Role</strong>
                <p className="muted">Quyền quản trị trong app (admin/user). Tách biệt với gói Plan.</p>
                <div className="formStack">
                  <select className="inputLike" value={roleDraft} onChange={(event) => setRoleDraft(event.target.value as 'admin' | 'user')}>
                    <option value="user">user</option>
                    <option value="admin">admin</option>
                  </select>
                  <button className="primary" onClick={() => void saveRole()} disabled={actionBusy}>
                    {actionBusy ? <LoaderCircle size={14} className="spin" /> : null}
                    Save role
                  </button>
                </div>
              </div>
              <div className="drawerSection">
                <strong>Access control</strong>
                <div className="formStack">
                  <select className="inputLike" value={moderationStatus} onChange={(event) => setModerationStatus(event.target.value)}>
                    <option value="active">active</option>
                    <option value="restricted">restricted</option>
                    <option value="suspended">suspended</option>
                  </select>
                  <input className="inputLike" value={moderationReason} onChange={(event) => setModerationReason(event.target.value)} placeholder="Reason visible to ops" />
                  <textarea className="inputLike textAreaLike" value={moderationNote} onChange={(event) => setModerationNote(event.target.value)} placeholder="Internal moderation note" />
                  <input className="inputLike" type="date" value={moderationUntil} onChange={(event) => setModerationUntil(event.target.value)} />
                  <button className="primary" onClick={() => void saveModeration()} disabled={actionBusy}>
                    {actionBusy ? <LoaderCircle size={14} className="spin" /> : null}
                    Save access rule
                  </button>
                </div>
              </div>
              <DetailList title="Recent usage (7 days)" items={item.usage_daily?.map((usage) => `${usage.usage_date}: ${usage.voice_sessions ?? 0} sessions / ${usage.voice_turns ?? 0} turns`) ?? []} />
              <DetailList title="Recent voice sessions" items={item.recent_voice_sessions?.map((session) => `${session.client_session_id ?? session.id}: ${session.status ?? 'unknown'} • ${formatDate(session.started_at)}`) ?? []} />
            </div>
          )}
        </DetailState>
      </Drawer>
    </>
  );
}

function VoiceOperationsPage({ token, connected }: { token: string; connected: boolean }) {
  const [query, setQuery] = useState('');
  const [status, setStatus] = useState<'all' | 'active' | 'ended' | 'error' | 'idle_timeout'>('all');
  const [sort, setSort] = useState<'started_at' | 'status' | 'latest_event_at'>('started_at');
  const [sortDir, setSortDir] = useState<'asc' | 'desc'>('desc');
  const [state, setState] = useState<RemoteState<AdminVoiceSession>>(emptyRemoteState());
  const [selectedId, setSelectedId] = useState<string>();
  const [detail, setDetail] = useState<Loadable<AdminVoiceSession>>({ loading: false });
  const [reviewDraft, setReviewDraft] = useState('pending');
  const [reviewNote, setReviewNote] = useState('');
  const [actionBusy, setActionBusy] = useState(false);

  useEffect(() => {
    if (!connected || !token) {
      return;
    }
    void loadPage(0);
  }, [token, connected, query, status, sort, sortDir]);

  useEffect(() => {
    if (!selectedId || !token) {
      setDetail({ loading: false });
      return;
    }
    void loadDetail(selectedId);
  }, [selectedId, token]);

  const loadPage = async (offset = state.offset) => {
    setState((current) => ({ ...current, loading: true, error: undefined }));
    try {
      const response = await fetchVoiceSessions(token, {
        search: query || undefined,
        status: status === 'all' ? undefined : status,
        sort,
        dir: sortDir,
        limit: PAGE_SIZE,
        offset,
      });
      setState(toRemoteState(response));
    } catch (error) {
      setState((current) => ({ ...current, loading: false, error: asMessage(error) }));
    }
  };

  const loadDetail = async (id: string) => {
    setDetail({ loading: true });
    try {
      const item = await fetchVoiceSessionDetail(token, id);
      setReviewDraft(item.review_status ?? 'pending');
      setReviewNote(item.review_note ?? '');
      setDetail({ loading: false, item });
    } catch (error) {
      setDetail({ loading: false, error: asMessage(error) });
    }
  };

  const saveReview = async () => {
    if (!selectedId) return;
    setActionBusy(true);
    try {
      const response = await updateVoiceSessionReview(token, selectedId, reviewDraft, reviewNote);
      setDetail({ loading: false, item: response.item });
      await loadPage(state.offset);
    } catch (error) {
      setDetail((current) => ({ ...current, error: asMessage(error) }));
    } finally {
      setActionBusy(false);
    }
  };

  const rows = state.items.map((session) => [
    <button className="rowLink" onClick={() => setSelectedId(session.id)}><div className="tablePrimary"><strong>{session.client_session_id ?? session.id ?? 'session'}</strong><span>{session.user_id ?? 'Anonymous'}</span></div></button>,
    <StatusPill label={normalizeSessionStatus(session.status)} />,
    session.language ?? 'vi',
    session.voice_profile ?? 'Default',
    `${session.voice_turns?.length ?? 0} turns`,
    String(session.event_count ?? 0),
    <span className="muted">{formatDate(session.started_at)}</span>,
  ]);

  return (
    <>
      <div className="content">
        <div className="pageTools">
          <div className="search"><Search size={17} /><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search session id or user id..." /></div>
          <div className="toolGroup">
            <FilterButton active={status === 'all'} onClick={() => setStatus('all')}>All</FilterButton>
            <FilterButton active={status === 'active'} onClick={() => setStatus('active')}>Active</FilterButton>
            <FilterButton active={status === 'ended'} onClick={() => setStatus('ended')}>Ended</FilterButton>
            <FilterButton active={status === 'error'} onClick={() => setStatus('error')}>Error</FilterButton>
            <FilterButton active={status === 'idle_timeout'} onClick={() => setStatus('idle_timeout')}>Idle timeout</FilterButton>
            <button className="select" onClick={() => setSort(sort === 'started_at' ? 'status' : sort === 'status' ? 'latest_event_at' : 'started_at')}>Sort: {sort}</button>
            <button className="select" onClick={() => setSortDir(sortDir === 'asc' ? 'desc' : 'asc')}>{sortDir.toUpperCase()}</button>
            <button className="ghostButton" onClick={() => exportRowsAsCsv('voice-sessions', ['id', 'client_session_id', 'status', 'language', 'voice_profile', 'event_count'], state.items.map((item) => [item.id ?? '', item.client_session_id ?? '', item.status ?? '', item.language ?? '', item.voice_profile ?? '', String(item.event_count ?? 0)]))}>Export CSV</button>
          </div>
        </div>

        <section className="panel">
          <div className="panelHead">
            <div><h2>Voice operations <span className="count">{state.count}</span></h2><p>Server search + pagination + detail thật</p></div>
          </div>
          <RemoteTable headers={['SESSION', 'STATUS', 'LANG', 'VOICE', 'TURNS', 'EVENTS', 'STARTED']} state={state} rows={rows} emptyTitle="Không có voice session phù hợp" emptyBody="Thử đổi bộ lọc hoặc search khác." />
          <Pagination meta={state} onPage={(offset) => void loadPage(offset)} />
        </section>
      </div>

      <Drawer open={Boolean(selectedId)} title="Voice session detail" onClose={() => setSelectedId(undefined)}>
        <DetailState state={detail}>
          {(item) => (
            <div className="drawerBody">
              <KeyValue label="Client session id" value={item.client_session_id ?? '—'} />
              <KeyValue label="User id" value={item.user_id ?? '—'} />
              <KeyValue label="Status" value={normalizeSessionStatus(item.status)} />
              <KeyValue label="Voice profile" value={item.voice_profile ?? '—'} />
              <KeyValue label="Event count" value={String(item.event_count ?? 0)} />
              <KeyValue label="Provider calls" value={String(item.provider_call_count ?? 0)} />
              <KeyValue label="Review status" value={item.review_status ?? 'pending'} />
              <KeyValue label="Started at" value={formatDate(item.started_at)} />
              <KeyValue label="Ended at" value={formatDate(item.ended_at)} />
              <div className="drawerSection">
                <strong>Review mark</strong>
                <div className="formStack">
                  <select className="inputLike" value={reviewDraft} onChange={(event) => setReviewDraft(event.target.value)}>
                    <option value="pending">pending</option>
                    <option value="reviewed">reviewed</option>
                    <option value="flagged">flagged</option>
                  </select>
                  <textarea className="inputLike textAreaLike" value={reviewNote} onChange={(event) => setReviewNote(event.target.value)} placeholder="Review note" />
                  <button className="primary" onClick={() => void saveReview()} disabled={actionBusy}>
                    {actionBusy ? <LoaderCircle size={14} className="spin" /> : null}
                    Save review
                  </button>
                </div>
              </div>
              <DetailList title="Turns" items={item.voice_turns?.map((turn) => `${turn.turn_id ?? turn.id}: ${normalizeTurnStatus(turn.status)} • ${trim(turn.user_text ?? 'No user text', 60)}`) ?? []} />
            </div>
          )}
        </DetailState>
      </Drawer>
    </>
  );
}

function ConversationsPage({ token, connected }: { token: string; connected: boolean }) {
  const [query, setQuery] = useState('');
  const [status, setStatus] = useState<'all' | 'completed' | 'processing' | 'error' | 'interrupted'>('all');
  const [sort, setSort] = useState<'started_at' | 'status' | 'latency'>('started_at');
  const [sortDir, setSortDir] = useState<'asc' | 'desc'>('desc');
  const [state, setState] = useState<RemoteState<AdminConversation>>(emptyRemoteState());
  const [selectedId, setSelectedId] = useState<string>();
  const [detail, setDetail] = useState<Loadable<AdminConversationDetail>>({ loading: false });
  const [reviewDraft, setReviewDraft] = useState('pending');
  const [reviewNote, setReviewNote] = useState('');
  const [actionBusy, setActionBusy] = useState(false);

  useEffect(() => {
    if (!connected || !token) {
      return;
    }
    void loadPage(0);
  }, [token, connected, query, status, sort, sortDir]);

  useEffect(() => {
    if (!selectedId || !token) {
      setDetail({ loading: false });
      return;
    }
    void loadDetail(selectedId);
  }, [selectedId, token]);

  const loadPage = async (offset = state.offset) => {
    setState((current) => ({ ...current, loading: true, error: undefined }));
    try {
      const response = await fetchConversations(token, {
        search: query || undefined,
        status: status === 'all' ? undefined : status,
        sort,
        dir: sortDir,
        limit: PAGE_SIZE,
        offset,
      });
      setState(toRemoteState(response));
    } catch (error) {
      setState((current) => ({ ...current, loading: false, error: asMessage(error) }));
    }
  };

  const loadDetail = async (id: string) => {
    setDetail({ loading: true });
    try {
      const item = await fetchConversationDetail(token, id);
      setReviewDraft(item.review_status ?? 'pending');
      setReviewNote(item.review_note ?? '');
      setDetail({ loading: false, item });
    } catch (error) {
      setDetail({ loading: false, error: asMessage(error) });
    }
  };

  const saveReview = async () => {
    if (!selectedId) return;
    setActionBusy(true);
    try {
      const response = await updateConversationReview(token, selectedId, reviewDraft, reviewNote);
      setDetail({ loading: false, item: response.item });
      await loadPage(state.offset);
    } catch (error) {
      setDetail((current) => ({ ...current, error: asMessage(error) }));
    } finally {
      setActionBusy(false);
    }
  };

  const rows = state.items.map((turn) => [
    <button className="rowLink" onClick={() => setSelectedId(turn.id)}><div className="tablePrimary"><strong>{turn.turn_id ?? turn.id ?? 'turn'}</strong><span>{turn.voice_sessions?.client_session_id ?? 'No session'}</span></div></button>,
    <span className="breakCell">{trim(turn.user_text ?? 'No user text', 72)}</span>,
    <span className="breakCell">{trim(turn.assistant_text ?? 'No assistant text', 72)}</span>,
    <StatusPill label={normalizeTurnStatus(turn.status)} />,
    turn.latency?.totalMs ? `${Math.round(turn.latency.totalMs)}ms` : '—',
    <span className="muted">{formatDate(turn.completed_at ?? turn.started_at)}</span>,
  ]);

  return (
    <>
      <div className="content">
        <div className="pageTools">
          <div className="search"><Search size={17} /><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search by text, turn id, or session id..." /></div>
          <div className="toolGroup">
            <FilterButton active={status === 'all'} onClick={() => setStatus('all')}>All</FilterButton>
            <FilterButton active={status === 'completed'} onClick={() => setStatus('completed')}>Completed</FilterButton>
            <FilterButton active={status === 'processing'} onClick={() => setStatus('processing')}>Processing</FilterButton>
            <FilterButton active={status === 'error'} onClick={() => setStatus('error')}>Error</FilterButton>
            <FilterButton active={status === 'interrupted'} onClick={() => setStatus('interrupted')}>Interrupted</FilterButton>
            <button className="select" onClick={() => setSort(sort === 'started_at' ? 'status' : sort === 'status' ? 'latency' : 'started_at')}>Sort: {sort}</button>
            <button className="select" onClick={() => setSortDir(sortDir === 'asc' ? 'desc' : 'asc')}>{sortDir.toUpperCase()}</button>
            <button className="ghostButton" onClick={() => exportRowsAsCsv('conversations', ['id', 'turn_id', 'status', 'user_text', 'assistant_text'], state.items.map((item) => [item.id ?? '', item.turn_id ?? '', item.status ?? '', item.user_text ?? '', item.assistant_text ?? '']))}>Export CSV</button>
          </div>
        </div>

        <section className="panel">
          <div className="panelHead">
            <div><h2>Conversation review <span className="count">{state.count}</span></h2><p>Detail thật gồm events và provider calls</p></div>
          </div>
          <RemoteTable headers={['TURN', 'USER TEXT', 'ASSISTANT TEXT', 'STATUS', 'LATENCY', 'UPDATED']} state={state} rows={rows} emptyTitle="Không có conversation phù hợp" emptyBody="Thử đổi bộ lọc hoặc từ khóa tìm kiếm." />
          <Pagination meta={state} onPage={(offset) => void loadPage(offset)} />
        </section>
      </div>

      <Drawer open={Boolean(selectedId)} title="Conversation detail" onClose={() => setSelectedId(undefined)}>
        <DetailState state={detail}>
          {(item) => (
            <div className="drawerBody">
              <KeyValue label="Turn id" value={item.turn_id ?? item.id ?? '—'} />
              <KeyValue label="Session" value={item.voice_session?.client_session_id ?? '—'} />
              <KeyValue label="Status" value={normalizeTurnStatus(item.status)} />
              <KeyValue label="Review status" value={item.review_status ?? 'pending'} />
              <KeyValue label="Latency" value={item.latency?.totalMs ? `${Math.round(item.latency.totalMs)}ms` : '—'} />
              <div className="detailBlock">
                <strong>User text</strong>
                <p>{item.user_text ?? '—'}</p>
              </div>
              <div className="detailBlock">
                <strong>Assistant text</strong>
                <p>{item.assistant_text ?? '—'}</p>
              </div>
              <div className="drawerSection">
                <strong>Review mark</strong>
                <div className="formStack">
                  <select className="inputLike" value={reviewDraft} onChange={(event) => setReviewDraft(event.target.value)}>
                    <option value="pending">pending</option>
                    <option value="reviewed">reviewed</option>
                    <option value="flagged">flagged</option>
                  </select>
                  <textarea className="inputLike textAreaLike" value={reviewNote} onChange={(event) => setReviewNote(event.target.value)} placeholder="Review note" />
                  <button className="primary" onClick={() => void saveReview()} disabled={actionBusy}>
                    {actionBusy ? <LoaderCircle size={14} className="spin" /> : null}
                    Save review
                  </button>
                </div>
              </div>
              <DetailList title="Related events" items={item.related_events?.map((event) => `${event.event_type}: ${formatDate(event.created_at)}`) ?? []} />
              <DetailList title="Provider calls" items={item.provider_calls?.map((call) => `${call.provider}/${call.operation}: ${call.status} • ${call.latency_ms ?? '—'}ms`) ?? []} />
            </div>
          )}
        </DetailState>
      </Drawer>
    </>
  );
}

function HealthPage({ apiState, hasLoaded }: { apiState: AdminApiState; hasLoaded: boolean }) {
  const rows = buildHealthRows(apiState);
  return (
    <div className="content">
      <section className="panel">
        <div className="panelHead">
          <div><h2>System checks</h2><p>Trạng thái đọc từ admin API và dependency health</p></div>
        </div>
        <RemoteTable
          headers={['SERVICE', 'STATUS', 'CHECK', 'LATENCY', 'TARGET']}
          state={{ loading: !hasLoaded, items: rows, count: rows.length, limit: rows.length, offset: 0 }}
          rows={rows}
          emptyTitle="Chưa đọc được health data"
          emptyBody="Đăng nhập và refresh lại để lấy trạng thái thật."
        />
      </section>
    </div>
  );
}

function AuditPage({ token, connected }: { token: string; connected: boolean }) {
  const [query, setQuery] = useState('');
  const [sort, setSort] = useState<'created_at' | 'action' | 'actor_role'>('created_at');
  const [sortDir, setSortDir] = useState<'asc' | 'desc'>('desc');
  const [state, setState] = useState<RemoteState<AdminAuditLog>>(emptyRemoteState());

  useEffect(() => {
    if (!connected || !token) {
      return;
    }
    void loadPage(0);
  }, [token, connected, query, sort, sortDir]);

  const loadPage = async (offset = state.offset) => {
    setState((current) => ({ ...current, loading: true, error: undefined }));
    try {
      const response = await fetchAuditLogs(token, { search: query || undefined, sort, dir: sortDir, limit: PAGE_SIZE, offset });
      setState(toRemoteState(response));
    } catch (error) {
      setState((current) => ({ ...current, loading: false, error: asMessage(error) }));
    }
  };

  const rows = state.items.map((log) => [
    <div className="tablePrimary"><strong>{log.actor_id ?? 'System'}</strong><span>{log.actor_role ?? 'service'}</span></div>,
    <StatusPill label={log.action ?? 'unknown'} />,
    log.target_type ?? '—',
    log.target_id ?? '—',
    <span className="muted">{formatDate(log.created_at)}</span>,
  ]);

  return (
    <div className="content">
      <div className="pageTools">
        <div className="search"><Search size={17} /><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search actor, role, action, target..." /></div>
        <div className="toolGroup">
          <button className="ghostButton" onClick={() => setSort((current) => current === 'created_at' ? 'action' : current === 'action' ? 'actor_role' : 'created_at')}>Sort: {sort}</button>
          <button className="ghostButton" onClick={() => setSortDir((current) => current === 'desc' ? 'asc' : 'desc')}>Dir: {sortDir}</button>
          <button className="ghostButton" onClick={() => exportRowsAsCsv('audit-logs', ['actor_id', 'actor_role', 'action', 'target_type', 'target_id', 'created_at'], state.items.map((item) => [item.actor_id ?? '', item.actor_role ?? '', item.action ?? '', item.target_type ?? '', item.target_id ?? '', item.created_at ?? '']))}>Export CSV</button>
        </div>
      </div>
      <section className="panel">
        <div className="panelHead">
          <div><h2>Audit timeline <span className="count">{state.count}</span></h2><p>Server search + pagination trên audit log thật</p></div>
        </div>
        <RemoteTable headers={['ACTOR', 'ACTION', 'TARGET TYPE', 'TARGET ID', 'TIME']} state={state} rows={rows} emptyTitle="Không có audit log phù hợp" emptyBody="Thử đổi từ khóa tìm kiếm." />
        <Pagination meta={state} onPage={(offset) => void loadPage(offset)} />
      </section>
    </div>
  );
}

function HealthRecordsPage({ token, connected }: { token: string; connected: boolean }) {
  const [query, setQuery] = useState('');
  const [anomaly, setAnomaly] = useState<'all' | 'anomaly' | 'normal'>('all');
  const [sort, setSort] = useState<'measured_at' | 'heart_rate' | 'systolic_bp'>('measured_at');
  const [sortDir, setSortDir] = useState<'asc' | 'desc'>('desc');
  const [state, setState] = useState<RemoteState<AdminHealthMeasurement>>(emptyRemoteState());
  const [selectedId, setSelectedId] = useState<string>();
  const [detail, setDetail] = useState<Loadable<AdminHealthMeasurementDetail>>({ loading: false });

  useEffect(() => {
    if (!connected || !token) {
      return;
    }
    void loadPage(0);
  }, [token, connected, query, anomaly, sort, sortDir]);

  useEffect(() => {
    if (!selectedId || !token) {
      setDetail({ loading: false });
      return;
    }
    void loadDetail(selectedId);
  }, [selectedId, token]);

  const loadPage = async (offset = state.offset) => {
    setState((current) => ({ ...current, loading: true, error: undefined }));
    try {
      const response = await fetchHealthMeasurements(token, {
        search: query || undefined,
        anomaly: anomaly === 'all' ? undefined : anomaly,
        sort,
        dir: sortDir,
        limit: PAGE_SIZE,
        offset,
      });
      setState(toRemoteState(response));
    } catch (error) {
      setState((current) => ({ ...current, loading: false, error: asMessage(error) }));
    }
  };

  const loadDetail = async (id: string) => {
    setDetail({ loading: true });
    try {
      const item = await fetchHealthMeasurementDetail(token, id);
      setDetail({ loading: false, item });
    } catch (error) {
      setDetail({ loading: false, error: asMessage(error) });
    }
  };

  const rows = state.items.map((record) => [
    <button className="rowLink" onClick={() => setSelectedId(record.id)}><div className="tablePrimary"><strong>{record.user_label ?? record.user_id ?? 'user'}</strong><span>{record.user_email ?? record.user_id ?? '—'}</span></div></button>,
    <span>{record.systolic_bp != null && record.diastolic_bp != null ? `${record.systolic_bp}/${record.diastolic_bp} mmHg` : '—'}</span>,
    <span>{record.heart_rate != null ? `${record.heart_rate} bpm` : '—'}</span>,
    <StatusPill label={record.ai_anomaly_flag ? 'Anomaly' : 'Normal'} />,
    record.source ?? '—',
    <span className="muted">{formatDate(record.measured_at ?? record.created_at)}</span>,
  ]);

  return (
    <>
      <div className="content">
        <div className="pageTools">
          <div className="search"><Search size={17} /><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search by patient name, email, or id..." /></div>
          <div className="toolGroup">
            <FilterButton active={anomaly === 'all'} onClick={() => setAnomaly('all')}>All</FilterButton>
            <FilterButton active={anomaly === 'anomaly'} onClick={() => setAnomaly('anomaly')}>Anomaly</FilterButton>
            <FilterButton active={anomaly === 'normal'} onClick={() => setAnomaly('normal')}>Normal</FilterButton>
            <button className="select" onClick={() => setSort(sort === 'measured_at' ? 'heart_rate' : sort === 'heart_rate' ? 'systolic_bp' : 'measured_at')}>Sort: {sort}</button>
            <button className="select" onClick={() => setSortDir(sortDir === 'asc' ? 'desc' : 'asc')}>{sortDir.toUpperCase()}</button>
            <button className="ghostButton" onClick={() => exportRowsAsCsv('health-measurements', ['id', 'user', 'systolic_bp', 'diastolic_bp', 'heart_rate', 'anomaly', 'measured_at'], state.items.map((item) => [item.id, item.user_label ?? '', item.systolic_bp ?? '', item.diastolic_bp ?? '', item.heart_rate ?? '', String(Boolean(item.ai_anomaly_flag)), item.measured_at ?? '']))}>Export CSV</button>
          </div>
        </div>

        <section className="panel">
          <div className="panelHead">
            <div><h2>Health records <span className="count">{state.count}</span></h2><p>Chỉ số huyết áp / nhịp tim thật từ app, đọc trực tiếp từ database</p></div>
            <button className="ghostButton" onClick={() => void loadPage(state.offset)} disabled={state.loading}>
              {state.loading ? <LoaderCircle size={14} className="spin" /> : <HeartPulse size={16} />}
              Reload
            </button>
          </div>
          <RemoteTable headers={['PATIENT', 'BLOOD PRESSURE', 'HEART RATE', 'FLAG', 'SOURCE', 'MEASURED']} state={state} rows={rows} emptyTitle="Không có bản ghi sức khỏe" emptyBody="Thử đổi bộ lọc hoặc từ khóa tìm kiếm." />
          <Pagination meta={state} onPage={(offset) => void loadPage(offset)} />
        </section>
      </div>

      <Drawer open={Boolean(selectedId)} title="Health record detail" onClose={() => setSelectedId(undefined)}>
        <DetailState state={detail}>
          {(item) => (
            <div className="drawerBody">
              <KeyValue label="Patient" value={item.user_label ?? '—'} />
              <KeyValue label="Email" value={item.user_email ?? '—'} />
              <KeyValue label="Phone" value={item.user_phone ?? '—'} />
              <KeyValue label="Blood pressure" value={item.systolic_bp != null && item.diastolic_bp != null ? `${item.systolic_bp}/${item.diastolic_bp} mmHg` : '—'} />
              <KeyValue label="Heart rate" value={item.heart_rate != null ? `${item.heart_rate} bpm` : '—'} />
              <KeyValue label="Anomaly flag" value={item.ai_anomaly_flag ? 'true' : 'false'} />
              <KeyValue label="Source" value={item.source ?? '—'} />
              <KeyValue label="Measured at" value={formatDate(item.measured_at)} />
              {item.notes ? (
                <div className="detailBlock">
                  <strong>Notes</strong>
                  <p>{item.notes}</p>
                </div>
              ) : null}
              <DetailList title="Time series" items={item.time_series?.map((point) => `${point.metric_type}: ${point.value ?? '—'} ${point.unit ?? ''} • ${formatDate(point.measured_at)}`) ?? []} />
            </div>
          )}
        </DetailState>
      </Drawer>
    </>
  );
}

function ChatPage({ token, connected }: { token: string; connected: boolean }) {
  const [query, setQuery] = useState('');
  const [type, setType] = useState<'all' | 'direct' | 'group'>('all');
  const [sort, setSort] = useState<'last_message_time' | 'created_at' | 'message_count'>('last_message_time');
  const [sortDir, setSortDir] = useState<'asc' | 'desc'>('desc');
  const [state, setState] = useState<RemoteState<AdminChatRoom>>(emptyRemoteState());
  const [selectedId, setSelectedId] = useState<string>();
  const [detail, setDetail] = useState<Loadable<AdminChatRoomDetail>>({ loading: false });
  const [actionBusy, setActionBusy] = useState(false);

  useEffect(() => {
    if (!connected || !token) {
      return;
    }
    void loadPage(0);
  }, [token, connected, query, type, sort, sortDir]);

  useEffect(() => {
    if (!selectedId || !token) {
      setDetail({ loading: false });
      return;
    }
    void loadDetail(selectedId);
  }, [selectedId, token]);

  const loadPage = async (offset = state.offset) => {
    setState((current) => ({ ...current, loading: true, error: undefined }));
    try {
      const response = await fetchChatRooms(token, {
        search: query || undefined,
        type: type === 'all' ? undefined : type,
        sort,
        dir: sortDir,
        limit: PAGE_SIZE,
        offset,
      });
      setState(toRemoteState(response));
    } catch (error) {
      setState((current) => ({ ...current, loading: false, error: asMessage(error) }));
    }
  };

  const loadDetail = async (id: string) => {
    setDetail({ loading: true });
    try {
      const item = await fetchChatRoomDetail(token, id);
      setDetail({ loading: false, item });
    } catch (error) {
      setDetail({ loading: false, error: asMessage(error) });
    }
  };

  const removeMessage = async (messageId: string) => {
    if (!selectedId) return;
    setActionBusy(true);
    try {
      await deleteChatMessage(token, messageId);
      await loadDetail(selectedId);
      await loadPage(state.offset);
    } catch (error) {
      setDetail((current) => ({ ...current, error: asMessage(error) }));
    } finally {
      setActionBusy(false);
    }
  };

  const rows = state.items.map((room) => [
    <button className="rowLink" onClick={() => setSelectedId(room.id)}><div className="tablePrimary"><strong>{room.name || (room.participants ?? []).map((participant) => participant.label).join(', ') || room.id}</strong><span>{trim(room.last_message_text ?? 'No messages', 60)}</span></div></button>,
    <span>{room.type ?? 'direct'}</span>,
    String(room.participant_count ?? 0),
    String(room.message_count ?? 0),
    <span className="muted">{formatDate(room.last_message_time ?? room.created_at)}</span>,
  ]);

  return (
    <>
      <div className="content">
        <div className="pageTools">
          <div className="search"><Search size={17} /><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search by room name or last message..." /></div>
          <div className="toolGroup">
            <FilterButton active={type === 'all'} onClick={() => setType('all')}>All</FilterButton>
            <FilterButton active={type === 'direct'} onClick={() => setType('direct')}>Direct</FilterButton>
            <FilterButton active={type === 'group'} onClick={() => setType('group')}>Group</FilterButton>
            <button className="select" onClick={() => setSort(sort === 'last_message_time' ? 'created_at' : sort === 'created_at' ? 'message_count' : 'last_message_time')}>Sort: {sort}</button>
            <button className="select" onClick={() => setSortDir(sortDir === 'asc' ? 'desc' : 'asc')}>{sortDir.toUpperCase()}</button>
          </div>
        </div>

        <section className="panel">
          <div className="panelHead">
            <div><h2>Chat rooms <span className="count">{state.count}</span></h2><p>Giám sát phòng chat thật; mở room để xem tin nhắn và ẩn nội dung vi phạm</p></div>
            <button className="ghostButton" onClick={() => void loadPage(state.offset)} disabled={state.loading}>
              {state.loading ? <LoaderCircle size={14} className="spin" /> : <MessageSquare size={16} />}
              Reload
            </button>
          </div>
          <RemoteTable headers={['ROOM', 'TYPE', 'PARTICIPANTS', 'MESSAGES', 'LAST ACTIVITY']} state={state} rows={rows} emptyTitle="Không có phòng chat phù hợp" emptyBody="Thử đổi bộ lọc hoặc từ khóa tìm kiếm." />
          <Pagination meta={state} onPage={(offset) => void loadPage(offset)} />
        </section>
      </div>

      <Drawer open={Boolean(selectedId)} title="Chat room detail" onClose={() => setSelectedId(undefined)}>
        <DetailState state={detail}>
          {(item) => (
            <div className="drawerBody">
              <KeyValue label="Room" value={item.name ?? item.id} />
              <KeyValue label="Type" value={item.type ?? 'direct'} />
              <KeyValue label="Created" value={formatDate(item.created_at)} />
              <DetailList title="Participants" items={item.participants?.map((participant) => participant.label ?? participant.profile_id ?? '—') ?? []} />
              <div className="drawerSection">
                <strong>Messages ({item.messages?.length ?? 0})</strong>
                {(item.messages ?? []).length > 0 ? (
                  <ul className="detailList">
                    {(item.messages ?? []).map((message) => (
                      <li key={message.id}>
                        <div className="chatMessageRow">
                          <div>
                            <strong>{message.sender_label ?? message.sender_id ?? 'unknown'}</strong>
                            <span className="muted"> • {formatDate(message.created_at)}</span>
                            <p className={message.is_deleted ? 'detailMuted' : ''}>{message.is_deleted ? '[deleted]' : (message.content ?? `[${message.type ?? 'message'}]`)}</p>
                          </div>
                          {!message.is_deleted && message.id ? (
                            <button className="ghostButton" onClick={() => void removeMessage(message.id!)} disabled={actionBusy}>Hide</button>
                          ) : null}
                        </div>
                      </li>
                    ))}
                  </ul>
                ) : <p className="detailMuted">Chưa có tin nhắn.</p>}
              </div>
            </div>
          )}
        </DetailState>
      </Drawer>
    </>
  );
}

function RemoteTable<T>({ headers, state, rows, emptyTitle, emptyBody }: { headers: string[]; state: RemoteState<T>; rows: ReactNode[][]; emptyTitle: string; emptyBody: string }) {
  if (state.loading && rows.length === 0) {
    return <EmptyState icon={LoaderCircle} title="Đang tải dữ liệu" body="Hệ thống đang đọc dữ liệu thật từ admin API." spinning />;
  }
  if (state.error && rows.length === 0) {
    return <EmptyState icon={AlertTriangle} title="Không tải được dữ liệu" body={state.error} />;
  }
  if (rows.length === 0) {
    return <EmptyState icon={Search} title={emptyTitle} body={emptyBody} />;
  }
  return <DataTable headers={headers} rows={rows} />;
}

function DataTable({ headers, rows }: { headers: string[]; rows: ReactNode[][] }) {
  return (
    <div className="tableWrap">
      <table>
        <thead><tr>{headers.map((head) => <th key={head}>{head}</th>)}</tr></thead>
        <tbody>{rows.map((row, index) => <tr key={index}>{row.map((cell, cellIndex) => <td key={`${index}-${cellIndex}`}>{cell}</td>)}</tr>)}</tbody>
      </table>
    </div>
  );
}

function DetailState<T>({ state, children }: { state: Loadable<T>; children: (item: T) => ReactNode }) {
  if (state.loading) {
    return <EmptyState icon={LoaderCircle} title="Đang tải chi tiết" body="Đang đọc bản ghi thật từ hệ thống." spinning compact />;
  }
  if (state.error) {
    return <EmptyState icon={AlertTriangle} title="Không tải được chi tiết" body={state.error} compact />;
  }
  if (!state.item) {
    return <EmptyState icon={FileText} title="Chưa chọn bản ghi" body="Chọn một bản ghi ở bảng để mở panel chi tiết." compact />;
  }
  return <>{children(state.item)}</>;
}

function Drawer({ open, title, onClose, children }: { open: boolean; title: string; onClose: () => void; children: ReactNode }) {
  return (
    <div className={open ? 'drawerOverlay open' : 'drawerOverlay'} onClick={onClose}>
      <aside className={open ? 'drawer open' : 'drawer'} onClick={(event) => event.stopPropagation()}>
        <div className="drawerHead">
          <div>
            <strong>{title}</strong>
            <span>Realtime detail panel</span>
          </div>
          <button className="iconOnly" onClick={onClose}><X size={18} /></button>
        </div>
        {children}
      </aside>
    </div>
  );
}

function Pagination({ meta, onPage }: { meta: RemoteState<unknown>; onPage: (offset: number) => void }) {
  const previousOffset = Math.max(0, meta.offset - meta.limit);
  const nextOffset = meta.offset + meta.limit;
  const page = meta.limit ? Math.floor(meta.offset / meta.limit) + 1 : 1;
  const totalPages = meta.limit ? Math.max(1, Math.ceil(meta.count / meta.limit)) : 1;

  return (
    <div className="paginationBar">
      <span>Page {page} / {totalPages}</span>
      <div className="toolGroup">
        <button className="select" onClick={() => onPage(previousOffset)} disabled={meta.offset === 0 || meta.loading}>Previous</button>
        <button className="select" onClick={() => onPage(nextOffset)} disabled={nextOffset >= meta.count || meta.loading}>Next</button>
      </div>
    </div>
  );
}

function Metric({ icon: Icon, label, value, trend, good = false, warning = false }: { icon: typeof Users; label: string; value: string; trend: string; good?: boolean; warning?: boolean }) {
  return <div className={warning ? 'metric warningMetric' : 'metric'}><div className="metricIcon"><Icon size={19} /></div><div><span>{label}</span><strong>{value}</strong><small className={good ? 'good' : warning ? 'warning' : ''}>{trend}</small></div></div>;
}

function FilterButton({ active, onClick, children }: { active: boolean; onClick: () => void; children: ReactNode }) {
  return <button className={active ? 'select activeSelect' : 'select'} onClick={onClick}>{children}</button>;
}

function StatusPill({ label }: { label: string }) {
  const className = label.toLowerCase().replace(/[^a-z0-9]+/g, '-');
  return <span className={`pill ${className}`}><i />{label}</span>;
}

function Issue({ title, meta, tone }: { title: string; meta: string; tone: 'hot' | 'warm' | 'cool' }) {
  return <div className={`issue ${tone}`}><span /><div><strong>{title}</strong><p>{meta}</p></div><button className="iconOnly"><ChevronDown size={16} /></button></div>;
}

function EmptyState({ icon: Icon, title, body, compact = false, spinning = false }: { icon: typeof Activity; title: string; body: string; compact?: boolean; spinning?: boolean }) {
  return (
    <div className={compact ? 'emptyState compactEmptyState' : 'emptyState'}>
      <div className="emptyIcon">{spinning ? <Icon size={20} className="spin" /> : <Icon size={20} />}</div>
      <div><strong>{title}</strong><p>{body}</p></div>
    </div>
  );
}

function KeyValue({ label, value }: { label: string; value: string }) {
  return <div className="keyValueRow"><span>{label}</span><strong>{value}</strong></div>;
}

function DetailList({ title, items }: { title: string; items: string[] }) {
  return (
    <div className="drawerSection">
      <strong>{title}</strong>
      {items.length > 0 ? <ul className="detailList">{items.map((item) => <li key={item}>{item}</li>)}</ul> : <p className="detailMuted">Chưa có dữ liệu.</p>}
    </div>
  );
}

function buildDashboardStats(apiState: AdminApiState) {
  const userCount = apiState.overview?.users?.totalSample ?? apiState.users.length;
  const activeUsers = apiState.overview?.users?.activeSample ?? apiState.users.filter((user) => Boolean(user.last_seen)).length;
  const sessionCount = apiState.overview?.voice?.sessionsSample ?? apiState.sessions.length;
  const activeSessions = apiState.overview?.voice?.activeSessions ?? apiState.sessions.filter((session) => session.status === 'active').length;
  const averageTotalMs = apiState.overview?.voice?.averageTotalMs ?? null;
  const errorTurns = apiState.overview?.voice?.errorTurns ?? apiState.conversations.filter((turn) => turn.status === 'error').length;
  const suspendedUsers = apiState.overview?.moderation?.suspendedUsers ?? 0;
  const pendingReviews = apiState.overview?.moderation?.pendingReviews ?? 0;
  return {
    userCount,
    activeUsers,
    sessionCount,
    activeSessions,
    avgResponse: averageTotalMs ? `${Math.round(averageTotalMs)}ms` : '—',
    avgResponseMeta: averageTotalMs ? 'Based on persisted completed turns' : 'Chưa có đủ completed turns',
    errorTurns,
    suspendedUsers,
    pendingReviews,
  };
}

function buildAttentionItems(apiState: AdminApiState): Array<{ title: string; meta: string; tone: 'hot' | 'warm' | 'cool' }> {
  const items: Array<{ title: string; meta: string; tone: 'hot' | 'warm' | 'cool' }> = [];
  const errorTurns = apiState.overview?.voice?.errorTurns ?? 0;
  const unverifiedUsers = apiState.users.filter((user) => !user.is_verified).length;
  const suspendedUsers = apiState.overview?.moderation?.suspendedUsers ?? 0;
  const flaggedReviews = apiState.overview?.moderation?.flaggedReviews ?? 0;
  if (!apiState.connected) items.push({ title: 'Admin API chưa kết nối', meta: apiState.error ?? 'Dashboard chưa đọc được dữ liệu thật.', tone: 'hot' });
  if (errorTurns > 0) items.push({ title: `Có ${errorTurns} turn lỗi`, meta: 'Kiểm tra màn Conversations và Voice Operations để rà soát nguyên nhân.', tone: 'hot' });
  if (flaggedReviews > 0) items.push({ title: `${flaggedReviews} mục bị flagged`, meta: 'Có review mark đang cần xử lý ở voice hoặc conversations.', tone: 'warm' });
  if (suspendedUsers > 0) items.push({ title: `${suspendedUsers} user đang bị khóa`, meta: 'Voice backend sẽ chặn session mới cho các tài khoản này.', tone: 'warm' });
  if (unverifiedUsers > 0) items.push({ title: `${unverifiedUsers} user chưa verified`, meta: 'Đã có action verify trực tiếp ở màn Users.', tone: 'warm' });
  if (apiState.sessions.length === 0) items.push({ title: 'Chưa có dữ liệu voice gần đây', meta: 'Không có session nào được API trả về trong snapshot hiện tại.', tone: 'cool' });
  return items.slice(0, 5);
}

function buildHealthRows(apiState: AdminApiState): ReactNode[][] {
  const rows: ReactNode[][] = [];
  if (apiState.health) {
    rows.push(['Admin API', <StatusPill label={apiState.health.ok ? 'Operational' : 'Degraded'} />, apiState.health.version ?? 'unknown', `${apiState.health.latencyMs ?? 0}ms`, apiState.health.service ?? 'divie-admin-api']);
    const dependency = apiState.health.dependencies?.voiceBackend as { status?: number; body?: { version?: string } } | undefined;
    if (dependency) {
      rows.push(['Voice backend', <StatusPill label={dependency.status === 200 ? 'Operational' : 'Degraded'} />, dependency.body?.version ?? `HTTP ${dependency.status ?? '—'}`, 'live', 'chat.divie.site']);
    }
  }
  rows.push(['Admin session', <StatusPill label={apiState.connected ? 'Operational' : 'Review'} />, apiState.me?.authMode ?? 'unknown', '—', apiState.me?.role ?? 'viewer']);
  rows.push(['Database snapshot', <StatusPill label={apiState.users.length || apiState.sessions.length || apiState.conversations.length ? 'Operational' : 'Review'} />, `${apiState.users.length} users / ${apiState.sessions.length} sessions`, '—', 'postgres / supabase']);
  return rows;
}

function emptyRemoteState<T>(): RemoteState<T> {
  return { loading: false, items: [], count: 0, limit: PAGE_SIZE, offset: 0 };
}

function toRemoteState<T>(response: PaginatedResponse<T>): RemoteState<T> {
  return {
    loading: false,
    items: response.items,
    count: response.meta.count,
    limit: response.meta.limit,
    offset: response.meta.offset,
  };
}

interface Loadable<T> {
  loading: boolean;
  error?: string;
  item?: T;
}

function asMessage(error: unknown): string {
  return error instanceof Error ? error.message : 'Unknown error.';
}

function exportRowsAsCsv(name: string, headers: string[], rows: Array<Array<string | number | boolean | null | undefined>>): void {
  const escape = (value: string | number | boolean | null | undefined) => `"${String(value ?? '').replaceAll('"', '""')}"`;
  const csv = [headers.map(escape).join(','), ...rows.map((row) => row.map(escape).join(','))].join('\n');
  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = `${name}-${new Date().toISOString().slice(0, 10)}.csv`;
  link.click();
  URL.revokeObjectURL(url);
}

function normalizeSessionStatus(status?: string | null): string {
  if (!status) return 'Unknown';
  if (status === 'active') return 'Active';
  if (status === 'ended') return 'Ended';
  if (status === 'idle_timeout') return 'Idle timeout';
  return status;
}

function normalizeTurnStatus(status?: string | null): string {
  if (!status) return 'Unknown';
  if (status === 'completed') return 'Completed';
  if (status === 'processing') return 'Processing';
  if (status === 'error') return 'Error';
  if (status === 'interrupted') return 'Interrupted';
  return status;
}

function initials(value: string): string {
  return value.split(/\s+/u).filter(Boolean).slice(0, 2).map((part) => part[0]?.toUpperCase()).join('') || 'DV';
}

function trim(value: string, max: number): string {
  return value.length > max ? `${value.slice(0, max - 1)}…` : value;
}

function formatDate(value?: string | null): string {
  if (!value) return '—';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return '—';
  return new Intl.DateTimeFormat('vi-VN', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' }).format(date);
}

function formatNumber(value: number): string {
  return new Intl.NumberFormat('en-US').format(value);
}

createRoot(document.getElementById('root')!).render(<StrictMode><App /></StrictMode>);
