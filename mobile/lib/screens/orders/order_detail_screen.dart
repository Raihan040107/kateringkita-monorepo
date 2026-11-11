import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_currency.dart';
import '../../core/app_routes.dart';
import '../../core/app_text_styles.dart';
import '../../core/app_time.dart';
import '../../models/cart_line.dart';
import '../../models/order.dart';
import '../../services/api_client.dart';
import '../../services/orders_api.dart';
import '../../widgets/order_status_chip.dart';
import '../../widgets/primary_button.dart';

/// Detail satu pesanan: timeline status, item, pembayaran, dan aksi pembeli.
/// Dipantau tiap 5 detik selama pesanan aktif. Argumen rute: `String code`.
class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen>
    with WidgetsBindingObserver {
  static const _steps = [
    ('Pesanan masuk', 'Menunggu pembayaran & konfirmasi penjual'),
    ('Dikonfirmasi', 'Penjual menerima pesanan'),
    ('Dimasak', 'Pesanan sedang disiapkan'),
    ('Siap diambil', 'Ambil di titik temu yang dipilih'),
    ('Selesai', 'Pesanan sudah diambil'),
  ];

  String? _code;
  Order? _order;
  bool _loading = true;
  String? _error;
  bool _busy = false;
  Timer? _poll;
  Timer? _tick;

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
    _poll?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
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
      if (_order == null) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    }
  }

  void _sync(Order order) {
    if (order.isActive) {
      _poll ??= Timer.periodic(const Duration(seconds: 5), (_) => _load());
    } else {
      _poll?.cancel();
      _poll = null;
    }
    if (order.isHolding) {
      _tick ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else {
      _tick?.cancel();
      _tick = null;
    }
  }

  Future<void> _run(Future<Order> Function() action) async {
    setState(() => _busy = true);
    try {
      final order = await action();
      if (!mounted) return;
      setState(() => _order = order);
      _sync(order);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Batalkan pesanan?', style: AppTextStyles.h4),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kuota akan dilepas dan pesanan tidak bisa dilanjutkan.',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLength: 255,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Alasan (opsional)',
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Kembali'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Batalkan Pesanan',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    final reason = controller.text.trim();
    controller.dispose();
    if (ok != true || !mounted) return;
    await _run(() => _api.cancel(_code!, reason.isEmpty ? null : reason));
  }

  Future<void> _complete() =>
      _run(() => _api.complete(_code!));

  Future<void> _review(Order order) async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ReviewSheet(order: order, api: _api),
    );
    if (sent == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Terima kasih, ulasan terkirim!')),
      );
      _load();
    }
  }

  Future<void> _reorder() async {
    setState(() => _busy = true);
    try {
      final r = await _api.reorder(_code!);
      if (!mounted) return;
      final lines = cartLinesFromReorder(r.request, r.quote);
      if (lines.isEmpty) {
        throw ApiException(0, 'EMPTY', 'Menu pesanan ini sudah tidak tersedia.');
      }
      Navigator.pushNamed(context, AppRoutes.checkout, arguments: lines);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openPayment() async {
    await Navigator.pushNamed(context, AppRoutes.payment, arguments: _code);
    if (mounted) _load();
  }

  void _copy(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label disalin'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  BoxDecoration get _card => BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      );

  @override
  Widget build(BuildContext context) {
    final order = _order;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.canPop(context)
              ? Navigator.pop(context)
              : Navigator.pushNamedAndRemoveUntil(
                  context, AppRoutes.mainNav, (route) => false),
        ),
        title: Text('Detail Pesanan',
            style: AppTextStyles.h3.copyWith(fontSize: 18)),
        actions: [
          if (order != null)
            IconButton(
              tooltip: 'Segarkan',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _load,
            ),
        ],
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
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    children: [
                      _buildHeader(order),
                      const SizedBox(height: 14),
                      if (order.isFinal && order.status != 'completed')
                        _buildCancelledCard(order)
                      else
                        _buildTimeline(order),
                      const SizedBox(height: 14),
                      _buildItemsCard(order),
                      const SizedBox(height: 14),
                      _buildPickupCard(order),
                      const SizedBox(height: 14),
                      _buildPaymentCard(order),
                      const SizedBox(height: 14),
                      _buildActions(order),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeader(Order order) {
    final created = order.createdAt;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _copy(order.code, 'Kode pesanan'),
                  child: Row(
                    children: [
                      Text(
                        order.code,
                        style: AppTextStyles.h3.copyWith(
                          fontSize: 17,
                          fontFamily: 'monospace',
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.copy_rounded,
                          size: 14, color: AppColors.textMuted),
                    ],
                  ),
                ),
              ),
              OrderStatusChip(order.status),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.storefront_rounded,
                  size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  order.merchantName,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              if (created != null)
                Text(
                  AppTime.dateTime(created),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
          if (order.isHolding) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined,
                      size: 18, color: AppColors.primaryDark),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bayar dalam ${AppTime.mmss(order.remainingSeconds())} '
                      'atau pesanan kedaluwarsa.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimeline(Order order) {
    final current = switch (order.status) {
      'holding' => 0,
      'confirmed' => 1,
      'cooking' => 2,
      'ready' => 3,
      'completed' => 4,
      _ => 0,
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      decoration: _card,
      child: Column(
        children: [
          for (var i = 0; i < _steps.length; i++)
            _TimelineStep(
              title: _steps[i].$1,
              subtitle: _steps[i].$2,
              done: i < current,
              active: i == current,
              last: i == _steps.length - 1,
            ),
        ],
      ),
    );
  }

  Widget _buildCancelledCard(Order order) {
    final expired = order.status == 'expired';
    final by = switch (order.cancelledBy) {
      'customer' => 'oleh Anda',
      'merchant' => 'oleh penjual',
      'admin' => 'oleh admin',
      'system' => 'oleh sistem',
      _ => null,
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.dangerLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            expired ? Icons.timer_off_rounded : Icons.cancel_rounded,
            color: AppColors.danger,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expired
                      ? 'Pesanan kedaluwarsa'
                      : 'Pesanan dibatalkan${by == null ? '' : ' $by'}',
                  style: AppTextStyles.h4
                      .copyWith(fontSize: 15, color: AppColors.danger),
                ),
                const SizedBox(height: 4),
                Text(
                  order.cancelReason ??
                      (expired
                          ? 'Pembayaran tidak diterima sebelum batas waktu.'
                          : 'Kuota sudah dilepas.'),
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

  Widget _buildItemsCard(Order order) {
    Widget row(String label, String value,
        {Color? color, bool bold = false}) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: bold
                    ? AppTextStyles.h4.copyWith(fontSize: 14)
                    : AppTextStyles.bodySmall.copyWith(fontSize: 12.5)),
            Text(
              value,
              style: bold
                  ? AppTextStyles.price.copyWith(fontSize: 16)
                  : AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: color,
                      fontSize: 12.5,
                    ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Rincian Pesanan',
              style: AppTextStyles.h4.copyWith(fontSize: 14)),
          const SizedBox(height: 10),
          for (final item in order.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.secondaryBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${item.qty}x',
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
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
                          '@ ${AppCurrency.format(item.unitPrice)}'
                          '${item.options.isEmpty ? '' : ' • ${item.options.join(', ')}'}',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    AppCurrency.format(item.lineTotal),
                    style: AppTextStyles.bodyMedium
                        .copyWith(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ],
              ),
            ),
          Divider(height: 12, color: AppColors.cardBorder),
          row('Subtotal', AppCurrency.format(order.subtotal)),
          if (order.discount > 0)
            row('Diskon', '- ${AppCurrency.format(order.discount)}',
                color: AppColors.success),
          row(
            'Biaya Layanan',
            order.serviceFee == 0
                ? 'Gratis'
                : AppCurrency.format(order.serviceFee),
            color: order.serviceFee == 0 ? AppColors.success : null,
          ),
          row('Total', AppCurrency.format(order.total), bold: true),
        ],
      ),
    );
  }

  Widget _buildPickupCard(Order order) {
    final pickupAt = order.pickupAt;
    final note = order.note;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pengambilan', style: AppTextStyles.h4.copyWith(fontSize: 14)),
          const SizedBox(height: 10),
          _infoRow(Icons.location_on_rounded, 'Titik temu', order.pickupPointName),
          if (pickupAt != null) ...[
            const SizedBox(height: 8),
            _infoRow(Icons.event_rounded, 'Waktu ambil (pre-order)',
                AppTime.dateTime(pickupAt)),
          ],
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: 8),
            _infoRow(Icons.sticky_note_2_outlined, 'Catatan', note),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: AppTextStyles.bodySmall
                      .copyWith(fontSize: 11, color: AppColors.textSecondary)),
              Text(
                value,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentCard(Order order) {
    final p = order.payment;
    final va = p?.vaNumber;
    final expires = p?.vaExpiresAt;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Pembayaran', style: AppTextStyles.h4.copyWith(fontSize: 14)),
              Text(
                paymentStatusLabel(order.paymentStatus),
                style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 11.5,
                  color: order.paymentStatus == 'paid'
                      ? AppColors.successDark
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _infoRow(
            order.paymentMethod == 'va'
                ? Icons.account_balance_rounded
                : Icons.qr_code_2_rounded,
            'Metode',
            paymentMethodLabel(order.paymentMethod) +
                (p?.vaBank != null ? ' ${p!.vaBank!.toUpperCase()}' : ''),
          ),
          if (va != null && va.isNotEmpty && order.isHolding) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const SizedBox(width: 28),
                Expanded(
                  child: Text(
                    va,
                    style: AppTextStyles.h4.copyWith(
                      fontSize: 16,
                      fontFamily: 'monospace',
                      letterSpacing: 1,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _copy(va, 'Nomor VA'),
                  icon: const Icon(Icons.copy_rounded, size: 14),
                  label: const Text('Salin'),
                ),
              ],
            ),
            if (expires != null)
              Padding(
                padding: const EdgeInsets.only(left: 28),
                child: Text(
                  'Berlaku sampai ${AppTime.dateTime(expires)}',
                  style: AppTextStyles.bodySmall.copyWith(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
          ],
          if (order.isHolding) ...[
            const SizedBox(height: 12),
            PrimaryButton(
              text: va != null && va.isNotEmpty
                  ? 'Lihat Instruksi Bayar'
                  : 'Lanjut Bayar',
              height: 46,
              onPressed: _busy ? null : _openPayment,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActions(Order order) {
    final buttons = <Widget>[];
    if (order.canComplete) {
      buttons.add(PrimaryButton(
        text: 'Sudah Diambil',
        icon: Icons.check_circle_outline_rounded,
        isLoading: _busy,
        onPressed: _busy ? null : _complete,
      ));
    }
    if (order.canReview) {
      buttons.add(PrimaryButton(
        text: 'Beri Ulasan',
        icon: Icons.star_rounded,
        onPressed: _busy ? null : () => _review(order),
      ));
    }
    if (order.isFinal) {
      buttons.add(_outlined(
        'Pesan Lagi',
        Icons.replay_rounded,
        _busy ? null : _reorder,
      ));
    }
    buttons.add(_outlined(
      'Chat Penjual',
      Icons.chat_bubble_outline_rounded,
      () => Navigator.pushNamed(context, AppRoutes.whatsappGenerator,
          arguments: order.code),
      color: const Color(0xFF10B981),
    ));
    if (order.canCancel) {
      buttons.add(_outlined(
        'Batalkan Pesanan',
        Icons.close_rounded,
        _busy ? null : _cancel,
        color: AppColors.danger,
      ));
    }
    return Column(
      children: [
        for (final b in buttons)
          Padding(padding: const EdgeInsets.only(bottom: 10), child: b),
      ],
    );
  }

  Widget _outlined(String text, IconData icon, VoidCallback? onPressed,
      {Color? color}) {
    final c = color ?? AppColors.textPrimary;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: c,
          side: BorderSide(color: color ?? AppColors.cardBorder),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: Icon(icon, size: 18),
        label: Text(
          text,
          style: AppTextStyles.bodyMedium
              .copyWith(fontWeight: FontWeight.w700, color: c),
        ),
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.title,
    required this.subtitle,
    required this.done,
    required this.active,
    required this.last,
  });

  final String title;
  final String subtitle;
  final bool done;
  final bool active;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final color = done || active ? AppColors.primary : AppColors.cardBorder;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done
                    ? AppColors.primary
                    : active
                        ? AppColors.primarySoft
                        : AppColors.surface,
                border: Border.all(color: color, width: 2),
              ),
              child: done
                  ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                  : active
                      ? Center(
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary,
                            ),
                          ),
                        )
                      : null,
            ),
            if (!last)
              Container(
                width: 2,
                height: 30,
                color: done ? AppColors.primary : AppColors.cardBorder,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 1, bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: done || active
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                  ),
                ),
                if (active)
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySmall.copyWith(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Ulasan per item: bintang 1–5 + komentar → `POST /orders/:code/reviews`.
class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({required this.order, required this.api});
  final Order order;
  final ApiClient api;

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  late final List<int> _ratings =
      List.filled(widget.order.items.length, 5);
  late final List<TextEditingController> _comments = [
    for (final _ in widget.order.items) TextEditingController(),
  ];
  bool _sending = false;

  @override
  void dispose() {
    for (final c in _comments) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _sending = true);
    try {
      await widget.api.review(widget.order.code, [
        for (var i = 0; i < widget.order.items.length; i++)
          {
            'menu_id': widget.order.items[i].menuId,
            'rating': _ratings[i],
            if (_comments[i].text.trim().isNotEmpty)
              'comment': _comments[i].text.trim(),
          },
      ]);
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bagaimana pesananmu?',
                style: AppTextStyles.h3.copyWith(fontSize: 17)),
            const SizedBox(height: 4),
            Text(
              'Ulasan membantu penjual dan pembeli lain.',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < widget.order.items.length; i++) ...[
              Text(
                widget.order.items[i].menuName,
                style: AppTextStyles.bodyMedium
                    .copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  for (var s = 1; s <= 5; s++)
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36),
                      iconSize: 30,
                      onPressed: () => setState(() => _ratings[i] = s),
                      icon: Icon(
                        s <= _ratings[i]
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: s <= _ratings[i]
                            ? const Color(0xFFF59E0B)
                            : AppColors.textMuted,
                      ),
                    ),
                ],
              ),
              TextField(
                controller: _comments[i],
                maxLength: 500,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Komentar (opsional)',
                  isDense: true,
                  counterText: '',
                  filled: true,
                  fillColor: AppColors.secondaryBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            PrimaryButton(
              text: 'Kirim Ulasan',
              isLoading: _sending,
              onPressed: _sending ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
