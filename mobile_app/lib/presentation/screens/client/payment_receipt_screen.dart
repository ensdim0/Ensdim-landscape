// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

import 'package:bustan_amari/core/theme/app_colors.dart';
import 'package:bustan_amari/core/utils/date_formatter.dart' as date_fmt;
import 'package:bustan_amari/domain/entities/contract.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _kGreen      = AppColors.primary;
const _kGreenDark  = Color(0xFF1F5C3C);
const _kOrange     = Color(0xFFE8A020);
const _kCream      = Color(0xFFF7F3EE);
const _kBorder     = Color(0xFFDDD8D0);
const _kGreenLight = Color(0xFFEAF4EE);
const _kRowAlt     = Color(0xFFF5FAF6);

class PaymentReceiptScreen extends StatefulWidget {
  final String paymentId;
  final String paymentType;
  final String contractId;
  final double amount;
  final String? receiptUrl;
  final String? contractCode;
  final String? clientName;
  final String? clientPhone;
  final String? address;
  final String? dueDate;
  final String? paymentDate;
  final String? createdAt;
  final String? paymentGatewayOrderId;
  final String? gatewayPaymentMethod;

  // ── new fields ──
  final String? contractType;
  final String? contractStartDate;
  final String? contractEndDate;
  final double? contractTotalValue;
  final double? totalPaidAmount;
  final int? totalVisitsCount;
  final int? completedVisitsCount;
  final ContractPalmInfo? palmInfo;

  const PaymentReceiptScreen({
    super.key,
    required this.paymentId,
    required this.paymentType,
    required this.contractId,
    required this.amount,
    this.receiptUrl,
    this.contractCode,
    this.clientName,
    this.clientPhone,
    this.address,
    this.dueDate,
    this.paymentDate,
    this.createdAt,
    this.paymentGatewayOrderId,
    this.gatewayPaymentMethod,
    this.contractType,
    this.contractStartDate,
    this.contractEndDate,
    this.contractTotalValue,
    this.totalPaidAmount,
    this.totalVisitsCount,
    this.completedVisitsCount,
    this.palmInfo,
  });

  @override
  State<PaymentReceiptScreen> createState() => _PaymentReceiptScreenState();
}

class _PaymentReceiptScreenState extends State<PaymentReceiptScreen> {
  final _screenshotController = ScreenshotController();
  bool _saving = false;
  bool _sharing = false;

  String get _formattedAmount => '${widget.amount.toStringAsFixed(3)} د.ك';

