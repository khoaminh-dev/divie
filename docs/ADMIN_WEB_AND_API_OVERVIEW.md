# DiVie Web Admin và Admin API — Tài liệu hiện trạng

> Cập nhật: 2026-08-14  
> Phạm vi chính: `backend-source/admin-api/`

## 1. Kết luận quan trọng

Trong workspace hiện tại:

- **Đã có Admin API backend**.
- **Chưa có source giao diện Web Admin riêng** để đăng nhập và thao tác trên trình duyệt.
- Chưa thấy package frontend, route UI, HTML/React app hoặc thư mục `admin-web`/`dashboard` tương ứng.
- Landing page tại `web/` chỉ giới thiệu sản phẩm; không phải giao diện quản trị.

Trạng thái chính xác là:

```text
Landing page: có
Admin API: có
Web Admin UI: chưa có trong workspace hiện tại
```

Không nên gọi hệ thống hiện tại là “đã có web admin hoàn chỉnh”. Backend đã chuẩn bị khá nhiều năng lực, nhưng còn thiếu lớp giao diện để nhân sự vận hành sử dụng.

## 2. Vị trí và cấu trúc Admin API

```text
backend-source/admin-api/
├─ src/
│  ├─ index.ts                 # HTTP server và route API
│  ├─ config.ts                # Biến môi trường
│  ├─ auth/
│  │  ├─ adminAuth.ts           # Xác thực và vai trò admin
│  │  └─ jwt.ts                 # Kiểm tra JWT
│  ├─ db/
│  │  ├─ postgres.ts            # Kết nối PostgreSQL
│  │  └─ supabaseRest.ts        # Fallback qua Supabase REST
│  ├─ repositories/
│  │  └─ adminRepository.ts     # Truy vấn dữ liệu và audit
│  ├─ services/
│  │  └─ healthService.ts       # Kiểm tra sức khỏe hệ thống
│  └─ http/respond.ts            # Chuẩn hóa response
├─ db/migrations/               # Schema và RLS liên quan
├─ deploy/vps/                  # Docker/Traefik trên VPS
├─ Dockerfile
├─ package.json
└─ .env.example
```

## 3. Công nghệ Admin API

| Thành phần | Công nghệ |
|---|---|
| Runtime | Node.js 22+ |
| Ngôn ngữ | TypeScript |
| HTTP server | `node:http` |
| Database | PostgreSQL/Supabase |
| Kết nối DB | `pg` và Supabase REST |
| Validation/config | `zod`, `dotenv` |
| Logging | `pino` |
| Đóng gói | Docker |
| Reverse proxy | Traefik trên VPS |
| CI/CD | GitHub Actions build/deploy |

Package nguồn: [`backend-source/admin-api/package.json`](../backend-source/admin-api/package.json).

## 4. Các nhóm chức năng backend đã có

### 4.1. Xác thực và tổng quan

| Endpoint | Chức năng | Quyền tối thiểu |
|---|---|---|
| `GET /health` | Health check không yêu cầu admin | Không yêu cầu |
| `GET /api/admin/health` | Kiểm tra sức khỏe cho admin | Viewer |
| `GET /api/admin/me` | Lấy thông tin admin hiện tại | Viewer |
| `GET /api/admin/overview` | Tổng quan hệ thống | Viewer |

### 4.2. Người dùng

| Endpoint | Chức năng | Quyền |
|---|---|---|
| `GET /api/admin/users` | Danh sách người dùng, lọc/phân trang | Viewer |
| `GET /api/admin/users/:id` | Chi tiết người dùng | Viewer |
| `PATCH /api/admin/users/:id/verification` | Cập nhật xác minh | Admin |
| `PATCH /api/admin/users/:id/plan` | Cập nhật gói sử dụng | Admin |
| `PATCH /api/admin/users/:id/role` | Cập nhật role user/admin | Admin |
| `PATCH /api/admin/users/:id/moderation` | Khóa/mở hoặc ghi nhận moderation | Support |

