import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/bem_colors.dart';
import '../../address/map_sheet.dart';

/// Шапка «назад + адрес + корзина» — порт `AddressTopBar.tsx` 1:1.
/// Адрес-плашка — «матовое стекло» (glass), по тапу откроется выбор адреса
/// (TopAddressSheet — отдельный этап). Справа — корзина со счётчиком.
class AddressTopBar extends ConsumerWidget {
  const AddressTopBar({super.key, required this.address, this.backFallback = '/home'});

  final String address;
  final String backFallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 10, 16, 0),
      child: Row(
        children: [
          _squareBtn(
            child: const Icon(Icons.chevron_left, size: 24, color: Color(0xFF55555A)),
            onTap: () => context.canPop() ? context.pop() : context.go(backFallback),
          ),
          const SizedBox(width: 8),
          // Адрес — стеклянная плашка.
          Expanded(
            child: GestureDetector(
              onTap: () => showAddressMapSheet(context, ref),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.62),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
                      // rgba(40,30,20,0.22)
                      boxShadow: const [
                        BoxShadow(color: Color(0x38281E14), blurRadius: 32, spreadRadius: -16, offset: Offset(0, 12)),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on_outlined, size: 16, color: BemColors.coral),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            address.isEmpty ? 'Выберите адрес' : address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600, color: BemColors.ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down, size: 16, color: BemColors.mute),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _squareBtn({required Widget child, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 3))],
        ),
        child: child,
      ),
    );
  }
}
