# DiVie Landing Page — Tài liệu kỹ thuật

> Cập nhật: 2026-08-14  
> Phạm vi: `web/`

## 1. Kết luận nhanh

Project hiện **có landing page** trong thư mục `web/`. Đây là một ứng dụng React chạy trên Vite, dùng để giới thiệu sản phẩm DiVie, các vấn đề người cao tuổi gặp phải, nhóm tính năng, AI và công nghệ.

Landing page hiện là frontend tĩnh/stateless:

- Không có đăng nhập.
- Không có dashboard người dùng.
- Không có quản trị dữ liệu.
- Không thấy luồng gọi API backend trong source hiện tại.
- Nội dung đang được khai báo trong code tại `src/data/content.ts`.

Nói cách khác, đây là **website giới thiệu sản phẩm**, chưa phải web vận hành.

## 2. Công nghệ đang dùng

| Thành phần | Công nghệ |
|---|---|
| UI | React 19 |
| Ngôn ngữ | TypeScript |
| Build/dev server | Vite 8 |
| Icon | `@phosphor-icons/react` |
| Styling | CSS tự viết trong `src/index.css` và `src/App.css` |
| Hình ảnh | PNG, SVG nội bộ trong `src/assets` và `public/` |
| Kiểm tra | TypeScript build và Oxlint |

Package chính nằm tại [`web/package.json`](../web/package.json).

## 3. Cấu trúc source

```text
web/
├─ public/
│  ├─ characters/        # Minh họa người cao tuổi, người thân, bác sĩ, AI...
│  ├─ icons.svg           # Icon/asset dùng chung
│  └─ favicon.svg
├─ src/
│  ├─ assets/             # Hình ảnh build cùng frontend
│  ├─ components/         # Các section của landing page
│  ├─ data/content.ts     # Nội dung điều hướng, tính năng, công nghệ
│  ├─ App.tsx             # Ghép toàn bộ trang
│  ├─ App.css             # Style chính
│  ├─ index.css           # Style nền tảng/reset
│  └─ main.tsx             # Entry point
├─ index.html
├─ package.json
└─ vite.config.ts
```

## 4. Các section hiện có

`src/App.tsx` đang ghép các phần theo thứ tự:

1. `Header` — logo/điều hướng nội bộ.
2. `Hero` — thông điệp chính và CTA.
3. `ProblemSection` — các vấn đề của người cao tuổi và người thân.
4. `ResearchInsight` — insight/ngữ cảnh nghiên cứu.
5. `SolutionSection` — cách DiVie giải quyết vấn đề.
6. `FeatureBento` — nhóm tính năng chính.
7. `AiSection` — năng lực AI dự kiến.
8. `TechSection` — công nghệ sử dụng.
9. `FinalCta` — lời kêu gọi hành động cuối trang.
10. `Footer` — thông tin cuối trang.

Nội dung dùng chung được tách khỏi JSX tại [`src/data/content.ts`](../web/src/data/content.ts), giúp thay đổi copy mà không phải sửa nhiều component.

## 5. Luồng hoạt động

```text
Người dùng mở landing page
        ↓
Vite phục vụ static bundle
        ↓
React mount App
        ↓
Các component render theo thứ tự
        ↓
Người dùng cuộn trang hoặc bấm anchor CTA
```

Landing page không giữ session, không ghi dữ liệu và không phụ thuộc database.

## 6. Chạy local và kiểm tra

```powershell
cd web
npm ci
npm run dev
```

Kiểm tra trước khi bàn giao:

```powershell
npm run lint
npm run build
npm run preview
```

Build đầu ra nằm ở `web/dist/`, có thể triển khai trên Vercel hoặc một static host.

## 7. Trạng thái tích hợp backend

Hiện tại landing page chỉ mô tả các công nghệ và tính năng. Việc có chữ “web admin”, “API”, “Firebase”, “Groq” trong phần nội dung **không có nghĩa landing page đã kết nối tới các hệ thống đó**.

Nếu muốn CTA hoạt động thật, cần quyết định rõ từng nút:

| CTA | Hành vi đề xuất |
|---|---|
| Dùng thử app | Link tới trang tải app hoặc deep link |
| Liên hệ | Form gửi về backend/email hoặc mở kênh liên hệ |
| Tìm hiểu tính năng | Anchor tới section tương ứng |
| Đăng nhập quản trị | Link sang web admin sau khi web admin được xây dựng |

## 8. Việc còn thiếu để landing page sẵn sàng production

- Cấu hình title, description, Open Graph và favicon theo thương hiệu chính thức.
- Kiểm tra responsive ở màn hình điện thoại, tablet và desktop.
- Tối ưu kích thước ảnh, lazy-load ảnh ngoài vùng nhìn thấy.
- Bổ sung trạng thái focus/keyboard và alt text đầy đủ.
- Kiểm tra CTA không dẫn tới route giả hoặc nội dung chưa có.
- Gắn analytics/consent nếu cần đo chuyển đổi.
- Tách URL và thông tin liên hệ ra khỏi code nếu sau này có nhiều môi trường.

## 9. Định hướng bảo trì

- Nội dung marketing: sửa tại `src/data/content.ts`.
- Layout/section: sửa component tương ứng trong `src/components/`.
- Màu sắc, spacing, breakpoint: sửa trong `src/App.css` và `src/index.css`.
- Asset thương hiệu: quản lý tại `public/` hoặc `src/assets/`, không nhúng ảnh tạm từ máy cá nhân.
- Mọi thay đổi nên chạy `npm run lint` và `npm run build` trước khi deploy.

## 10. Liên quan

- Tổng quan toàn sản phẩm: [`TECHNICAL_OVERVIEW.md`](./TECHNICAL_OVERVIEW.md)
- Source landing page: [`../web/`](../web/)
- Admin API: [`ADMIN_WEB_AND_API_OVERVIEW.md`](./ADMIN_WEB_AND_API_OVERVIEW.md)
