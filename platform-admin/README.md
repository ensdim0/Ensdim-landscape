# Ensdim Platform Admin

لوحة منفصلة لصاحب المنصة (مش لأدمن أي شركة) — لإضافة شركات جديدة، تعليق/تفعيل شركة، ومراجعة عدد مستخدمي كل شركة.

## التشغيل

```powershell
pnpm install
cp .env.example .env.local   # ثم حط VITE_SUPABASE_ANON_KEY
pnpm dev
```

## قبل أول استخدام

المستخدم اللي هتسجل دخول بيه لازم يكون عنده `is_platform_owner = true` في جدول `public.users`. شغّل في SQL Editor:

```sql
update public.users set is_platform_owner = true where email = 'your-login-email@example.com';
```

هذا المستخدم لازم يكون موجود بالفعل (مسجل دخول عادي في الداشبورد الأساسي مرة على الأقل) قبل ما تعمله platform owner.

## الاعتماديات الخلفية

- Migration: `dashboard/supabase/migrations/2026-07-22_super_admin.sql`
- Edge Function: `dashboard/supabase/functions/platform-create-company`
