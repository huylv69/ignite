import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/theme/app_theme.dart';

/// Shimmering placeholders sized to match the real content, so the swap from
/// loading to loaded does not shift the layout.
class _Shimmer extends StatelessWidget {
  final Widget child;
  const _Shimmer({required this.child});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppTheme.bgElevated,
      highlightColor: AppTheme.border,
      child: child,
    );
  }
}

class _Block extends StatelessWidget {
  final double width;
  final double height;
  final double radius;
  const _Block(this.width, this.height, {this.radius = 6});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.bgElevated,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Placeholder for one app row on the home screen.
class AppCardSkeleton extends StatelessWidget {
  const AppCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _Shimmer(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const _Block(44, 44, radius: 12),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  _Block(140, 13),
                  SizedBox(height: 8),
                  _Block(200, 10),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Placeholder for one build row.
class BuildItemSkeleton extends StatelessWidget {
  const BuildItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _Shimmer(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Block(28, 28, radius: 14),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _Block(120, 13),
                    SizedBox(height: 8),
                    _Block(220, 11),
                    SizedBox(height: 10),
                    _Block(90, 10),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Placeholder for the stats tab: one wide chart card over a 2x2 tile grid.
class StatsSkeleton extends StatelessWidget {
  const StatsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _Shimmer(
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const _Block(160, 160, radius: 80),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        _Block(110, 12),
                        SizedBox(height: 12),
                        _Block(110, 12),
                        SizedBox(height: 12),
                        _Block(110, 12),
                        SizedBox(height: 12),
                        _Block(90, 12),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: List.generate(
              4,
              (_) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      _Block(22, 22, radius: 6),
                      SizedBox(height: 10),
                      _Block(60, 20),
                      SizedBox(height: 6),
                      _Block(80, 10),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A list of [AppCardSkeleton]s for the home screen's loading state.
class AppListSkeleton extends StatelessWidget {
  final int count;
  const AppListSkeleton({super.key, this.count = 5});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        count,
        (_) => const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: AppCardSkeleton(),
        ),
      ),
    );
  }
}
