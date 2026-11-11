import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_currency.dart';
import '../../core/app_routes.dart';
import '../../core/app_text_styles.dart';
import '../../data/liked_store.dart';
import '../../models/menu.dart';
import '../../services/api_client.dart';
import '../../widgets/food_card.dart';
import '../../widgets/menu_image.dart';

class LikedScreen extends StatefulWidget {
  const LikedScreen({super.key});

  @override
  State<LikedScreen> createState() => _LikedScreenState();
}

class _LikedScreenState extends State<LikedScreen> {
  @override
  void initState() {
    super.initState();
    // segarkan dari server tiap layar dibuka (favorit bisa berubah di perangkat lain)
    LikedStore.load(context.read<ApiClient>());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: ValueListenableBuilder<List<MenuCard>>(
          valueListenable: LikedStore.favorites,
          builder: (context, liked, child) {
            return RefreshIndicator(
              onRefresh: () => LikedStore.load(context.read<ApiClient>()),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Liked',
                      style: AppTextStyles.h2.copyWith(fontSize: 24),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${liked.length} Menu Favorit Tersimpan',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (liked.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 60),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  color: AppColors.dangerLight,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.favorite_border_rounded,
                                  size: 32,
                                  color: AppColors.danger,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Belum ada menu favorit',
                                style: AppTextStyles.h3.copyWith(fontSize: 16),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Tekan ikon hati pada menu untuk menyimpannya di sini.',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: liked.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final menu = liked[index];
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: AppColors.cardBorder
                                      .withValues(alpha: 0.8)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                MenuImage(menu.imageUrl,
                                    width: 60, height: 60, radius: 12, iconSize: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        menu.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextStyles.h4
                                            .copyWith(fontSize: 14),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        menu.merchant.businessName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextStyles.bodySmall.copyWith(
                                            color: AppColors.textSecondary,
                                            fontSize: 11),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        AppCurrency.format(menu.price),
                                        style: AppTextStyles.price
                                            .copyWith(fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                                FavoriteButton(menu, size: 22),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.pushNamed(
                                      context,
                                      AppRoutes.productDetail,
                                      arguments: menu.id,
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      gradient: AppColors.primaryGradient,
                                      borderRadius: BorderRadius.circular(18),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primary
                                              .withValues(alpha: 0.3),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      '+ Order',
                                      style: AppTextStyles.button.copyWith(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
