import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_currency.dart';
import '../../core/app_routes.dart';
import '../../core/app_text_styles.dart';
import '../../models/cart_line.dart';
import '../../models/menu.dart';
import '../../services/api_client.dart';
import '../../services/catalog_api.dart';
import '../../widgets/food_card.dart';
import '../../widgets/menu_image.dart';
import '../../widgets/primary_button.dart';

/// Detail menu (`GET /menus/:id` + ulasan). Argumen rute: `int menuId`.
class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int? _menuId;
  MenuDetail? _detail;
  List<MenuReview> _reviews = const [];
  final Set<int> _selectedOptionIds = {};
  bool _loading = true;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_menuId != null || _error != null) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is int) {
      _menuId = args;
      _load();
    } else {
      // layar lama (pencarian, profil toko, riwayat) masih mengirim model contoh
      _loading = false;
      _error = 'Menu tidak ditemukan.';
    }
  }

  Future<void> _load() async {
    final api = context.read<ApiClient>();
    if (!_loading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final detail = await api.menu(_menuId!);
      var reviews = const <MenuReview>[];
      try {
        reviews = await api.menuReviews(_menuId!);
      } on ApiException {
        // ulasan opsional
      }
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _reviews = reviews;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.status == 404 ? 'Menu tidak ditemukan.' : e.message;
        _loading = false;
      });
    }
  }

  List<MenuOption> get _selectedOptions => _detail!.options
      .where((o) => _selectedOptionIds.contains(o.id))
      .toList();

  int get _unitTotal =>
      _detail!.card.price +
      _selectedOptions.fold(0, (sum, o) => sum + o.extraPrice);

  String _quotaText(MenuDetail d) {
    final c = d.card;
    if (!c.merchant.isOpen) return 'Toko sedang tutup. Menu belum bisa dipesan.';
    return switch (c.badge) {
      'sold_out' => 'Kuota hari ini sudah habis.',
      'low_stock' =>
        '🔥 Hanya tersisa ${c.available} ${c.unitLabel} untuk kuota hari ini!',
      'preorder' =>
        'Pre-order: waktu ambil dipilih saat checkout (maks. H+${d.preorderDays}).',
      _ => 'Tersedia ${c.available} ${c.unitLabel} untuk hari ini.',
    };
  }

  void _addToOrders() {
    final d = _detail!;
    final opts = _selectedOptions;
    Navigator.pushNamed(
      context,
      AppRoutes.checkout,
      arguments: <CartLine>[
        CartLine(
          menuId: d.card.id,
          name: d.card.name,
          imageUrl: d.card.imageUrl,
          qty: d.minOrderQty < 1 ? 1 : d.minOrderQty,
          optionIds: [for (final o in opts) o.id],
          optionNames: [for (final o in opts) o.name],
          isPreorder: d.isPreorder,
          unitPrice: _unitTotal,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = _detail;
    if (d == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
        ),
        body: Center(
          child: _loading
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.no_meals_rounded,
                        size: 48, color: AppColors.textMuted),
                    const SizedBox(height: 12),
                    Text(_error ?? 'Menu tidak ditemukan.',
                        style: AppTextStyles.bodyMedium),
                    if (_menuId != null)
                      TextButton(
                          onPressed: _load, child: const Text('Coba lagi')),
                  ],
                ),
        ),
      );
    }

    final c = d.card;
    final canOrder = c.canOrder;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Foto menu
                MenuImage(c.imageUrl,
                    width: double.infinity, height: 340, iconSize: 64),

                // Sheet Content
                Transform.translate(
                  offset: const Offset(0, -16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(28)),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 16,
                          offset: Offset(0, -4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.name,
                          style: AppTextStyles.h1.copyWith(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${AppCurrency.format(c.price)} / ${c.unitLabel}',
                          style: AppTextStyles.price.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _RatingRow(avg: c.ratingAvg, count: c.ratingCount),
                        const SizedBox(height: 16),

                        // Kuota / status
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: canOrder
                                ? AppColors.primarySoft
                                : AppColors.dangerLight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: (canOrder
                                      ? AppColors.primary
                                      : AppColors.danger)
                                  .withValues(alpha: 0.28),
                            ),
                          ),
                          child: Text(
                            _quotaText(d),
                            style: AppTextStyles.bodySmall.copyWith(
                              color: canOrder
                                  ? AppColors.primaryDark
                                  : AppColors.danger,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Kartu toko (tanpa navigasi: profil toko ditunda)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          child: Row(
                            children: [
                              MenuImage(
                                d.logoUrl,
                                width: 48,
                                height: 48,
                                radius: 12,
                                iconSize: 24,
                                icon: Icons.storefront_rounded,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.verified_rounded,
                                          color: AppColors.primary,
                                          size: 15,
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            c.merchant.businessName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTextStyles.h4.copyWith(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${d.openTime} – ${d.closeTime} WIB • Siap ±${d.prepMinutes} mnt',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.bodySmall.copyWith(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              _StatusChip(open: c.merchant.isOpen),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        if (d.description != null &&
                            d.description!.isNotEmpty) ...[
                          Text('Deskripsi',
                              style: AppTextStyles.h3.copyWith(fontSize: 16)),
                          const SizedBox(height: 8),
                          Text(
                            d.description!,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.5,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        if (d.minOrderQty > 1) ...[
                          Text(
                            'Minimal pesan ${d.minOrderQty} ${c.unitLabel}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        if (d.options.isNotEmpty) ...[
                          Text('Pilihan Tambahan',
                              style: AppTextStyles.h3.copyWith(fontSize: 16)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            children: [
                              for (final opt in d.options)
                                _OptionChip(
                                  option: opt,
                                  selected: _selectedOptionIds.contains(opt.id),
                                  onTap: () => setState(() {
                                    if (!_selectedOptionIds.remove(opt.id)) {
                                      _selectedOptionIds.add(opt.id);
                                    }
                                  }),
                                ),
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],

                        if (_reviews.isNotEmpty) ...[
                          Text('Ulasan (${c.ratingCount})',
                              style: AppTextStyles.h3.copyWith(fontSize: 16)),
                          const SizedBox(height: 8),
                          for (final r in _reviews.take(3)) _ReviewTile(r),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Tombol kembali & favorit
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _RoundButton(
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 18),
                      color: AppColors.textPrimary,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  _RoundButton(child: FavoriteButton(c, size: 20)),
                ],
              ),
            ),
          ),

          // Tombol pesan
          Positioned(
            left: 20,
            right: 20,
            bottom: 24,
            child: PrimaryButton(
              text: canOrder
                  ? 'Add to Orders • ${AppCurrency.format(_unitTotal)}'
                  : c.merchant.isOpen
                      ? 'Kuota Habis'
                      : 'Toko Tutup',
              onPressed: canOrder ? _addToOrders : null,
              gradient: canOrder ? AppColors.primaryGradient : null,
              backgroundColor: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
          ),
        ],
      ),
      child: child,
    );
  }
}

class _RatingRow extends StatelessWidget {
  const _RatingRow({required this.avg, required this.count});
  final double avg;
  final int count;

  @override
  Widget build(BuildContext context) {
    final filled = avg.round();
    return Row(
      children: [
        Row(
          children: List.generate(
            5,
            (i) => Icon(
              i < filled ? Icons.star_rounded : Icons.star_outline_rounded,
              color: AppColors.warning,
              size: 18,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            count == 0
                ? 'Belum ada ulasan'
                : '${avg.toStringAsFixed(1)} ($count ulasan)',
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.open});
  final bool open;

  @override
  Widget build(BuildContext context) {
    final color = open ? AppColors.success : AppColors.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: open ? AppColors.successLight : AppColors.dangerLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        open ? 'Buka' : 'Tutup',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _OptionChip extends StatelessWidget {
  const _OptionChip({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final MenuOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final extra = option.extraPrice > 0
        ? ' +${AppCurrency.format(option.extraPrice)}'
        : '';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryBackground : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.cardBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          '${selected ? '✓ ' : ''}${option.name}$extra',
          style: AppTextStyles.bodySmall.copyWith(
            color: selected ? AppColors.primary : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile(this.review);
  final MenuReview review;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  review.customerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.h4.copyWith(fontSize: 13),
                ),
              ),
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < review.rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: AppColors.warning,
                    size: 14,
                  ),
                ),
              ),
            ],
          ),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              review.comment!,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
