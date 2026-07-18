// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:bustan_amari/core/theme/app_colors.dart';
import 'package:bustan_amari/domain/entities/contract.dart';
import 'package:bustan_amari/presentation/screens/client/payment_success_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentWebViewScreen extends StatefulWidget {
  final String paymentUrl;
  final String paymentId;
  final String paymentType;
  final String contractId;
  final double amount;

  const PaymentWebViewScreen({
    super.key,
    required this.paymentUrl,
    required this.paymentId,
    required this.paymentType,
    required this.contractId,
    required this.amount,
  });

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _paymentDone = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _isLoading = true),
        onPageFinished: (_) => setState(() => _isLoading = false),
        onWebResourceError: (_) => setState(() => _isLoading = false),
        onNavigationRequest: _onNavRequest,
      ))
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  // ── URL Interception ───────────────────────────────────────────────────────

  NavigationDecision _onNavRequest(NavigationRequest request) {
    if (_paymentDone) return NavigationDecision.prevent;

    final url = request.url.toLowerCase();
    final isReturn = url.contains('/payment/return');
    final isCancel = url.contains('/payment/cancel');

    if (!isReturn && !isCancel) return NavigationDecision.navigate;

    _paymentDone = true;
    final uri  = Uri.tryParse(request.url);
    final result  = uri?.queryParameters['result'] ?? '';
    final trackId = uri?.queryParameters['track_id'];

    debugPrint('[UPayments] redirect → result="$result" trackId=$trackId isReturn=$isReturn');

    // CAPTURED = UPayments success code, Y = 3DS sandbox success code
    final isSuccess = isReturn && {'captured', 'y'}.contains(result.toLowerCase());

    if (isSuccess) {
      _onPaymentSuccess(trackId: trackId, resultFromUrl: result);
    } else {
      final code = result.isNotEmpty ? result : (isCancel ? 'CANCELLED' : 'FAILED');
      _onPaymentFailed(code);
    }
    return NavigationDecision.prevent;
  }

  // ── Success Path ───────────────────────────────────────────────────────────

  Future<void> _onPaymentSuccess({String? trackId, String? resultFromUrl}) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    // Primary: verify-upayment edge function — marks paid AND notifies the
    // client + admins. Must be awaited and called first: if we mark the row
    // paid via a direct client-side update beforehand, verify-upayment's own
    // "already paid" idempotency check short-circuits before it ever sends
    // any notification.
    var verified = false;
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'verify-upayment',
        body: {
          'paymentId':    widget.paymentId,
          'paymentType':  widget.paymentType,
          if (trackId != null) 'trackId': trackId,
          if (resultFromUrl != null) 'resultFromUrl': resultFromUrl,
        },
      );
      final data = res.data as Map<String, dynamic>?;
      verified = data?['verified'] == true;
      debugPrint('[UPayments] verify-upayment → verified=$verified');
    } catch (e) {
      debugPrint('[UPayments] verify-upayment call error: $e');
    }

    // Fallback: only if the edge function call itself failed (e.g. network
    // error) — best-effort direct DB update so the client isn't stuck, but
    // no notification will fire in this rare case.
    if (!verified) {
      try {
        final table = widget.paymentType == 'standalone'
            ? 'standalone_task_payments'
            : 'contract_payments';
        final today = DateTime.now().toIso8601String().split('T')[0];
        await Supabase.instance.client
            .from(table)
            .update({
              'gateway_status': 'paid',
              'payment_method': 'gateway',
              'payment_date':   today,
              'due_date':       null,
            })
            .eq('id', widget.paymentId);
        debugPrint('[UPayments] fallback DB → gateway_status=paid');
      } catch (e) {
        debugPrint('[UPayments] fallback DB update error: $e');
      }
    }

    // Fetch payment & contract info for receipt
    String? receiptUrl, paymentDate, createdAt, dueDate, gatewayOrderId,
        gatewayPaymentMethod, contractCode, clientName, clientPhone, address,
        contractType, contractStartDate, contractEndDate;
    double? contractTotalValue, totalPaidAmount;
    ContractPalmInfo? palmInfo;

    try {
      final table = widget.paymentType == 'standalone'
          ? 'standalone_task_payments'
          : 'contract_payments';

      final payRow = await Supabase.instance.client
          .from(table)
          .select('receipt_url, payment_date, created_at, due_date, payment_gateway_order_id, gateway_payment_method')
          .eq('id', widget.paymentId)
          .maybeSingle();

      receiptUrl           = payRow?['receipt_url']?.toString();
      paymentDate          = payRow?['payment_date']?.toString();
      createdAt            = payRow?['created_at']?.toString();
      dueDate              = payRow?['due_date']?.toString();
      gatewayOrderId       = payRow?['payment_gateway_order_id']?.toString();
      gatewayPaymentMethod = payRow?['gateway_payment_method']?.toString();

      if (widget.paymentType != 'standalone') {
        // Fetch contract data + all payments + visits in parallel
        final results = await Future.wait<dynamic>([
          Supabase.instance.client
              .from('contracts_view')
              .select('code, client_name, client_phone, contract_user_name, contract_user_phone, '
                  'zone_id, block_number, street, avenue, house, address_details, '
                  'start_date, end_date, total_value, contract_type_id, palm_info')
              .eq('id', widget.contractId)
              .maybeSingle(),
          Supabase.instance.client
              .from('contract_payments')
              .select('amount, gateway_status, due_date')
              .eq('contract_id', widget.contractId),
          Supabase.instance.client
              .from('visits')
              .select('status')
              .eq('contract_id', widget.contractId),
        ]);

        final contractRow = results[0] as Map<String, dynamic>?;
        final allPayments = results[1] as List;
        final allVisits   = results[2] as List;

        int? totalVisitsCount;
        int  completedVisitsCount = 0;
        if (allVisits.isNotEmpty) {
          totalVisitsCount      = allVisits.length;
          completedVisitsCount  = allVisits.where((v) => (v as Map)['status'] == 'completed').length;
        }

        if (contractRow != null) {
          contractCode = contractRow['code']?.toString();

          // Prefer contract_user_name (manually entered), fall back to client_name (from users table via view)
          final contractUserName = contractRow['contract_user_name']?.toString().trim() ?? '';
          clientName = contractUserName.isNotEmpty
              ? contractUserName
              : contractRow['client_name']?.toString().trim();

          // Prefer contract_user_phone, fall back to client_phone (already in view via users join)
          final contractUserPhone = contractRow['contract_user_phone']?.toString().trim() ?? '';
          clientPhone = contractUserPhone.isNotEmpty
              ? contractUserPhone
              : contractRow['client_phone']?.toString().trim();
          contractStartDate  = contractRow['start_date']?.toString();
          contractEndDate    = contractRow['end_date']?.toString();
          contractTotalValue = (contractRow['total_value'] as num?)?.toDouble();

          if (contractRow['palm_info'] != null) {
            palmInfo = ContractPalmInfo.fromJson(contractRow['palm_info']);
          }

          // Fetch zone name + contract type name in parallel
          final typeId = contractRow['contract_type_id']?.toString();
          final zoneId = contractRow['zone_id']?.toString();

          final sideResults = await Future.wait<dynamic>([
            zoneId != null && zoneId.isNotEmpty
                ? Supabase.instance.client
                    .from('zones')
                    .select('name')
                    .eq('id', zoneId)
                    .maybeSingle()
                : Future<dynamic>.value(null),
            typeId != null && typeId.isNotEmpty
                ? Supabase.instance.client
                    .from('contract_types')
                    .select('name')
                    .eq('id', typeId)
                    .maybeSingle()
                : Future<dynamic>.value(null),
          ]);

          final zone = (sideResults[0] as Map?)?['name']?.toString();
          contractType = (sideResults[1] as Map?)?['name']?.toString();

          final parts = <String>[];
          final block = contractRow['block_number']?.toString();
          final st    = contractRow['street']?.toString();
          final av    = contractRow['avenue']?.toString();
          final hs    = contractRow['house']?.toString();
          final det   = contractRow['address_details']?.toString();
          if (zone?.isNotEmpty  == true) parts.add(zone!);
          if (block?.isNotEmpty == true) parts.add('قطعة $block');
          if (st?.isNotEmpty    == true) parts.add('شارع $st');
          if (av?.isNotEmpty    == true) parts.add('جادة $av');
          if (hs?.isNotEmpty    == true) parts.add('منزل $hs');
          if (parts.isEmpty && det != null) parts.add(det);
          address = parts.isNotEmpty ? parts.join('، ') : null;
        }

        // Compute total paid at this moment (snapshot)
        totalPaidAmount = allPayments
            .where((p) {
              final m = p as Map;
              return m['gateway_status'] == 'paid' ||
                  (m['gateway_status'] == null && m['due_date'] == null);
            })
            .fold<double>(0.0, (sum, p) => sum + (((p as Map)['amount'] as num?)?.toDouble() ?? 0.0));

        // ── Save frozen snapshot to DB ──────────────────────────────────────
        try {
          final pi = palmInfo;
          final snapshot = <String, dynamic>{
            if (contractType       != null) 'contractType':       contractType,
            if (contractStartDate  != null) 'contractStartDate':  contractStartDate,
            if (contractEndDate    != null) 'contractEndDate':    contractEndDate,
            if (contractTotalValue != null) 'contractTotalValue': contractTotalValue,
            'totalPaidAtTime':      totalPaidAmount,
            if (totalVisitsCount   != null) 'totalVisitsCount':   totalVisitsCount,
            'completedVisitsCount': completedVisitsCount,
            if (pi != null) 'palmInfo': {
              'isPalm':  pi.isPalm,
              'species': pi.species,
              'baladi': {
                'largeProductive':    pi.baladi.largeProductive,
                'largeNonProductive': pi.baladi.largeNonProductive,
                'smallProductive':    pi.baladi.smallProductive,
                'smallNonProductive': pi.baladi.smallNonProductive,
              },
              'washingtonia': {
                'largeProductive':    pi.washingtonia.largeProductive,
                'largeNonProductive': pi.washingtonia.largeNonProductive,
                'smallProductive':    pi.washingtonia.smallProductive,
                'smallNonProductive': pi.washingtonia.smallNonProductive,
              },
            },
          };
          await Supabase.instance.client
              .from('contract_payments')
              .update({'receipt_data': snapshot})
              .eq('id', widget.paymentId);
          debugPrint('[UPayments] receipt_data snapshot saved');
        } catch (e) {
          debugPrint('[UPayments] snapshot save error: $e');
        }
      }
    } catch (e) {
      debugPrint('[UPayments] receipt data error: $e');
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    // Use push (not pushReplacement) so the pop result propagates back to _openGateway
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PaymentSuccessScreen(
        paymentId:             widget.paymentId,
        paymentType:           widget.paymentType,
        contractId:            widget.contractId,
        amount:                widget.amount,
        receiptUrl:            receiptUrl,
        contractCode:          contractCode,
        clientName:            clientName,
        clientPhone:           clientPhone,
        address:               address,
        dueDate:               dueDate,
        paymentDate:           paymentDate,
        createdAt:             createdAt,
        paymentGatewayOrderId: gatewayOrderId,
        gatewayPaymentMethod:  gatewayPaymentMethod,
        contractType:          contractType,
        contractStartDate:     contractStartDate,
        contractEndDate:       contractEndDate,
        contractTotalValue:    contractTotalValue,
        totalPaidAmount:       totalPaidAmount,
        palmInfo:              palmInfo,
      ),
    ));
    // Pop WebView with true so _openGateway calls _reload()
    if (mounted) Navigator.of(context).pop(true);
  }

  // ── Failure Path ───────────────────────────────────────────────────────────

  void _onPaymentFailed(String resultCode) {
    if (!mounted) return;
    Navigator.of(context).pop(false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(_errorMessage(resultCode)),
      backgroundColor: Colors.red.shade700,
      duration: const Duration(seconds: 5),
    ));
  }

  static String _errorMessage(String code) {
    final c = code.trim().toUpperCase();
    if (c.contains('NOT_CAPTUR') || c.contains('NOTCAPTUR')) return 'لم يتم تأكيد الدفع — حاول مرة أخرى';
    if (c == 'N' || c.contains('NOT_AUTH') || c.contains('NOTAUTH'))  return 'فشل التحقق من البطاقة — حاول مرة أخرى';
    if (c == 'U')                                                       return 'التحقق من البطاقة غير متاح حالياً — حاول مرة أخرى';
    if (c == 'R' || c.contains('REJECT'))                              return 'رُفض التحقق من البطاقة — تواصل مع البنك';
    if (c == 'E' || c == 'AI')                                         return 'خطأ في بوابة الدفع — حاول مرة أخرى';
    if (c.contains('DECLIN') || c.contains('DO_NOT'))                  return 'رُفضت البطاقة من البنك — تواصل مع البنك';
    if (c.contains('INSUFFICIENT'))                                     return 'الرصيد غير كافٍ';
    if (c.contains('EXPIR'))                                            return 'انتهت صلاحية البطاقة';
    if (c.contains('INVALID'))                                          return 'بيانات البطاقة غير صحيحة';
    if (c.contains('CANCEL') || c == 'ABANDONED')                      return 'تم إلغاء عملية الدفع';
    if (c.contains('TIMEOUT') || c.contains('SESSION'))                return 'انتهت مهلة الجلسة — حاول مرة أخرى';
    if (c.contains('FAIL') || c.contains('ERROR'))                     return 'فشلت عملية الدفع — حاول مرة أخرى';
    return 'لم تكتمل عملية الدفع — يرجى المحاولة مجدداً';
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Row(children: [
          Image.asset(
            'assets/app_icon.png',
            width: 28,
            height: 28,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
          const SizedBox(width: 8),
          const Text(
            'بوابة الدفع',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ]),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('إلغاء الدفع'),
              content: const Text('هل تريد إلغاء عملية الدفع والعودة؟'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('لا'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('نعم، إلغاء'),
                ),
              ],
            ),
          ).then((confirmed) {
            if (confirmed == true && mounted) Navigator.of(context).pop(false);
          }),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () => _controller.reload(),
          ),
        ],
      ),
      body: Stack(children: [
        WebViewWidget(controller: _controller),
        if (_isLoading)
          Container(
            color: Colors.white.withValues(alpha: 0.85),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 12),
                  Text(
                    'جارٍ التحميل...',
                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
      ]),
    );
  }
}
