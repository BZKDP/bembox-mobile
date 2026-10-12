import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/bem_colors.dart';
import '../category_icons.dart';

/// Плитка категории — порт `PagerTile` (дашборд, size 78) и `PcatChip`
/// (категория, size 92). Тонированный квадрат с иконкой из /cat-icons или
/// Package-контуром, подпись в 2 строки. 1:1 с прод-исходником.
class CategoryTile extends StatelessWidget {
  const CategoryTile({
    super.key,
    required this.name,
    required this.onTap,
    this.parentName,
    this.size = 78,
    this.labelWeight = FontWeight.w600,
  });

  final String name;
  final String? parentName;
  final VoidCallback onTap;
  final double size;
  final FontWeight labelWeight;

  @override
  Widget build(BuildContext context) {
    final icon = categoryIconUrl(name, parentName: parentName);
    final radius = size >= 90 ? 20.0 : 18.0;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: size,
              height: size,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(color: categoryTint(name), borderRadius: BorderRadius.circular(radius)),
              alignment: Alignment.center,
              child: icon == null
                  ? Icon(Icons.inventory_2_outlined, size: size >= 90 ? 36 : 32, color: const Color(0x4D1A1410))
                  : CachedNetworkImage(
                      imageUrl: icon,
                      fit: BoxFit.contain,
                      placeholder: (_, _) => const SizedBox(),
                      errorWidget: (_, _, _) => Icon(Icons.inventory_2_outlined, size: size >= 90 ? 36 : 32, color: const Color(0x4D1A1410)),
                    ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 28,
              child: Text(
                name,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, height: 1.2, fontWeight: labelWeight, color: BemColors.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
