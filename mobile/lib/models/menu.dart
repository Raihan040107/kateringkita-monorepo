import 'json.dart';
import 'meta.dart';

class MerchantRef {
  const MerchantRef({
    required this.id,
    required this.slug,
    required this.businessName,
    required this.isOpen,
  });
  final int id;
  final String slug;
  final String businessName;
  final bool isOpen;

  factory MerchantRef.fromJson(Map<String, dynamic> j) => MerchantRef(
        id: asInt(j['id']),
        slug: '${j['slug'] ?? ''}',
        businessName: '${j['business_name'] ?? ''}',
        isOpen: asBool(j['is_open']),
      );
}

/// Kartu menu di katalog (`GET /menus`, `GET /me/favorites`).
class MenuCard {
  const MenuCard({
    required this.id,
    required this.name,
    required this.price,
    required this.unitLabel,
    required this.category,
    required this.merchant,
    required this.available,
    required this.badge,
    required this.ratingAvg,
    required this.ratingCount,
    required this.isFavorite,
    this.imageUrl,
  });

  final int id;
  final String name;
  final String? imageUrl;
  final int price;
  final String unitLabel;
  final Category category;
  final MerchantRef merchant;
  final int available;

  /// `sold_out` | `preorder` | `low_stock` | `available`
  final String badge;
  final double ratingAvg;
  final int ratingCount;
  final bool isFavorite;

  bool get canOrder => merchant.isOpen && available > 0;

  factory MenuCard.fromJson(Map<String, dynamic> j) => MenuCard(
        id: asInt(j['id']),
        name: '${j['name'] ?? ''}',
        imageUrl: asStringOrNull(j['image_url']),
        price: asInt(j['price']),
        unitLabel: '${j['unit_label'] ?? 'porsi'}',
        category: Category.fromJson(asMap(j['category'])),
        merchant: MerchantRef.fromJson(asMap(j['merchant'])),
        available: asInt(j['available']),
        badge: '${j['badge'] ?? 'available'}',
        ratingAvg: asDouble(j['rating_avg']),
        ratingCount: asInt(j['rating_count']),
        isFavorite: asBool(j['is_favorite']),
      );

  MenuCard copyWith({bool? isFavorite}) => MenuCard(
        id: id,
        name: name,
        imageUrl: imageUrl,
        price: price,
        unitLabel: unitLabel,
        category: category,
        merchant: merchant,
        available: available,
        badge: badge,
        ratingAvg: ratingAvg,
        ratingCount: ratingCount,
        isFavorite: isFavorite ?? this.isFavorite,
      );
}

class MenuOption {
  const MenuOption({required this.id, required this.name, required this.extraPrice});
  final int id;
  final String name;
  final int extraPrice;

  factory MenuOption.fromJson(Map<String, dynamic> j) => MenuOption(
        id: asInt(j['id']),
        name: '${j['name'] ?? ''}',
        extraPrice: asInt(j['extra_price']),
      );
}

/// `GET /menus/:id`
class MenuDetail {
  const MenuDetail({
    required this.card,
    required this.options,
    required this.minOrderQty,
    required this.prepMinutes,
    required this.isPreorder,
    required this.preorderDays,
    required this.openTime,
    required this.closeTime,
    required this.pickupPoints,
    this.description,
    this.logoUrl,
  });

  final MenuCard card;
  final String? description;
  final List<MenuOption> options;
  final int minOrderQty;
  final int prepMinutes;
  final bool isPreorder;
  final int preorderDays;
  final String? logoUrl;
  final String openTime;
  final String closeTime;
  final List<PickupPoint> pickupPoints;

  factory MenuDetail.fromJson(Map<String, dynamic> j) {
    final m = asMap(j['merchant']);
    return MenuDetail(
      card: MenuCard.fromJson(j),
      description: asStringOrNull(j['description']),
      options: asList(j['options']).map(MenuOption.fromJson).toList(),
      minOrderQty: asInt(j['min_order_qty'], 1),
      prepMinutes: asInt(j['prep_minutes']),
      isPreorder: asBool(j['is_preorder']),
      preorderDays: asInt(j['preorder_days']),
      logoUrl: asStringOrNull(m['logo_url']),
      openTime: '${m['open_time'] ?? ''}',
      closeTime: '${m['close_time'] ?? ''}',
      pickupPoints: asList(m['pickup_points']).map(PickupPoint.fromJson).toList(),
    );
  }
}

class MenuReview {
  const MenuReview({
    required this.rating,
    required this.customerName,
    required this.createdAt,
    this.comment,
  });
  final int rating;
  final String? comment;
  final String customerName;
  final DateTime? createdAt;

  factory MenuReview.fromJson(Map<String, dynamic> j) => MenuReview(
        rating: asInt(j['rating']),
        comment: asStringOrNull(j['comment']),
        customerName: '${j['customer_name'] ?? 'Pembeli'}',
        createdAt: asDate(j['created_at']),
      );
}