### 4.3. Voice và AI review

| Endpoint | Chức năng | Quyền |
|---|---|---|
| `GET /api/admin/voice/sessions` | Danh sách phiên voice | Viewer |
| `GET /api/admin/voice/sessions/:id` | Chi tiết phiên voice | Viewer |
| `PATCH /api/admin/voice/sessions/:id/review` | Đánh dấu/review phiên | Support |

### 4.4. Chat và nội dung người dùng

| Endpoint | Chức năng | Quyền |
|---|---|---|
| `GET /api/admin/conversations` | Danh sách hội thoại | Viewer |
| `GET /api/admin/conversations/:id` | Chi tiết hội thoại | Viewer |
| `PATCH /api/admin/conversations/:id/review` | Review hội thoại | Support |
| `GET /api/admin/chat/rooms` | Danh sách phòng chat | Viewer |
| `GET /api/admin/chat/rooms/:id` | Chi tiết phòng chat | Viewer |
| `DELETE /api/admin/chat/messages/:id` | Xóa mềm tin nhắn vi phạm | Support |

### 4.5. Dữ liệu sức khỏe và audit

| Endpoint | Chức năng | Quyền |
|---|---|---|
| `GET /api/admin/health-measurements` | Danh sách chỉ số sức khỏe | Viewer |
| `GET /api/admin/health-measurements/:id` | Chi tiết chỉ số | Viewer |
| `GET /api/admin/audit-logs` | Nhật ký thao tác quản trị | Admin |

Các route trên được khai báo trực tiếp trong [`src/index.ts`](../backend-source/admin-api/src/index.ts).

## 5. Mô hình quyền

Admin API đang dùng bốn vai trò:

```text
viewer  <  support  <  admin  <  owner
```

- `viewer`: xem dữ liệu và tổng quan.
- `support`: xử lý hỗ trợ, moderation và review nội dung.
- `admin`: quản lý người dùng, gói, role và audit.
- `owner`: quyền cao nhất.

Cơ chế xác thực hiện hỗ trợ:

1. Bearer token bootstrap qua `ADMIN_API_TOKEN`.
2. Hoặc Supabase JWT HS256.
3. Sau khi xác minh JWT, hệ thống tra bảng `viegrand_admin_members` để kiểm tra thành viên còn hoạt động và role.

## 6. Luồng dự kiến khi có Web Admin UI

```text
Admin mở web admin
        ↓
Đăng nhập qua Supabase/Auth flow
        ↓
Frontend giữ access token ngắn hạn
        ↓
Gọi Admin API với Authorization: Bearer <token>
        ↓
API kiểm tra JWT + admin membership + minimum role
        ↓
Repository đọc/ghi PostgreSQL hoặc Supabase
        ↓
Thao tác nhạy cảm ghi audit log
```

## 7. Web Admin UI cần xây dựng

Đề xuất tạo app riêng, ví dụ:

```text
admin-web/
├─ src/
│  ├─ app/                  # route và layout
│  ├─ auth/                 # login, session, route guard
│  ├─ api/                  # typed API client
│  ├─ features/
│  │  ├─ overview/
│  │  ├─ users/
│  │  ├─ voice-sessions/
│  │  ├─ conversations/
│  │  ├─ health-measurements/
│  │  ├─ chat-moderation/
│  │  └─ audit-logs/
│  ├─ components/           # table, drawer, modal, badge, pagination
│  └─ styles/
├─ package.json
└─ vite.config.ts
```

Các màn hình nên có theo thứ tự ưu tiên:

1. Đăng nhập và bảo vệ route.
2. Tổng quan hệ thống.
3. Người dùng: tìm kiếm, lọc, xem chi tiết, cập nhật trạng thái.
4. Voice session: xem phiên, review và ghi chú.
5. Chat moderation: xem phòng, xem tin nhắn, xử lý tin vi phạm.
6. Chỉ số sức khỏe: tra cứu và xem chi tiết, hạn chế hiển thị dữ liệu nhạy cảm.
7. Audit logs: chỉ mở cho admin/owner.
8. System health: tình trạng API, database, voice backend và queue nếu có.

