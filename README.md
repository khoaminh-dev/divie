# DiVie workspace

Monorepo workspace for DiVie.

## Structure

- `web/` — DiVie landing page (Vite + React + TypeScript)
- `app/` — DiVie mobile application (Flutter)
- `docs/` — product and technical documentation

## Web

```powershell
cd web
npm install
npm run dev
```

## App

```powershell
cd app
flutter pub get
flutter run
```

## Checks

```powershell
cd web
npm run build

cd ..\app
flutter analyze
```
