import 'package:flutter/material.dart';

import '../core/app_colors.dart';

/// Foto menu dari URL; null/gagal → kotak abu dengan ikon makanan.
class MenuImage extends StatelessWidget {
  const MenuImage(
    this.url, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.radius = 0,
    this.iconSize = 32,
    this.icon = Icons.fastfood_rounded,
  });

  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double radius;
  final double iconSize;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: width,
      height: height,
      color: AppColors.secondaryBg,
      alignment: Alignment.center,
      child: Icon(icon, size: iconSize, color: AppColors.textMuted),
    );
    final child = (url == null || url!.isEmpty)
        ? placeholder
        : Image.network(
            url!,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (_, _, _) => placeholder,
          );
    return radius > 0
        ? ClipRRect(borderRadius: BorderRadius.circular(radius), child: child)
        : child;
  }
}