## 8. Nguyên tắc UX cho Web Admin

- Một layout cố định: sidebar trái, header ngắn, nội dung toàn chiều rộng.
- Bảng có tìm kiếm, lọc, phân trang và trạng thái rõ ràng.
- Chi tiết mở bằng drawer hoặc route detail, không làm người dùng mất ngữ cảnh.
- Thao tác nhạy cảm phải có xác nhận và lý do.
- Luôn hiển thị “ai thao tác”, “thời điểm nào”, “đối tượng nào”.
- Ẩn các hành động người dùng không đủ quyền, không chỉ disable sau khi bấm.
- Không đưa dữ liệu sức khỏe hoặc nội dung chat nhạy cảm lên dashboard tổng quan nếu chưa cần.

## 9. Cấu hình và triển khai API

Cấu hình mẫu: [`backend-source/admin-api/.env.example`](../backend-source/admin-api/.env.example).

Các biến quan trọng:

- `PORT`, `HOST`, `NODE_ENV`.
- `CORS_ORIGIN` — production phải giới hạn về domain web admin thật.
- `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`.
- `SUPABASE_JWT_SECRET`.
- `ADMIN_API_TOKEN` — chỉ dùng bootstrap/khẩn cấp và không commit vào Git.
- `DATABASE_URL` hoặc nhóm `PG*`.
- `VOICE_BACKEND_URL`.

API có Dockerfile và manifest VPS/Traefik tại `deploy/vps/`. Domain mẫu trong manifest hiện là `admin.viegrand.site`; cần xác nhận domain production trước khi triển khai giao diện.

## 10. Trạng thái hiện tại và khoảng trống

### Đã có

- Admin API chạy bằng Node.js/TypeScript.
- Phân quyền theo role.
- Kết nối PostgreSQL/Supabase.
- Các nhóm API users, voice, chat, health, audit.
- Docker và cấu hình reverse proxy.
- Audit log cho các thao tác quản trị chính.

### Chưa có hoặc cần xác nhận

- Web Admin UI chính thức.
- Flow đăng nhập admin ở frontend.
- Typed API client dùng chung cho UI.
- OpenAPI/Swagger contract công khai cho Admin API.
- Test end-to-end từ trình duyệt đến database.
- Rate limit và policy CORS production cụ thể.
- Monitoring/alerting cho API và các thao tác thất bại.
- Quy trình backup/restore và phân loại dữ liệu nhạy cảm.

## 11. Kế hoạch triển khai hợp lý

### Giai đoạn 1 — Khóa hợp đồng backend

- Chốt response/error schema.
- Chốt pagination, filter, sort.
- Viết OpenAPI cho tất cả route.
- Viết test auth và role matrix.

### Giai đoạn 2 — Xây Web Admin tối thiểu

- Login + route guard.
- Overview.
- Users list/detail.
- Audit log.
- Loading, empty, error và permission states.

### Giai đoạn 3 — Bổ sung nghiệp vụ vận hành

- Voice review.
- Chat moderation.
- Health measurements.
- System health.

### Giai đoạn 4 — Production hardening

- Giới hạn CORS.
- Không dùng token bootstrap thường xuyên.
- Bổ sung rate limit, monitoring, alerting.
- Test backup/restore.
- Kiểm tra quyền theo từng role bằng E2E test.

## 12. Liên quan

- Landing page: [`LANDING_PAGE_TECHNICAL_OVERVIEW.md`](./LANDING_PAGE_TECHNICAL_OVERVIEW.md)
- Tổng quan toàn sản phẩm: [`TECHNICAL_OVERVIEW.md`](./TECHNICAL_OVERVIEW.md)
- Admin API source: [`../backend-source/admin-api/`](../backend-source/admin-api/)
