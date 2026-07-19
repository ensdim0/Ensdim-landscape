# Ensdim Landscape System (Dashboard)

## 1) Architecture Explanation
المشروع مبني على Clean Architecture + DDD لضمان قابلية التوسع بدون إعادة كتابة. تدفق الاعتماد يكون من Presentation → Application → Domain → Infrastructure. جميع الداتا تمر عبر Use Cases ولا يوجد اتصال مباشر بين الواجهة وSupabase.

- **Domain Layer**: تعريف الكيانات وقواعد العمل وواجهات المستودعات.
- **Application Layer**: حالات الاستخدام (Use Cases) + DTOs + Validation + قواعد الصلاحيات.
- **Infrastructure Layer**: تكامل Supabase وتنفيذ المستودعات ورفع الملفات.
- **Presentation Layer**: الصفحات والمكونات وإدارة الحالة والـ routing.
- **Core / Shared**: أخطاء مركزية، إعدادات، أدوات مشتركة.

## 2) Folder Structure
- core/: إعدادات و logging وأخطاء مشتركة.
- domain/: الكيانات وقواعد العمل وواجهات المستودعات.
- application/: حالات الاستخدام و DTOs والتحقق.
- infrastructure/: عميل Supabase وتنفيذ المستودعات.
- presentation/: صفحات ومكونات وإدارة حالة.
- shared/: ثوابت وأدوات مشتركة.
- supabase/: SQL للـ schema و RLS و seed.

## 3) Database Schema
راجع [supabase/schema.sql](supabase/schema.sql) لتفاصيل الجداول والعلاقات والمؤشرات وSoft Delete وTimestamps.

الجداول الأساسية:
- users, roles, user_roles
- clients, supervisors
- geographic_lines, zones, blocks
- contracts, assets, assignments
- visits, reports
- invoices, payments
- audit_logs

## 4) Supabase RLS Policies
كل السياسات موجودة في [supabase/rls.sql](supabase/rls.sql). تشمل صلاحيات Admin/Supervisor/Client على مستوى الصفوف لكل جدول.

أمثلة حقيقية:
- Admin يمكنه التحكم الكامل في العقود والفواتير.
- Supervisor يرى الخطوط والمناطق والقطع والعقود المعيّنة له فقط ويمكنه تسجيل الزيارات والتقارير.
- Client يرى عقوده وفواتيره فقط.

## 5) Core Use Cases
- Admin: إدارة المستخدمين، إنشاء العقود، إدارة الفواتير.
- Supervisor: رؤية العقود المخصصة، تسجيل زيارة، رفع صور، إرسال تقرير.
- Client: عرض العقود والفواتير.

## 6) API / Data Flow
1. الواجهة تستدعي Use Case في Application.
2. الـ Use Case يتحقق من البيانات والصلاحيات.
3. تنفيذ المستودع في Infrastructure يستدعي Supabase.
4. الاستجابة تعود كـ Result مع أخطاء مركزية.

## 7) MVP Roadmap (Phase 1)
- مصادقة المستخدمين وربط الأدوار.
- إدارة الخطوط والمناطق والمناطق والقطع وربط العقود بها.
- تعيين المشرفين وجدولة الزيارات.
- إدارة الفواتير والتحصيل.
- تقارير الزيارات الأساسية.

## 8) نقاط ضعف محتملة + حلول
- **تضارب الصلاحيات**: حل عبر اختبار RLS وتغطية Use Cases بقواعد ثابتة.
- **ازدحام الأداء**: إضافة indexes + pagination + caching.
- **بيانات ناقصة**: Validation صارم قبل أي كتابة.
- **أمان الملفات**: سياسات Storage مع مسارات حسب الدور.

## تشغيل المشروع محلياً
1. أنشئ ملف .env من [.env.example](.env.example).
2. شغّل Vite عبر `npm run dev` بعد تثبيت الاعتمادات.

## ملاحظات أمنية
- لا تستخدم مفتاح Service Role في الواجهة.
- احفظ مفاتيح Supabase في متغيرات البيئة فقط.
