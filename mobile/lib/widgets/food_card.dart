import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_colors.dart';
import '../core/app_currency.dart';
import '../core/app_text_styles.dart';
import '../data/liked_store.dart';
import '../models/menu.dart';
import '../services/api_client.dart';
import 'menu_image.dart';

/// Label badge katalog: (teks, warna) atau null bila tersedia normal.
(String, Color)? menuBadge(MenuCard menu) => switch (menu.badge) {
      'sold_out' => ('Habis', AppColors.danger),
      'low_stock' => ('Sisa ${menu.available}', AppColors.success),
      'preorder' => ('Pre-order', AppColors.blue),
      _ => null,
    };

/// Tombol hati yang terhubung ke [LikedStore]; dipakai kartu dan detail menu.
class FavoriteButton extends StatelessWidget {
  const FavoriteButton(this.menu, {super.key, this.size = 18});
  final MenuCard menu;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<MenuCard>>(
      valueListenable: LikedStore.favorites,
      builder: (context, _, _) {
        final liked = LikedStore.isLiked(menu.id);
        return IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: Icon(
            liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            size: size,
            color: liked ? AppColors.danger : AppColors.textPrimary,
          ),
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            try {
              final nowLiked =
                  await LikedStore.toggle(context.read<ApiClient>(), menu);
              messenger.showSnackBar(SnackBar(
                content: Text(nowLiked
                    ? 'Ditambahkan ke favorit: ${menu.name}'
                    : 'Dihapus dari favorit: ${menu.name}'),
                duration: const Duration(seconds: 1),
              ));
            } on ApiException catch (e) {
              messenger.showSnackBar(SnackBar(content: Text(e.message)));
            }
          },
        );
      },
    );
  }
}

class FoodGridCard extends StatelessWidget {
  final MenuCard menu;
  final VoidCallback onTap;

  const FoodGridCard({
    super.key,
    required this.menu,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final badge = menuBadge(menu);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Foto, badge, hati
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      child: MenuImage(menu.imageUrl),
                    ),
                  ),
                  if (badge != null)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: badge.$2,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Text(
                          badge.$1,
                          style: AppTextStyles.badge.copyWith(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                      ),
                      child: FavoriteButton(menu, size: 16),
                    ),
                  ),
                ],
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    menu.name,
                    style: AppTextStyles.h4.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(
                        Icons.storefront_rounded,
                        size: 11.5,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          menu.merchant.businessName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySmall.copyWith(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          AppCurrency.format(menu.price),
                          style: AppTextStyles.price.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, color: AppColors.warning, size: 14),
                          const SizedBox(width: 2),
                          Text(
                            menu.ratingCount == 0
                                ? 'Baru'
                                : menu.ratingAvg.toStringAsFixed(1),
                            style: AppTextStyles.bodySmall.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
