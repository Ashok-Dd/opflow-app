import '../../l10n/lang.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../theme/text.dart';
import '../../theme/tokens.dart';

class NavItem {
  const NavItem(this.label, this.icon, this.activeIcon);

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

/// Bottom bar used by both sides. Words are always shown; the selected tab gets a soft green highlight.
class OpBottomNav extends StatelessWidget {
  const OpBottomNav({super.key, required this.items, required this.index, required this.onTap, this.badges = const {}});

  final List<NavItem> items;
  final int index;
  final ValueChanged<int> onTap;
  final Map<int, int> badges;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: OpColors.card,
        borderRadius: OpRadius.sheetTop,
        boxShadow: OpShadow.bar,
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 74,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: Semantics(
                    selected: i == index,
                    button: true,
                    label: items[i].label.tr,
                    excludeSemantics: true,
                    child: InkWell(
                      borderRadius: OpRadius.controlAll,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onTap(i);
                      },
                      child: Stack(
                        children: [
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    AnimatedContainer(
                                      duration: OpMotion.quick,
                                      curve: OpMotion.curve,
                                      width: i == index ? 60 : 44,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: i == index ? OpColors.mint : Colors.transparent,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Icon(i == index ? items[i].activeIcon : items[i].icon,
                                          color: i == index ? OpColors.forest : OpColors.inkSoft, size: 23),
                                    ),
                                    if ((badges[i] ?? 0) > 0)
                                      Positioned(
                                        right: 2,
                                        top: -3,
                                        child: Container(
                                          constraints: const BoxConstraints(minWidth: 18),
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: OpColors.alarm,
                                            borderRadius: BorderRadius.circular(9),
                                            border: Border.all(color: OpColors.card, width: 1.5),
                                          ),
                                          child: Text('${badges[i]}', style: OpText.mono(10, color: Colors.white, weight: FontWeight.w600)),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  items[i].label.tr,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: OpText.smallStrong.copyWith(
                                    fontSize: 12.5,
                                    color: i == index ? OpColors.forest : OpColors.inkSoft,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class PatientShell extends StatelessWidget {
  const PatientShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const items = [
    NavItem('Home', Icons.home_outlined, Icons.home),
    NavItem('Find doctor', Icons.search, Icons.manage_search),
    NavItem('My bookings', Icons.confirmation_number_outlined, Icons.confirmation_number),
    NavItem('Me', Icons.person_outline, Icons.person),
  ];

  @override
  Widget build(BuildContext context) {
    // Back on another tab goes to Home first, instead of closing the app.
    return PopScope(
      canPop: shell.currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) shell.goBranch(0);
      },
      child: Scaffold(
        body: shell,
        bottomNavigationBar: OpBottomNav(
          items: items,
          index: shell.currentIndex,
          onTap: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        ),
      ),
    );
  }
}
