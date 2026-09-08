import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../utils/trackit_responsive.dart';
import 'trackit_decorations.dart';

/// Scrollable page body used inside [TrackitMainShell] (no nested Scaffold).
class TrackitPageLayout extends StatelessWidget {
  const TrackitPageLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.body,
    this.bottomPadding,
    this.heroTrailing,
    this.onRefresh,
    this.showHero = true,
    this.topPadding = 0,
  });

  final String title;
  final String subtitle;
  final Widget body;
  final double? bottomPadding;
  final Widget? heroTrailing;
  final Future<void> Function()? onRefresh;
  final bool showHero;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    final layout = context.layout;
    final horizontal = layout.pageHorizontalPadding;
    final bottom = bottomPadding ?? layout.scrollBottomPadding;

    return RefreshIndicator(
      color: AppTheme.red,
      onRefresh: onRefresh ?? () async {},
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (showHero)
            SliverToBoxAdapter(
              child: TrackitPageHero(
                title: title,
                subtitle: subtitle,
                trailing: heroTrailing,
              ),
            ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(horizontal, topPadding, horizontal, bottom),
            sliver: SliverToBoxAdapter(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [body],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
