import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_currency.dart';
import '../../core/app_routes.dart';
import '../../core/app_text_styles.dart';
import '../../core/app_time.dart';
import '../../models/order.dart';
import '../../services/api_client.dart';
import '../../services/orders_api.dart';
import '../../widgets/order_status_chip.dart';

/// Daftar pesanan pembeli dari `GET /me/orders?tab=`; tiga tab.
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key, this.initialTab = 0});

  /// 0 Aktif, 1 Selesai, 2 Dibatalkan.
  final int initialTab;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  static const _tabs = [
    ('active', 'Aktif'),
    ('completed', 'Selesai'),
    ('cancelled', 'Dibatalkan'),
  ];

  late int _tab = widget.initialTab.clamp(0, _tabs.length - 1);
  final TextEditingController _searchController = TextEditingController();
  List<Order> _orders = const [];
  bool _loading = true;
  String? _error;
  Timer? _tick;

  ApiClient get _api => context.read<ApiClient>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tick?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final tab = _tabs[_tab].$1;
    try {
      final orders = await _api.myOrders(tab: tab);
      if (!mounted || tab != _tabs[_tab].$1) return;
      setState(() {
        _orders = orders;
        _loading = false;
        _error = null;
      });
      _syncTick();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  /// Hitung mundur hanya saat ada pesanan menunggu bayar.
  void _syncTick() {
    if (_orders.any((o) => o.isHolding)) {
      _tick ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else {
      _tick?.cancel();
      _tick = null;
    }
  }

  void _selectTab(int i) {
    if (i == _tab) return;
    setState(() {
      _tab = i;
      _orders = const [];
      _loading = true;
      _error = null;
    });
    _load();
  }

  List<Order> get _visible {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _orders;
    return _orders.where((o) {
      return o.code.toLowerCase().contains(q) ||
          o.merchantName.toLowerCase().contains(q) ||
          o.items.any((i) => i.menuName.toLowerCase().contains(q));
    }).toList();
  }

  Future<void> _open(Order order, {bool pay = false}) async {
    await Navigator.pushNamed(
      context,
      pay ? AppRoutes.payment : AppRoutes.orderDetail,
      arguments: order.code,
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  if (canPop)
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 18),
                      onPressed: () => Navigator.pop(context),
                    ),
                  if (canPop) const SizedBox(width: 10),
                  Text('Pesanan', style: AppTextStyles.h2),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Cari kode, toko, atau menu…',
                  hintStyle: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textMuted, fontSize: 13),
                  prefixIcon: Icon(Icons.search_rounded,
                      size: 20, color: AppColors.textMuted),
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _tabs.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final selected = i == _tab;
                  return GestureDetector(
                    onTap: () => _selectTab(i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primary : AppColors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : AppColors.cardBorder,
                        ),
                      ),
                      child: Text(
                        _tabs[i].$2,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: selected ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return _Message(
        icon: Icons.cloud_off_rounded,
        title: _error!,
        action: 'Coba lagi',
        onAction: () {
          setState(() => _loading = true);
          _load();
        },
      );
    }
    final orders = _visible;
    if (orders.isEmpty) {
      final searching = _searchController.text.trim().isNotEmpty;
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            SizedBox(
              height: 420,
              child: _Message(
                icon: Icons.receipt_long_rounded,
                title: searching
                    ? 'Tidak ada pesanan yang cocok'
                    : switch (_tab) {
                        0 => 'Belum ada pesanan aktif',
                        1 => 'Belum ada pesanan selesai',
                        _ => 'Tidak ada pesanan dibatalkan',
                      },
                action: searching ? null : 'Jelajahi Menu Katering',
                onAction: searching
                    ? null
                    : () => Navigator.pushNamedAndRemoveUntil(
                        context, AppRoutes.mainNav, (route) => false),
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
        itemCount: orders.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _OrderCard(
          order: orders[i],
          onTap: () => _open(orders[i]),
          onPay: orders[i].isHolding ? () => _open(orders[i], pay: true) : null,
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onTap, this.onPay});
  final Order order;
  final VoidCallback onTap;
  final VoidCallback? onPay;

  @override
  Widget build(BuildContext context) {
    final first = order.items.firstOrNull;
    final more = order.items.length - 1;
    final created = order.createdAt;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.storefront_rounded,
                    size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    order.merchantName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                OrderStatusChip(order.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              first == null
                  ? '-'
                  : '${first.menuName} ×${first.qty}'
                      '${more > 0 ? ' +$more lainnya' : ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  order.code,
                  style: AppTextStyles.bodySmall.copyWith(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
                if (created != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    AppTime.date(created),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  AppCurrency.format(order.total),
                  style: AppTextStyles.price.copyWith(fontSize: 14),
                ),
              ],
            ),
            if (onPay != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 38,
                child: ElevatedButton(
                  onPressed: onPay,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'Bayar sekarang • ${AppTime.mmss(order.remainingSeconds())}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    this.action,
    this.onAction,
  });
  final IconData icon;
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.h4.copyWith(fontSize: 15),
            ),
            if (action != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(action!,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
