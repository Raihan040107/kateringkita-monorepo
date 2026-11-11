import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_routes.dart';
import '../../core/app_text_styles.dart';
import '../../models/menu.dart';
import '../../models/meta.dart';
import '../../providers/session_provider.dart';
import '../../services/api_client.dart';
import '../../services/auth_api.dart';
import '../../services/catalog_api.dart';
import '../../services/meta_api.dart';
import '../../widgets/food_card.dart';
import '../orders/pickup_point_picker_screen.dart';

class HomeScreen extends StatefulWidget {
  final Function(int)? onTabChange;

  const HomeScreen({super.key, this.onTabChange});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Category> _categories = const [];
  List<PickupPoint> _pickupPoints = const [];
  List<MenuCard> _menus = const [];

  /// null = semua kategori
  Category? _selectedCategory;
  bool _loading = true;
  String? _error;

  ApiClient get _api => context.read<ApiClient>();
  int? get _favoritePickupPointId =>
      context.read<SessionProvider>().user?.favoritePickupPointId;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  /// Kategori + titik temu, lalu menu.
  Future<void> _loadAll() async {
    try {
      final (categories, pickupPoints) =
          await (_api.categories(), _api.pickupPoints()).wait;
      _categories = categories;
      _pickupPoints = pickupPoints;
    } on ParallelWaitError {
      // chip kategori/titik temu kosong; menu tetap dimuat
    }
    await _loadMenus();
  }

  Future<void> _loadMenus() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final menus = await _api.menus(
        category: _selectedCategory?.slug,
        pickupPointId: _favoritePickupPointId,
      );
      if (!mounted) return;
      setState(() {
        _menus = menus;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  void _selectCategory(Category? category) {
    if (category?.id == _selectedCategory?.id) return;
    _selectedCategory = category;
    _loadMenus();
  }

  /// Titik temu favorit disimpan di server (`PATCH /me`), lalu katalog
  /// disaring dengan `pickup_point_id`.
  Future<void> _pickPickupPoint() async {
    final session = context.read<SessionProvider>();
    final picked = await Navigator.push<PickupPoint>(
      context,
      MaterialPageRoute(
        builder: (_) => PickupPointPickerScreen(
          selectedId: session.user?.favoritePickupPointId,
          points: _pickupPoints.isEmpty ? null : _pickupPoints,
        ),
      ),
    );
    if (picked == null || !mounted) return;
    try {
      session.setUser(
          await _api.updateMe({'favorite_pickup_point_id': picked.id}));
      if (!_pickupPoints.any((p) => p.id == picked.id)) {
        _pickupPoints = [..._pickupPoints, picked];
      }
      await _loadMenus();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _showCategoryFilterSheet() {
    final items = <Category?>[null, ..._categories];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: AppColors.surface,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Pilih Kategori Menu',
                      style: AppTextStyles.h3.copyWith(fontSize: 18),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final isSelected = item?.id == _selectedCategory?.id;
                      return ListTile(
                        leading: Icon(
                          item == null
                              ? Icons.restaurant_menu_rounded
                              : Icons.label_rounded,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                        title: Text(
                          item?.name ?? 'Semua Menu',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textPrimary,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle_rounded,
                                color: AppColors.primary)
                            : null,
                        onTap: () {
                          Navigator.pop(context);
                          _selectCategory(item);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final favoriteId =
        context.watch<SessionProvider>().user?.favoritePickupPointId;
    final pickupName =
        _pickupPoints.where((p) => p.id == favoriteId).firstOrNull?.name;
    final hasCategory = _selectedCategory != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _loadAll,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---------------- TOP BAR ----------------
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'KateringKita',
                            style: AppTextStyles.h2.copyWith(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          GestureDetector(
                            onTap: _pickPickupPoint,
                            child: Row(
                              children: [
                                const Icon(Icons.location_on,
                                    size: 14, color: AppColors.primary),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    '${pickupName ?? 'Pilih titik temu'} ▾',
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Lonceng notifikasi (badge belum dibaca menyusul di Fase 4)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        Navigator.pushNamed(context, AppRoutes.notifications);
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppColors.cardBorder.withValues(alpha: 0.8)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.notifications_outlined,
                          color: AppColors.textPrimary,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ---------------- FILTER BAR ----------------
                // Pencarian teks ditunda; bilah ini membuka pilihan kategori.
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.cardBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search, color: AppColors.textMuted, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _showCategoryFilterSheet,
                          child: Text(
                            hasCategory
                                ? 'Kategori: ${_selectedCategory!.name}'
                                : 'Pilih kategori menu...',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: hasCategory
                                  ? AppColors.primary
                                  : AppColors.textMuted,
                              fontSize: 13,
                              fontWeight: hasCategory
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      if (hasCategory)
                        GestureDetector(
                          onTap: () => _selectCategory(null),
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Icon(Icons.close_rounded,
                                color: AppColors.textMuted, size: 18),
                          ),
                        ),
                      GestureDetector(
                        onTap: _showCategoryFilterSheet,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: hasCategory
                                ? AppColors.primarySoft
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.tune_rounded,
                            color: hasCategory
                                ? AppColors.primary
                                : AppColors.textPrimary,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // ---------------- CATEGORY PILLS ----------------
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final category in <Category?>[null, ..._categories])
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: _CategoryChip(
                            label: category?.name ?? 'Semua',
                            selected: category?.id == _selectedCategory?.id,
                            onTap: () => _selectCategory(
                              // klik kategori yang sama → kembali ke Semua
                              category?.id == _selectedCategory?.id
                                  ? null
                                  : category,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ---------------- DAFTAR MENU HEADER ----------------
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_selectedCategory?.name ?? 'Daftar Menu'} (${_menus.length})',
                      style: AppTextStyles.h3.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Semua halal & higienis',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // ---------------- PRODUCT GRID ----------------
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null)
                  _Message(
                    icon: Icons.wifi_off_rounded,
                    text: _error!,
                    action: 'Coba lagi',
                    onAction: _loadMenus,
                  )
                else if (_menus.isEmpty)
                  _Message(
                    icon: Icons.storefront_outlined,
                    text: 'Belum ada menu buka saat ini',
                    action: hasCategory
                        ? 'Tampilkan Semua Menu'
                        : favoriteId != null
                            ? 'Ganti titik temu'
                            : null,
                    onAction: hasCategory
                        ? () => _selectCategory(null)
                        : _pickPickupPoint,
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _menus.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.76,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 16,
                    ),
                    itemBuilder: (context, index) {
                      final menu = _menus[index];
                      return FoodGridCard(
                        menu: menu,
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            AppRoutes.productDetail,
                            arguments: menu.id,
                          );
                        },
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.cardBorder,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: selected ? Colors.white : AppColors.textPrimary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.text,
    this.action,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(icon, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: AppTextStyles.h4.copyWith(fontSize: 14),
          ),
          if (action != null) ...[
            const SizedBox(height: 6),
            TextButton(onPressed: onAction, child: Text(action!)),
          ],
        ],
      ),
    );
  }
}
