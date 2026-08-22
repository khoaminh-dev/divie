# DiVie Admin Web

Bản mã nguồn cục bộ của giao diện quản trị DiVie, được lấy từ deployment production của project Vercel `divie-admin`.

## Nguồn snapshot

- Project Vercel: `divie-admin`
- Production URL: `https://admin.divie.site`
- Deployment: `divie-admin-5j6lgg06p-khoaminh-devs-projects.vercel.app`
- Commit/nhánh deployment: `939475f6cc455126b4ddc11b1f364887d2c6a603` / `feature/rbac-role-and-app-management`
- Repository gốc được Vercel ghi nhận: `DIVIE-PRODUCT/divie-admin`
- Thời điểm lấy về: 2026-08-16

## Cấu trúc chính

- `src/`: mã nguồn React/Vite, API client, Supabase client và style
- `public/`: tài nguyên public
- `dist/`: bản build đã được deployment sử dụng
- `deploy/`: cấu hình triển khai VPS/Traefik
- `Dockerfile`, `nginx.conf`, `vercel.json`: cấu hình build và hosting
- `.env.example`: danh sách biến môi trường mẫu

## Chạy local

```powershell
cd C:\workspace\khachhang\dieu_1\admin-web
npm ci
npm run dev
```

Không chép giá trị bí mật thật vào Git. Dùng `.env.local` khi chạy local và lấy biến môi trường từ Vercel/VPS theo đúng quyền truy cập.