  String get _todayFormatted {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2,'0')}/${now.month.toString().padLeft(2,'0')}/${now.year}';
  }

  String? _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final dt = DateTime.parse(raw.replaceFirst(' ', 'T'));
      return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}';
    } catch (_) {
      final parts = raw.split(RegExp(r'[-/T ]'));
      if (parts.length >= 3) return '${parts[2]}/${parts[1]}/${parts[0]}';
      return raw;
    }
  }

  String? _parseDateTime(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final dt = DateTime.parse(raw.replaceFirst(' ', 'T')).toLocal();
      return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year} - ${date_fmt.formatTime(dt)}';
    } catch (_) {
      return _parseDate(raw);
    }
  }

  Future<Uint8List?> _capture() async {
    try {
      return await _screenshotController.capture(pixelRatio: 2.5);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveToGallery() async {
    setState(() => _saving = true);
    try {
      final bytes = await _capture();
      if (bytes == null) { _showSnack('فشل التقاط الفاتورة'); return; }
      final result = await ImageGallerySaverPlus.saveImage(
        bytes, quality: 95, name: 'receipt_${widget.paymentId}',
      );
      final ok = result != null && result['isSuccess'] == true;
      _showSnack(ok ? 'تم حفظ الفاتورة في المعرض ✓' : 'فشل الحفظ في المعرض');
      if (ok) await _uploadReceiptIfNeeded(bytes);
    } catch (_) {
      _showSnack('حدث خطأ أثناء الحفظ');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      final bytes = await _capture();
      if (bytes == null) { _showSnack('فشل التقاط الفاتورة'); return; }
      final dir  = await getTemporaryDirectory();
      final file = File('${dir.path}/receipt_${widget.paymentId}.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: 'فاتورة دفع إلكترونية - $_formattedAmount',
      );
      await _uploadReceiptIfNeeded(bytes);
    } catch (_) {
      _showSnack('حدث خطأ أثناء المشاركة');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _uploadReceiptIfNeeded(Uint8List bytes) async {
    if (widget.receiptUrl != null && widget.receiptUrl!.isNotEmpty) return;
    try {
      final path = '${widget.paymentId}/receipt.png';
      await Supabase.instance.client.storage
          .from('payment-receipts')
          .uploadBinary(path, bytes,
              fileOptions: const FileOptions(contentType: 'image/png', upsert: true));
      final url = await Supabase.instance.client.storage
          .from('payment-receipts')
          .createSignedUrl(path, 60 * 60 * 24 * 365);
      final table = widget.paymentType == 'standalone'
          ? 'standalone_task_payments'
          : 'contract_payments';
      await Supabase.instance.client
          .from(table)
          .update({'receipt_url': url}).eq('id', widget.paymentId);
    } catch (_) {}
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _copyOrderId() {
    final id = widget.paymentGatewayOrderId;
    if (id == null || id.isEmpty) return;
    Clipboard.setData(ClipboardData(text: id));
    _showSnack('تم نسخ رقم المعاملة ✓');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kCream,
      appBar: AppBar(
        backgroundColor: _kGreen,
        foregroundColor: Colors.white,
        title: const Text(
          'الفاتورة الإلكترونية',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const SizedBox(height: 4),
                  Screenshot(
                    controller: _screenshotController,
                    child: _InvoiceCard(
                      paymentId:             widget.paymentId,
                      amount:                widget.amount,
                      contractCode:          widget.contractCode,
                      clientName:            widget.clientName,
                      clientPhone:           widget.clientPhone,
                      address:               widget.address,
                      dueDate:               _parseDate(widget.dueDate),
                      paymentDate:           _parseDateTime(widget.createdAt) ?? _parseDate(widget.paymentDate) ?? _todayFormatted,
                      gatewayOrderId:        widget.paymentGatewayOrderId,
                      gatewayPaymentMethod:  widget.gatewayPaymentMethod,
                      contractType:          widget.contractType,
                      contractStartDate:     _parseDate(widget.contractStartDate),
                      contractEndDate:       _parseDate(widget.contractEndDate),
                      contractTotalValue:    widget.contractTotalValue,
                      totalPaidAmount:       widget.totalPaidAmount,
                      totalVisitsCount:      widget.totalVisitsCount,
                      completedVisitsCount:  widget.completedVisitsCount,
                      palmInfo:              widget.palmInfo,
                      onCopyOrderId:         _copyOrderId,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          _ActionBar(
            saving: _saving,
            sharing: _sharing,
            onSave: _saveToGallery,
            onShare: _share,
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Invoice Card
// ══════════════════════════════════════════════════════════════════════════════

class _InvoiceCard extends StatelessWidget {
  final String paymentId;
  final double amount;
  final String? contractCode;
  final String? clientName;
  final String? clientPhone;
  final String? address;
  final String? dueDate;
  final String paymentDate;
  final String? gatewayOrderId;
  final String? gatewayPaymentMethod;
  final String? contractType;
  final String? contractStartDate;
  final String? contractEndDate;
  final double? contractTotalValue;
  final double? totalPaidAmount;
  final int? totalVisitsCount;
  final int? completedVisitsCount;
  final ContractPalmInfo? palmInfo;
  final VoidCallback? onCopyOrderId;

  const _InvoiceCard({
    required this.paymentId,
    required this.amount,
    required this.paymentDate,
    this.contractCode,
    this.clientName,
    this.clientPhone,
    this.address,
    this.dueDate,
    this.gatewayOrderId,
    this.gatewayPaymentMethod,
    this.contractType,
    this.contractStartDate,
    this.contractEndDate,
    this.contractTotalValue,
    this.totalPaidAmount,
    this.completedVisitsCount,
    this.totalVisitsCount,
    this.palmInfo,
    this.onCopyOrderId,
  });

  String get _invoiceRef =>
      (paymentId.length > 8 ? paymentId.substring(0, 8) : paymentId)
          .toUpperCase();

  String _fmt(double v) => v.toStringAsFixed(3);

  // Palm helpers
  bool get _hasPalm => palmInfo?.isPalm == true;

  String get _palmSpeciesLabel {
    switch (palmInfo?.species) {
      case 'washingtonia': return 'واشنطونيا';
      default: return 'بلدي';
    }
  }

  ContractPalmStats? get _activeStats {
    final info = palmInfo;
    if (info == null) return null;
    if (info.species == 'washingtonia') return info.washingtonia;
    return info.baladi;
  }

  int get _totalPalmCount {
    final s = _activeStats;
    if (s == null) return 0;
    return s.largeProductive + s.largeNonProductive +
           s.smallProductive + s.smallNonProductive;
  }

  @override
  Widget build(BuildContext context) {
    final remaining = contractTotalValue != null && totalPaidAmount != null
        ? (contractTotalValue! - totalPaidAmount!).clamp(0.0, double.infinity)
        : null;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildClientSection(),
                const SizedBox(height: 14),
                _buildItemsTable(),
                const SizedBox(height: 14),
                _buildTotalsSection(remaining),
                const SizedBox(height: 14),
                _buildPaymentDetails(),
                if (totalVisitsCount != null) ...[
                  const SizedBox(height: 14),
                  _buildVisitsStats(),
                ],
                if (_hasPalm) ...[
                  const SizedBox(height: 14),
                  _buildPalmSection(),
                ],
                const SizedBox(height: 16),
                _buildVerifiedStamp(),
                const SizedBox(height: 16),
              ],
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kGreen, _kGreenDark],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Logo + company name
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2))],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/app_icon.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.eco_rounded, color: _kGreen, size: 32),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('شركة بستان أماري',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                  Text('BUSTAN AMARI KUWAIT',
                      style: TextStyle(color: Colors.white60, fontSize: 10, letterSpacing: 0.8)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Orange divider line
          Container(height: 2, color: _kOrange, margin: const EdgeInsets.symmetric(horizontal: 20)),
          const SizedBox(height: 12),
          // Title
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('فاتورة إلكترونية  •  ELECTRONIC INVOICE',
                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
          ),
          const SizedBox(height: 14),
          // Date + Invoice number boxes
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _HeaderInfoBox(
                    icon: Icons.calendar_month_rounded,
                    label: 'التاريخ',
                    value: _extractDate(paymentDate),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _HeaderInfoBox(
                    icon: Icons.receipt_long_rounded,
                    label: 'رقم الفاتورة',
                    value: 'INV-$_invoiceRef',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  String _extractDate(String dateTime) {
    // "dd/MM/yyyy - h:mm" → "dd/MM/yyyy"
    return dateTime.split(' - ').first;
  }

  // ── Client Section ─────────────────────────────────────────────────────────
  Widget _buildClientSection() {
    return Container(
      decoration: BoxDecoration(
        color: _kGreenLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFB8D9C4)),
      ),
      child: Column(
        children: [
          if (clientName != null)
            _ClientRow(icon: Icons.person_rounded, label: 'اسم العميل', value: clientName!),
          if (address != null && address!.isNotEmpty) ...[
            const _RowDivider(),
            _ClientRow(icon: Icons.location_on_rounded, label: 'العنوان', value: address!, wrap: true),
          ],
          if (clientPhone != null && clientPhone!.isNotEmpty) ...[
            const _RowDivider(),
            _ClientRow(icon: Icons.phone_rounded, label: 'رقم الهاتف', value: clientPhone!),
          ],
          if (contractCode != null) ...[
            const _RowDivider(),
            _ClientRow(icon: Icons.badge_rounded, label: 'رقم العقد', value: contractCode!),
          ],
          if (contractType != null && contractType!.isNotEmpty) ...[
            const _RowDivider(),
            _ClientRow(icon: Icons.description_rounded, label: 'نوع العقد', value: contractType!),
          ],
          if (contractStartDate != null && contractEndDate != null) ...[
            const _RowDivider(),
            _ClientRow(
              icon: Icons.date_range_rounded,
              label: 'فترة العقد',
              value: '$contractStartDate ← $contractEndDate',
            ),
          ],
        ],
      ),
    );
  }

  // ── Items Table ─────────────────────────────────────────────────────────────
  Widget _buildItemsTable() {
    final stats = _activeStats;
    final hasItems = contractType != null || _hasPalm;
    if (!hasItems) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Table header bar
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            color: _kGreen,
            borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: Row(
            children: [
              const Icon(Icons.eco_rounded, color: _kOrange, size: 16),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('تفاصيل الأصناف',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
              ),
              ...[
                _TableHeaderCell('م',        28,  TextAlign.center),
                _TableHeaderCell('الكمية',   65,  TextAlign.center),
                _TableHeaderCell('الإجمالي', 80,  TextAlign.end),
              ],
            ],
          ),
        ),
        // Column sub-headers
        Container(
          color: const Color(0xFF2A5C3A),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          child: Row(
            children: [
              const SizedBox(width: 24, child: Text('م', style: TextStyle(color: Colors.white60, fontSize: 11), textAlign: TextAlign.center)),
              const Expanded(child: Text('الصنف', style: TextStyle(color: Colors.white60, fontSize: 11))),
              SizedBox(width: 65, child: Text('الكمية', style: const TextStyle(color: Colors.white60, fontSize: 11), textAlign: TextAlign.center)),
              SizedBox(width: 80, child: Text('الإجمالي', style: const TextStyle(color: Colors.white60, fontSize: 11), textAlign: TextAlign.end)),
            ],
          ),
        ),
        // Rows
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: _kBorder),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
          ),
          child: Column(
            children: [
              if (contractType != null)
                _ItemRow(
                  index: 1,
                  item: contractType!,
                  quantity: totalVisitsCount != null ? '${totalVisitsCount!} زيارة' : '—',
                  total: contractTotalValue != null ? '${_fmt(contractTotalValue!)} د.ك' : '—',
                  isOdd: true,
                ),
              if (_hasPalm && stats != null)
                _ItemRow(
                  index: contractType != null ? 2 : 1,
                  item: 'نخيل $_palmSpeciesLabel',
                  quantity: '$_totalPalmCount نخلة',
                  total: '—',
                  isOdd: contractType == null,
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Totals Section ─────────────────────────────────────────────────────────
  Widget _buildTotalsSection(double? remaining) {
    if (contractTotalValue == null && totalPaidAmount == null) {
      // fallback: just show this payment amount
      return _TotalBar(label: 'هذه الدفعة', value: '${_fmt(amount)} د.ك', highlight: true);
    }
    return Column(
      children: [
        if (contractTotalValue != null)
          _TotalBar(label: 'القيمة الإجمالية للعقد', value: '${_fmt(contractTotalValue!)} د.ك'),
        const SizedBox(height: 4),
        _TotalBar(label: 'هذه الدفعة', value: '${_fmt(amount)} د.ك', highlight: true),
        if (remaining != null) ...[
          const SizedBox(height: 4),
          _TotalBar(label: 'المبلغ المتبقي', value: '${_fmt(remaining)} د.ك', isRemaining: true),
        ],
      ],
    );
  }

  // ── Payment Details ─────────────────────────────────────────────────────────
  Widget _buildPaymentDetails() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF8F5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.payment_rounded, size: 14, color: _kOrange),
            const SizedBox(width: 6),
            const Text('تفاصيل الدفع',
                style: TextStyle(color: _kOrange, fontWeight: FontWeight.w700, fontSize: 11)),
          ]),
          const SizedBox(height: 8),
          _DetailRow(label: 'تاريخ ووقت الدفع', value: paymentDate),
          if (dueDate != null) ...[
            const SizedBox(height: 4),
            _DetailRow(label: 'تاريخ الاستحقاق', value: dueDate!),
          ],
          const SizedBox(height: 4),
          _buildMethodRow(),
          if (gatewayOrderId != null && gatewayOrderId!.isNotEmpty) ...[
            const SizedBox(height: 4),
            _buildOrderIdRow(),
          ],
        ],
      ),
    );
  }

  Widget _buildMethodRow() {
    final info = _MethodInfo.resolve(gatewayPaymentMethod);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('طريقة الدفع',
            style: TextStyle(color: Color(0xFF8A8480), fontSize: 12)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: info.bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: info.color.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(info.icon, size: 13, color: info.color),
              const SizedBox(width: 5),
              Text(info.label,
                  style: TextStyle(color: info.color, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrderIdRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('رقم المعاملة',
            style: TextStyle(color: Color(0xFF8A8480), fontSize: 12)),
        GestureDetector(
          onTap: onCopyOrderId,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _kGreenLight,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFB8D9C4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  gatewayOrderId!.length > 14
                      ? '${gatewayOrderId!.substring(0, 14)}...'
                      : gatewayOrderId!,
                  style: const TextStyle(
                    color: _kGreen, fontSize: 11,
                    fontWeight: FontWeight.w600, fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.copy_rounded, size: 11, color: _kGreen),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Visit Stats ────────────────────────────────────────────────────────────
  Widget _buildVisitsStats() {
    final total     = totalVisitsCount ?? 0;
    final completed = completedVisitsCount ?? 0;
    final remaining = (total - completed).clamp(0, total);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.event_available_rounded, size: 14, color: _kOrange),
          const SizedBox(width: 6),
          const Text('إحصائيات الزيارات',
              style: TextStyle(color: _kOrange, fontWeight: FontWeight.w700, fontSize: 11)),
        ]),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _VisitStatBox(label: 'الإجمالي',  value: '$total',     color: _kGreen)),
            const SizedBox(width: 6),
            Expanded(child: _VisitStatBox(label: 'المكتملة',  value: '$completed', color: const Color(0xFF2E7D50))),
            const SizedBox(width: 6),
            Expanded(child: _VisitStatBox(label: 'المتبقية',  value: '$remaining', color: const Color(0xFF8A6A00))),
          ],
        ),
      ],
    );
  }

  // ── Palm Section ───────────────────────────────────────────────────────────
  Widget _buildPalmSection() {
    final stats = _activeStats;
    if (stats == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FAF3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFB8D9C4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('🌴', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text('تفاصيل النخيل — $_palmSpeciesLabel',
                style: const TextStyle(color: _kGreen, fontWeight: FontWeight.w700, fontSize: 11)),
          ]),
          const SizedBox(height: 10),
          // Total highlighted
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: _kGreen,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('الإجمالي الكلي',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                Text('$_totalPalmCount نخلة',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Breakdown grid
          _PalmStatRow(label: 'كبير ومثمر',        value: stats.largeProductive),
          _PalmStatRow(label: 'كبير وغير مثمر',    value: stats.largeNonProductive),
          _PalmStatRow(label: 'صغير ومثمر',        value: stats.smallProductive),
          _PalmStatRow(label: 'صغير وغير مثمر',   value: stats.smallNonProductive),
        ],
      ),
    );
  }

  // ── Verified Stamp ─────────────────────────────────────────────────────────
  Widget _buildVerifiedStamp() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: _kGreenLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF9ED9B5), width: 1.5),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_rounded, color: Color(0xFF2E7D50), size: 22),
            SizedBox(width: 8),
            Text('مدفوع بنجاح  ✓',
                style: TextStyle(color: Color(0xFF2E7D50), fontWeight: FontWeight.w800, fontSize: 15)),
          ],
        ),
      ),
    );
  }

  // ── Footer ─────────────────────────────────────────────────────────────────
  Widget _buildFooter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: const BoxDecoration(
        color: Color(0xFFF2EDE7),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        border: Border(top: BorderSide(color: _kBorder)),
      ),
      child: Column(
        children: [
          // Stamp area
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _kBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _kGreenLight,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFB8D9C4)),
                  ),
                  child: Image.asset(
                    'assets/app_icon.png',
                    errorBuilder: (_, __, ___) => const Icon(Icons.eco_rounded, color: _kGreen, size: 20),
                  ),
                ),
                const SizedBox(width: 10),
                const Text('ختم وتوقيع الشركة',
                    style: TextStyle(color: Color(0xFF5A5550), fontWeight: FontWeight.w600, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Text('شركة بستان أماري — الكويت',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF8A8480), fontSize: 11)),
          const SizedBox(height: 8),
          const _ContactLinkButton(),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Small reusable widgets
