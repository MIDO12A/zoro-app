# Railway Deployment Guide

## 1. Push backend/ to GitHub
```bash
git add backend/
git commit -m "Add backend API"
git push
```

## 2. Connect Railway to GitHub
- افتح https://railway.app/dashboard
- New Project → Deploy from GitHub repo
- اختار repo بتاعك واختار backend/ كـ root directory

## 3. Add Environment Variables
في Railway Dashboard:
1. **القائمة الشمالية** → اضغط **Shared Variables**
2. هتلاقي صفحة فيها Variable Name و Variable Value
3. Add 3 متغيرات:

| Variable Name | Variable Value |
|---|---|
| `SUPABASE_URL` | `https://mbdrysnfohknqulevulif.supabase.co` |
| `SUPABASE_SERVICE_ROLE_KEY` | `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...` |
| `JWT_SECRET` | `zero-backend-jwt-secret-2026` |

**مهم:** Variable Name في الخانة الأولى، Variable Value في الخانة التانية.

## 4. Deploy
بعد adding variables، Railway هيعمل build و deploy تلقائي.

## 5. Update Flutter
بعد ما deploy يخلص، خد الـ URL اللي Railway يديّك (زي `https://backend.up.railway.app`)
وحطه في `lib/services/api_service.dart`:
```dart
String _baseUrl = 'https://backend.up.railway.app/api/v1';
```
