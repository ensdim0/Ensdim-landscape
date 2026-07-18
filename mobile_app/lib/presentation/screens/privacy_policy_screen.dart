// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

import 'package:bustan_amari/core/l10n/app_localizations.dart';
import 'package:bustan_amari/core/theme/app_colors.dart';
import 'package:bustan_amari/core/theme/app_dimensions.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final localeCode = Localizations.localeOf(context).languageCode;
    final isArabic = localeCode == 'ar';
    final t = AppLocalizations.of(context);
    final body = isArabic ? _arabicPrivacyPolicy : _englishPrivacyPolicy;
    final textDirection = isArabic ? TextDirection.rtl : TextDirection.ltr;

    return Scaffold(
      appBar: AppBar(title: Text(t.tr('privacyPolicy'))),
      body: Directionality(
        textDirection: textDirection,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.background,
                AppColors.primary50.withOpacity(0.45),
              ],
            ),
          ),
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.primary700.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Icon(
                          Icons.privacy_tip_outlined,
                          color: AppColors.primary700,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.tr('privacyPolicyTitle'),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              t.tr('privacyPolicyIntro'),
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.neutral200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    body,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.65,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const String _arabicPrivacyPolicy = '''
سياسة الخصوصية لشركة بستان أماري (Bustan Amari)

تعتبر خصوصية بياناتكم أولوية قصوى لنا في شركة بستان أماري. توضح هذه السياسة كيف نقوم بجمع واستخدام وحماية المعلومات الشخصية التي تقدمونها لنا عند استخدام منصاتنا الرقمية أو طلب خدماتنا.

1. المعلومات التي نجمعها
نقوم بجمع المعلومات الضرورية فقط لتقديم خدمات تنسيق وصيانة الحدائق بأفضل جودة، وتشمل:

المعلومات الشخصية: الاسم، رقم الهاتف، والبريد الإلكتروني.

معلومات الموقع: العنوان الجغرافي (للمنزل أو المزرعة) لتمكين فرقنا الفنية من الوصول إلى موقع التنفيذ.

معلومات الطلب: تفاصيل حول المساحات الخضراء، أنواع الأشجار أو التصاميم التي ترغبون بها.

البيانات التقنية: مثل عنوان IP ونوع الجهاز، لتحسين تجربة المستخدم على الموقع.

2. كيف نستخدم معلوماتكم
نستخدم هذه البيانات للأغراض التالية:

تنسيق المواعيد والزيارات الميدانية للمعاينة أو التنفيذ.

إرسال عروض الأسعار والفواتير والتقارير الدورية عن حالة الحديقة.

التواصل معكم بخصوص تحديثات الخدمة أو العروض الموسمية لشركة بستان أماري.

معالجة المدفوعات الإلكترونية عبر بوابات الدفع المعتمدة.

3. مشاركة البيانات مع طرف ثالث
نحن لا نقوم ببيع أو تأجير بياناتكم الشخصية لأي جهات خارجية. قد يتم مشاركة البيانات فقط في الحالات التالية:

مزودي الخدمات التقنية: مثل شركات استضافة الموقع أو بوابات الدفع (لغرض إتمام المعاملة فقط).

الجهات القانونية: إذا تطلب القانون الكويتي ذلك امتثالاً للأنظمة واللوائح.

4. حماية البيانات
نلتزم بتطبيق معايير أمنية عالية لحماية بياناتكم من الوصول غير المصرح به أو التعديل أو الإفصاح. يتم تشفير المعلومات الحساسة (مثل بيانات الدفع) عبر بروتوكولات آمنة (SSL).

5. سياسة ملفات تعريف الارتباط (Cookies)
نستخدم ملفات تعريف الارتباط لتحليل حركة المرور على الموقع وفهم تفضيلات العملاء، مما يساعدنا في تطوير تصاميمنا وخدماتنا الزراعية بما يتناسب مع احتياجاتكم.

6. حقوق العميل
بصفتكم عملاء لشركة بستان أماري، يحق لكم:

طلب الوصول إلى بياناتكم الشخصية الموجودة لدينا.

تصحيح أي معلومات غير دقيقة أو تحديثها (مثل تغيير رقم الهاتف أو العنوان).

إيقاف استقبال الرسائل التسويقية في أي وقت عبر النقر على "إلغاء الاشتراك".

7. التعديلات على السياسة
قد نقوم بتحديث سياسة الخصوصية هذه من وقت لآخر لتعكس التغييرات في ممارساتنا أو القوانين المحلية. سيتم نشر أي تحديثات فوراً على هذه الصفحة.

8. التواصل معنا
إذا كان لديكم أي استفسار حول سياسة الخصوصية أو كيفية التعامل مع بياناتكم، يرجى التواصل مع فريق خدمة العملاء:

الموقع: الكويت.

البريد الإلكتروني: info@bustanamary.com

الواتساب/الهاتف: 96599423149
''';

const String _englishPrivacyPolicy = '''
Privacy Policy of Bustan Amari

Your privacy is a top priority at Bustan Amari. This policy explains how we collect, use, and protect the personal information you provide when using our digital platforms or requesting our services.

1. Information We Collect
We collect only the information needed to deliver garden design and maintenance services with the best quality, including:

Personal information: name, phone number, and email address.

Location information: the geographic address (home or farm) so our technical teams can reach the execution site.

Order information: details about green spaces, tree types, or designs you want.

Technical data: such as IP address and device type, to improve the user experience on the website.

2. How We Use Your Information
We use this data for the following purposes:

Scheduling appointments and on-site visits for inspection or execution.

Sending quotations, invoices, and periodic reports about the status of the garden.

Contacting you about service updates or seasonal offers from Bustan Amari.

Processing online payments through approved payment gateways.

3. Sharing Data With Third Parties
We do not sell or rent your personal data to any external party. Data may be shared only in the following cases:

Technical service providers: such as hosting companies or payment gateways, strictly for completing the transaction.

Legal authorities: if required under Kuwaiti law and applicable regulations.

4. Data Protection
We apply high security standards to protect your data from unauthorized access, alteration, or disclosure. Sensitive information, such as payment data, is encrypted using secure protocols (SSL).

5. Cookies Policy
We use cookies to analyze website traffic and understand customer preferences, helping us improve our designs and landscaping services to match your needs.

6. Customer Rights
As a Bustan Amari customer, you have the right to:

Request access to your personal data stored with us.

Correct inaccurate information or update it, such as changing your phone number or address.

Stop receiving marketing messages at any time by clicking "Unsubscribe".

7. Policy Updates
We may update this privacy policy from time to time to reflect changes in our practices or local laws. Any updates will be posted on this page immediately.

8. Contact Us
If you have any questions about this privacy policy or how your data is handled, please contact our customer service team:

Location: Kuwait.

Email: info@bustanamary.com

WhatsApp/Phone: +96599423149
''';