// ══════════════════════════════════════════════════════════════════════════════

class _HeaderInfoBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _HeaderInfoBox({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: _kOrange),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TableHeaderCell extends StatelessWidget {
  final String text;
  final double width;
  final TextAlign align;

  const _TableHeaderCell(this.text, this.width, this.align);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(text,
          textAlign: align,
          style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _ClientRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool wrap;

  const _ClientRow({required this.icon, required this.label, required this.value, this.wrap = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        crossAxisAlignment: wrap ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(color: _kGreen, shape: BoxShape.circle),
            child: Icon(icon, size: 14, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: wrap
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: const TextStyle(color: Color(0xFF6A7A6A), fontSize: 11)),
                      const SizedBox(height: 2),
                      Text(value,
                          style: const TextStyle(color: Color(0xFF1A2E1A), fontWeight: FontWeight.w700, fontSize: 13)),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(label, style: const TextStyle(color: Color(0xFF6A7A6A), fontSize: 12)),
                      Flexible(
                        child: Text(value,
                            textAlign: TextAlign.end,
                            style: const TextStyle(color: Color(0xFF1A2E1A), fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, indent: 50, color: Color(0xFFD0E8D8));
}

class _ItemRow extends StatelessWidget {
  final int index;
  final String item;
  final String quantity;
  final String total;
  final bool isOdd;

  const _ItemRow({
    required this.index,
    required this.item,
    required this.quantity,
    required this.total,
    this.isOdd = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isOdd ? Colors.white : _kRowAlt,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text('$index',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF8A8480), fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(item,
                style: const TextStyle(color: Color(0xFF1A2E1A), fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          SizedBox(
            width: 65,
            child: Text(quantity,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF4A6A4A), fontSize: 12, fontWeight: FontWeight.w500)),
          ),
          SizedBox(
            width: 80,
            child: Text(total,
                textAlign: TextAlign.end,
                style: const TextStyle(color: _kGreen, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _TotalBar extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  final bool isRemaining;

  const _TotalBar({required this.label, required this.value, this.highlight = false, this.isRemaining = false});

  @override
  Widget build(BuildContext context) {
    final bgLabel  = highlight ? _kGreen : (isRemaining ? const Color(0xFF7A5A00) : const Color(0xFF2A5C3A));
    final bgValue  = highlight ? const Color(0xFFEAF4EE) : (isRemaining ? const Color(0xFFFFF8E8) : const Color(0xFFF5FAF6));
    final txtValue = highlight ? _kGreen : (isRemaining ? const Color(0xFF7A5A00) : const Color(0xFF2A5C3A));

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          // Orange left accent
          Container(width: 4, height: 44, decoration: BoxDecoration(
            color: _kOrange,
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
          )),
          // Label (dark green bg)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            height: 44,
            decoration: BoxDecoration(color: bgLabel),
            child: Center(
              child: Text(label,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
            ),
          ),
          // Value
          Expanded(
            child: Container(
              height: 44,
              color: bgValue,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(value,
                    style: TextStyle(color: txtValue, fontWeight: FontWeight.w800, fontSize: 14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF8A8480), fontSize: 12)),
        Flexible(
          child: Text(value,
              textAlign: TextAlign.end,
              style: const TextStyle(color: Color(0xFF1A2E1A), fontWeight: FontWeight.w600, fontSize: 12)),
        ),
      ],
    );
  }
}

class _VisitStatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _VisitStatBox({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _PalmStatRow extends StatelessWidget {
  final String label;
  final int value;

  const _PalmStatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(width: 6, height: 6, margin: const EdgeInsets.only(left: 8),
                  decoration: const BoxDecoration(color: _kGreen, shape: BoxShape.circle)),
              Text(label, style: const TextStyle(color: Color(0xFF4A6A4A), fontSize: 12)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: _kGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('$value نخلة',
                style: const TextStyle(color: _kGreen, fontWeight: FontWeight.w700, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

// ── Contact link ──────────────────────────────────────────────────────────────

const String _bustanAmariLinktreeUrl = 'https://linktr.ee/bustanamari.kw';

class _ContactLinkButton extends StatelessWidget {
  const _ContactLinkButton();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => launchUrl(Uri.parse(_bustanAmariLinktreeUrl), mode: LaunchMode.externalApplication),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _kGreen.withValues(alpha: 0.35)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.link_rounded, size: 15, color: _kGreen),
            SizedBox(width: 6),
            Text('تواصل معنا',
                style: TextStyle(color: _kGreen, fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

// ── Payment method resolver ───────────────────────────────────────────────────

class _MethodInfo {
  final String label;
  final IconData icon;
  final Color color;
  final Color bg;

  const _MethodInfo(this.label, this.icon, this.color, this.bg);

  static _MethodInfo resolve(String? method) {
    switch (method?.toLowerCase()) {
      case 'knet':
        return const _MethodInfo('KNET', Icons.account_balance_rounded, Color(0xFF006838), Color(0xFFE8F5EE));
      case 'google_pay':
      case 'googlepay':
        return const _MethodInfo('Google Pay', Icons.g_mobiledata_rounded, Color(0xFF4285F4), Color(0xFFE8F0FE));
      case 'apple_pay':
      case 'applepay':
      case 'apple_pay_knet':
        return const _MethodInfo('Apple Pay', Icons.apple_rounded, Color(0xFF1C1C1E), Color(0xFFF2F2F7));
      case 'samsung_pay':
        return const _MethodInfo('Samsung Pay', Icons.phone_android_rounded, Color(0xFF1428A0), Color(0xFFE8EEFA));
      case 'cc':
      case 'credit_card':
      case 'creditcard':
        return const _MethodInfo('بطاقة ائتمانية', Icons.credit_card_rounded, Color(0xFF4285F4), Color(0xFFE8F0FE));
      default:
        return const _MethodInfo('بطاقة إلكترونية', Icons.credit_card_rounded, Color(0xFF4285F4), Color(0xFFE8F0FE));
    }
  }
}

// ── Action bar ────────────────────────────────────────────────────────────────

class _ActionBar extends StatelessWidget {
  final bool saving;
  final bool sharing;
  final VoidCallback onSave;
  final VoidCallback onShare;

  const _ActionBar({required this.saving, required this.sharing, required this.onSave, required this.onShare});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: const BoxDecoration(
          color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFEBE6E1)))),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: _kGreen,
                side: const BorderSide(color: _kGreen),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: sharing ? null : onShare,
              icon: sharing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _kGreen))
                  : const Icon(Icons.share_rounded, size: 18),
              label: const Text('مشاركة'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _kGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: saving ? null : onSave,
              icon: saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.download_rounded, size: 18),
              label: const Text('حفظ في المعرض'),
            ),
          ),
        ],
      ),
    );
  }
}
