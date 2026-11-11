import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_text_styles.dart';

String orderStatusLabel(String status) => switch (status) {
      'holding' => 'Menunggu Pembayaran',
      'confirmed' => 'Dikonfirmasi',
      'cooking' => 'Dimasak',
      'ready' => 'Siap Diambil',
      'completed' => 'Selesai',
      'cancelled' => 'Dibatalkan',
      'expired' => 'Kedaluwarsa',
      _ => status,
    };

String paymentMethodLabel(String method) => switch (method) {
      'va' => 'Virtual Account',
      'online' => 'Bayar Online',
      'cod' => 'Tunai',
      _ => method,
    };

String paymentStatusLabel(String status) => switch (status) {
      'unpaid' => 'Belum dibayar',
      'pending' => 'Menunggu pembayaran',
      'paid' => 'Lunas',
      'refunded' => 'Dikembalikan',
      _ => status,
    };

/// Chip status pesanan: warna mengikuti tahap.
class OrderStatusChip extends StatelessWidget {
  const OrderStatusChip(this.status, {super.key, this.label});
  final String status;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final (Color fg, Color bg) = switch (status) {
      'holding' => (AppColors.primaryDark, AppColors.primarySoft),
      'confirmed' || 'cooking' => (AppColors.blue, AppColors.blueLight),
      'ready' || 'completed' => (AppColors.successDark, AppColors.successLight),
      'cancelled' || 'expired' => (AppColors.danger, AppColors.dangerLight),
      _ => (AppColors.textSecondary, AppColors.secondaryBg),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label ?? orderStatusLabel(status),
        style: AppTextStyles.bodySmall.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}
