// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:ensdim_landscape/core/theme/app_colors.dart';
import 'package:ensdim_landscape/domain/entities/contract.dart';
import 'package:ensdim_landscape/presentation/screens/client/payment_receipt_screen.dart';

class PaymentSuccessScreen extends StatelessWidget {
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
  final String? contractType;
  final String? contractStartDate;
  final String? contractEndDate;
  final double? contractTotalValue;
  final double? totalPaidAmount;
  final ContractPalmInfo? palmInfo;

  const PaymentSuccessScreen({
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
    this.palmInfo,
  });

  String get _formattedAmount => '${amount.toStringAsFixed(3)} د.ك';

  void _openReceipt(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PaymentReceiptScreen(
        paymentId:             paymentId,
        paymentType:           paymentType,
        contractId:            contractId,
        amount:                amount,
        receiptUrl:            receiptUrl,
        contractCode:          contractCode,
        clientName:            clientName,
        clientPhone:           clientPhone,
        address:               address,
        dueDate:               dueDate,
        paymentDate:           paymentDate,
        createdAt:             createdAt,
        paymentGatewayOrderId: paymentGatewayOrderId,
        gatewayPaymentMethod:  gatewayPaymentMethod,
        contractType:          contractType,
        contractStartDate:     contractStartDate,
        contractEndDate:       contractEndDate,
        contractTotalValue:    contractTotalValue,
        totalPaidAmount:       totalPaidAmount,
        palmInfo:              palmInfo,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text(
          'تم الدفع',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(true),
        ),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(),

              // ── Success icon ───────────────────────────────────────────────
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFFECF8F0),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF9ED9B5), width: 2),
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF2E7D50),
                  size: 56,
                ),
              ),
              const SizedBox(height: 24),

              // ── Title ──────────────────────────────────────────────────────
              const Text(
                'تم استلام دفعتك بنجاح',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),

              // ── Amount ─────────────────────────────────────────────────────
              Text(
                _formattedAmount,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                contractCode != null ? 'عقد رقم $contractCode' : 'تمت العملية بنجاح',
                style: const TextStyle(color: AppColors.textLabel, fontSize: 14),
              ),

              const Spacer(),

              // ── Buttons ────────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _openReceipt(context),
                  icon: const Icon(Icons.receipt_long_rounded, size: 20),
                  label: const Text(
                    'الإيصال المحفوظ',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text(
                    'الرجوع للعقد',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
