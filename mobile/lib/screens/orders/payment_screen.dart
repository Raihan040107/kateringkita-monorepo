import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_colors.dart';
import '../../core/app_currency.dart';
import '../../core/app_routes.dart';
import '../../core/app_text_styles.dart';
import '../../core/app_time.dart';
import '../../models/order.dart';
import '../../services/api_client.dart';
import '../../services/orders_api.dart';
import '../../widgets/order_status_chip.dart';
import '../../widgets/primary_button.dart';

/// Pembayaran pesanan `holding`: Virtual Account (Core API) atau Snap online.
/// Status dipantau lewat `GET /orders/:code` tiap 5 detik. Argumen rute: `String code`.
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen>
    with WidgetsBindingObserver {
  static const _banks = ['bca', 'bni', 'bri'];

  String? _code;
  Order? _order;
  bool _loading = true;
  String? _error;
  String _bank = 'bca';
  bool _busy = false;
  Timer? _tick;
  Timer? _poll;
  bool _outcomeShown = false;

  ApiClient get _api => context.read<ApiClient>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_code != null || _error != null) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String) {
      _code = args;
      _load();
    } else {
      _loading = false;
      _error = 'Pesanan tidak ditemukan.';
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    _poll?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Kembali dari Custom Tab/m-banking → segarkan; di latar → hemat baterai.
    if (state == AppLifecycleState.resumed) {
      _load();
    } else if (state == AppLifecycleState.paused) {
      _poll?.cancel();
      _poll = null;
    }
  }

  Future<void> _load() async {
    if (_code == null) return;
    try {
      final order = await _api.order(_code!);
      if (!mounted) return;
      setState(() {
        _order = order;
        _loading = false;
        _error = null;
      });
      _sync(order);
    } on ApiException catch (e) {
      if (!mounted) return;
      // Sudah ada data: galat sementara diabaikan, polling lanjut.
      if (_order == null) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    }
  }

  void _sync(Order order) {
    if (order.isHolding) {
      _poll ??= Timer.periodic(const Duration(seconds: 5), (_) => _load());
      _tick ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
      return;
    }
    _poll?.cancel();
    _poll = null;
    _tick?.cancel();
    _tick = null;
    if (!_outcomeShown && order.isActive || order.status == 'completed') {
      _outcomeShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showPaidSheet(order);
      });
    }
  }

  Future<void> _createVa() async {
    setState(() => _busy = true);
    try {
      final order = await _api.createVa(_code!, _bank);
      if (!mounted) return;
      setState(() => _order = order);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Snap dibuka di atas aplikasi (Chrome Custom Tab, pola ShopeeFood);
  /// tanpa Chrome → browser luar. Status menyusul lewat polling.
  Future<void> _openSnap() async {
    setState(() => _busy = true);
    try {
      var url = _order?.payment?.paymentUrl;
      if (url == null || url.isEmpty) {
        final order = await _api.payOnline(_code!);
        if (!mounted) return;
        setState(() => _order = order);
        url = order.payment?.paymentUrl;
      }
      if (url == null || url.isEmpty) {
        throw ApiException(0, 'NO_URL', 'Tautan pembayaran belum tersedia.');
      }
      final uri = Uri.parse(url);
      var ok = false;
      try {
        ok = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
        if (!ok) ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        ok = false;
      }
      if (!ok) {
        throw ApiException(
            0, 'NO_BROWSER', 'Tidak dapat membuka halaman pembayaran.');
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _copy(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text('$label berhasil disalin!'),
          ],
        ),
        backgroundColor: AppColors.successDark,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _goHome() {
    Navigator.pushNamedAndRemoveUntil(
        context, AppRoutes.mainNav, (route) => false);
  }

  void _goDetail() {
    // Sisakan beranda di bawah detail pesanan.
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.orderDetail,
      (route) => route.settings.name == AppRoutes.mainNav,
      arguments: _code,
    );
  }

  void _showPaidSheet(Order order) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.success,
                    size: 44,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Pembayaran Diterima!',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.h2.copyWith(fontSize: 18),
                ),
                const SizedBox(height: 6),
                Text(
                  'Pesanan diteruskan ke ${order.merchantName}. Pantau statusnya di detail pesanan.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      _kv('Kode Pesanan', order.code, mono: true),
                      const SizedBox(height: 6),
                      _kv('Total Dibayar', AppCurrency.format(order.total),
                          valueColor: AppColors.primary),
                      const SizedBox(height: 6),
                      _kv('Metode', paymentMethodLabel(order.paymentMethod)),
                      const SizedBox(height: 6),
                      _kv('Titik Temu', order.pickupPointName),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.receipt_long_rounded, size: 20),
                    label: const Text(
                      'Lihat Detail Pesanan',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _goDetail();
                    },
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: AppColors.cardBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _goHome();
                    },
                    child: Text(
                      'Kembali ke Beranda',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _kv(String k, String v, {bool mono = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(k,
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            v,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w700,
              fontFamily: mono ? 'monospace' : null,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    final isVa = order?.paymentMethod == 'va';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          order == null
              ? 'Pembayaran'
              : isVa
                  ? 'Transfer Virtual Account'
                  : 'Bayar Online',
          style: AppTextStyles.h3.copyWith(fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: _goHome,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : order == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error ?? 'Pesanan tidak ditemukan.',
                          style: AppTextStyles.bodyMedium),
                      if (_code != null)
                        TextButton(
                            onPressed: _load, child: const Text('Coba lagi')),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (order.isHolding) ...[
                        _buildTimerCard(order),
                        const SizedBox(height: 16),
                        if (isVa)
                          _buildVaSection(order)
                        else
                          _buildOnlineSection(order),
                      ] else
                        _buildFinalCard(order),
                      const SizedBox(height: 16),
                      _buildOrderSummaryCard(order),
                      if (order.isHolding) ...[
                        const SizedBox(height: 16),
                        _buildInstructionCard(order),
                      ],
                    ],
                  ),
                ),
      bottomNavigationBar: order == null
          ? null
          : Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  top: BorderSide(
                    color: AppColors.cardBorder.withValues(alpha: 0.6),
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _busy
                        ? null
                        : order.isHolding
                            ? _load
                            : order.isActive || order.status == 'completed'
                                ? _goDetail
                                : _goHome,
                    child: Text(
                      order.isHolding
                          ? (isVa
                              ? 'Cek Status Pembayaran'
                              : 'Saya Sudah Membayar')
                          : order.isActive || order.status == 'completed'
                              ? 'Lihat Detail Pesanan'
                              : 'Kembali ke Beranda',
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildTimerCard(Order order) {
    final left = order.remainingSeconds();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFEDD5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.timer_outlined,
              color: AppColors.primaryDark,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  left == 0
                      ? 'Waktu habis, memeriksa status…'
                      : 'Selesaikan Pembayaran Dalam',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  AppTime.mmss(left),
                  style: AppTextStyles.h3.copyWith(
                    color: AppColors.primaryDark,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Menunggu Bayar',
              style: AppTextStyles.bodySmall.copyWith(
                color: const Color(0xFFDC2626),
                fontWeight: FontWeight.w700,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration get _card => BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      );

  Widget _buildVaSection(Order order) {
    final p = order.payment;
    final vaNumber = p?.vaNumber;
    if (vaNumber == null || vaNumber.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: _card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pilih Bank Virtual Account',
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: _banks.map((bank) {
                final isSelected = _bank == bank;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: InkWell(
                      onTap: () => setState(() => _bank = bank),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primarySoft
                              : AppColors.secondaryBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.cardBorder,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          bank.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              text: 'Buat Nomor Virtual Account',
              isLoading: _busy,
              onPressed: _createVa,
            ),
          ],
        ),
      );
    }

    final bank = (p?.vaBank ?? _bank).toUpperCase();
    final expires = p?.vaExpiresAt;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Nomor Virtual Account $bank',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
              Text(
                'Cek otomatis',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: FittedBox(
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.scaleDown,
                  child: Text(
                    vaNumber,
                    style: AppTextStyles.h3.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                      fontFamily: 'monospace',
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                onPressed: () => _copy(vaNumber, 'Nomor Virtual Account'),
                child: const Text('Salin',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: AppColors.cardBorder),
          const SizedBox(height: 10),
          _kv('Atas Nama', 'KateringKita'),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Pembayaran',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppCurrency.format(p?.amount ?? order.total),
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () =>
                        _copy('${p?.amount ?? order.total}', 'Nominal'),
                    child: const Icon(Icons.copy_rounded,
                        size: 14, color: AppColors.primary),
                  ),
                ],
              ),
            ],
          ),
          if (expires != null) ...[
            const SizedBox(height: 6),
            _kv('Berlaku sampai', AppTime.dateTime(expires)),
          ],
        ],
      ),
    );
  }

  Widget _buildOnlineSection(Order order) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE53935),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'QRIS',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _ewalletPill('GoPay'),
              const SizedBox(width: 6),
              _ewalletPill('ShopeePay'),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Halaman pembayaran aman Midtrans dibuka di atas aplikasi. Pilih QRIS, GoPay, atau ShopeePay, lalu kembali ke sini — status diperbarui otomatis.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.secondaryBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Pembayaran',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                Text(
                  AppCurrency.format(order.total),
                  style: AppTextStyles.h3.copyWith(
                    color: AppColors.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          PrimaryButton(
            text: 'Buka Halaman Pembayaran',
            icon: Icons.open_in_new_rounded,
            isLoading: _busy,
            onPressed: _openSnap,
          ),
        ],
      ),
    );
  }

  Widget _ewalletPill(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: AppColors.secondaryBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Text(
        name,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildFinalCard(Order order) {
    final paid = order.isActive || order.status == 'completed';
    final color = paid ? AppColors.success : AppColors.danger;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: paid ? AppColors.successLight : AppColors.dangerLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            paid ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: color,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  paid
                      ? 'Pembayaran diterima'
                      : order.status == 'expired'
                          ? 'Waktu pembayaran habis'
                          : 'Pesanan dibatalkan',
                  style: AppTextStyles.h4.copyWith(fontSize: 15, color: color),
                ),
                const SizedBox(height: 4),
                Text(
                  paid
                      ? 'Status: ${orderStatusLabel(order.status)}'
                      : (order.cancelReason ??
                          'Kuota dilepas. Silakan pesan kembali.'),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummaryCard(Order order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                order.merchantName,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              Text(
                order.code,
                style: AppTextStyles.bodySmall.copyWith(
                  fontFamily: 'monospace',
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final item in order.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.menuName,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          '${item.qty} x ${AppCurrency.format(item.unitPrice)}'
                          '${item.options.isEmpty ? '' : ' • ${item.options.join(', ')}'}',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    AppCurrency.format(item.lineTotal),
                    style: AppTextStyles.bodyMedium
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          Divider(height: 16, color: AppColors.cardBorder),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total', style: AppTextStyles.h4.copyWith(fontSize: 14)),
              Text(
                AppCurrency.format(order.total),
                style: AppTextStyles.price.copyWith(fontSize: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionCard(Order order) {
    final isVa = order.paymentMethod == 'va';
    final bank = (order.payment?.vaBank ?? _bank).toUpperCase();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Panduan Cara Pembayaran',
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          if (isVa) ...[
            _stepRow('1', 'Buat nomor Virtual Account, lalu buka m-Banking $bank atau ATM.'),
            _stepRow('2', 'Pilih Transfer > Virtual Account, masukkan nomor di atas.'),
            _stepRow('3', 'Pastikan nominal ${AppCurrency.format(order.total)} lalu konfirmasi.'),
            _stepRow('4', 'Status berubah otomatis dalam ±1 menit; tekan "Cek Status" bila belum.'),
          ] else ...[
            _stepRow('1', 'Tekan "Buka Halaman Pembayaran".'),
            _stepRow('2', 'Pilih QRIS, GoPay, atau ShopeePay dan selesaikan pembayaran.'),
            _stepRow('3', 'Kembali ke aplikasi; status berubah otomatis.'),
          ],
        ],
      ),
    );
  }

  Widget _stepRow(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              num,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontSize: 11.5,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
