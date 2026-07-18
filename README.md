# دليل العميل - مشروع بستان أماري

هذا الملف موجّه للعميل، وبيشرح ازاي تنزّل المشروع وتشغّله من غير خبرة برمجية عميقة.

## المشروع بيتكون من ايه

- **dashboard/** — لوحة تحكم (ويب) مبنية بـ React + Vite، وده اللي بيستخدمه الأدمن/المشرف من المتصفح.
- **mobile_app/** — تطبيق موبايل مبني بـ Flutter (شغّال بشكل أساسي على أندرويد).
- **key.md** — ملف فيه أوامر جاهزة (نسخ ولزق) لتشغيل تطبيق الموبايل بمفاتيح Supabase الحقيقية.

## 1) المتطلبات قبل ما تبدأ

لازم تكون مثبت على جهازك:

| الأداة | الاستخدام | الرابط |
|---|---|---|
| Git | تحميل المشروع من الريبو | https://git-scm.com/downloads |
| Node.js (نسخة 20 أو أحدث) | تشغيل الداشبورد | https://nodejs.org |
| pnpm | مدير الحزم بتاع الداشبورد | `npm install -g pnpm` |
| Flutter SDK | تشغيل/بناء تطبيق الموبايل | https://docs.flutter.dev/get-started/install |
| Android Studio | لعمل بيلد لتطبيق أندرويد | https://developer.android.com/studio |

> لو مش هتلمس تطبيق الموبايل، تقدر تتجاهل Flutter/Android Studio وتكتفي بـ Node.js وpnpm بس.

## 2) تحميل المشروع (Clone)

```powershell
git clone <رابط الريبو الخاص بتاعكم>
cd bostanAmary
```

(الريبو **خاص Private** — محتاج تكون معاك صلاحية وصول عليه من GitHub الأول).

## 3) تشغيل لوحة التحكم (Dashboard)

```powershell
cd dashboard
pnpm install
pnpm dev
```

بعد كده هتفتح المتصفح على:

```
http://localhost:5173
```

ملف `dashboard/.env` موجود بالفعل ومظبوط بمفاتيح Supabase الحقيقية، يعني مش محتاج تعمل أي إعداد إضافي عشان تجرب الداشبورد محليًا.

### عمل نسخة إنتاج (Build) للداشبورد

```powershell
pnpm build      # بيطلع الملفات الجاهزة في مجلد dist/
pnpm preview    # لو حابب تجرب نسخة الإنتاج محليًا قبل الرفع
```

### النشر (Deployment)

الداشبورد مظبوط للنشر على **Vercel** (فيه ملف `vercel.json` جاهز بإعدادات الأمان والـ headers). لو الحساب مربوط بالفعل، أي `git push` أو نشر يدوي من Vercel هيكفي.

## 4) تشغيل تطبيق الموبايل (Flutter)

```powershell
cd mobile_app
flutter pub get
```

بعدها شغّل التطبيق بالأمر ده (موجود جاهز كمان في ملف `key.md` بالروت — انسخه ولزقه زي ما هو):

```powershell
flutter run --dart-define=SUPABASE_URL=https://fazohdqthhktvpzlglue.supabase.co --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZhem9oZHF0aGhrdHZwemxnbHVlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA0MDEzNTIsImV4cCI6MjA4NTk3NzM1Mn0.PQ5Jmg4c-J9f2Xhk24Q86tHlajrbYMxzedJXK7MgY8c
```

> لازم يكون عندك جهاز أندرويد متوصل (أو محاكي/Emulator شغّال) قبل ما تنفذ الأمر ده.

### عمل ملف APK لتجربته على أي جهاز أندرويد بدون كمبيوتر

```powershell
flutter build apk --release --dart-define=SUPABASE_URL=https://fazohdqthhktvpzlglue.supabase.co --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZhem9oZHF0aGhrdHZwemxnbHVlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA0MDEzNTIsImV4cCI6MjA4NTk3NzM1Mn0.PQ5Jmg4c-J9f2Xhk24Q86tHlajrbYMxzedJXK7MgY8c
```

الملف الناتج (اللي بتنزّله على أي موبايل أندرويد) هيتحط هنا:

```
mobile_app/build/app/outputs/flutter-apk/app-release.apk
```

### رفعه على جوجل بلاي (Play Store)

الخطوات التفصيلية موجودة في `mobile_app/PLAY_STORE_RELEASE.md`.

## 5) ملاحظات أمان مهمة

- ملف `key.md` وملف `dashboard/.env` فيهم مفاتيح Supabase **الحقيقية** بتاعة المشروع. الريبو خاص (Private) عشان كده، **متشاركش الرابط أو محتوى الملفين دول مع حد برة الفريق**.
- المفتاح الموجود هو `ANON KEY` (مفتاح عام محدود الصلاحيات حسب قواعد RLS)، مفيش مفتاح Service Role في أي حتة بالكود — ودا مقصود عشان الأمان.
- لو حصل وغيّرتوا أي مفتاح من لوحة تحكم Supabase (rotate)، لازم تحدّثوا نفس المفتاح الجديد في:
  - `dashboard/.env`
  - الأوامر الموجودة في `key.md`

## 6) هيكل المشروع باختصار

```
bostanAmary/
├── dashboard/     لوحة تحكم الأدمن/المشرف (ويب)
├── mobile_app/    تطبيق الموبايل (Flutter)
├── key.md         أوامر تشغيل جاهزة فيها مفاتيح Supabase
└── scripts/       سكريبتات مساعدة للمطورين
```
