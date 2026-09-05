import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../analytics/analytics_event.dart';
import '../../analytics/analytics_providers.dart';
import '../../analytics/app_events.dart';
import '../../l10n/app_strings.dart';
import '../../location/location_opt_in.dart';
import '../../router/routes.dart';
import '../../theme/app_spacing.dart';
import '../onboarding_providers.dart';

class _OnboardingSlide {
  const _OnboardingSlide({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}

const List<_OnboardingSlide> _slides = [
  _OnboardingSlide(
    icon: Icons.sports_basketball,
    title: AppStrings.onboardingSlide1Title,
    description: AppStrings.onboardingSlide1Description,
  ),
  _OnboardingSlide(
    icon: Icons.public,
    title: AppStrings.onboardingSlide2Title,
    description: AppStrings.onboardingSlide2Description,
  ),
  _OnboardingSlide(
    icon: Icons.my_location,
    title: AppStrings.onboardingSlide3Title,
    description: AppStrings.onboardingSlide3Description,
  ),
];

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _pageController = PageController();
  int _currentPage = 0;

  bool get _isLastPage => _currentPage == _slides.length - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Leaves onboarding for the app.
  ///
  /// Only [OnboardingExit.getStarted] opts into a location, and that is the
  /// whole point of the last slide: the system permission dialog only ever
  /// appears because the user pressed a button asking for their courts,
  /// never because they reached the end of a carousel. Skipping, or browsing
  /// without location, opts into nothing.
  Future<void> _finish(OnboardingExit exit) async {
    if (exit == OnboardingExit.getStarted) {
      await ref
          .read(locationOptInProvider.notifier)
          .optIn(LocationEntryPoint.onboarding);
    }
    unawaited(
      ref.read(analyticsProvider).log(AppEvents.onboardingCompleted(exit)),
    );
    await ref.read(onboardingCompletedProvider.notifier).complete();
    if (!mounted) return;
    context.go(Routes.home);
  }

  void _next() {
    if (_isLastPage) {
      _finish(OnboardingExit.getStarted);
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: TextButton(
                  onPressed: _isLastPage
                      ? null
                      : () => _finish(OnboardingExit.skipped),
                  child: Text(
                    AppStrings.onboardingSkip,
                    style: TextStyle(
                      color: _isLastPage
                          ? Colors.transparent
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  // The slide has to survive a short screen (a phone in
                  // landscape) and a large text setting: the illustration
                  // gives way first, and whatever is still too tall
                  // scrolls rather than overflowing.
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final illustration = min(
                        120.0,
                        constraints.maxHeight * 0.3,
                      );
                      return SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xxl,
                              vertical: AppSpacing.md,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: illustration,
                                  height: illustration,
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary.withValues(
                                      alpha: 0.14,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    slide.icon,
                                    size: illustration * 0.47,
                                    color: colorScheme.primary,
                                  ),
                                ),
                                SizedBox(height: illustration * 0.2),
                                Text(
                                  slide.title,
                                  textAlign: TextAlign.center,
                                  style: textTheme.headlineMedium,
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Text(
                                  slide.description,
                                  textAlign: TextAlign.center,
                                  style: textTheme.bodyLarge?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _slides.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                    ),
                    width: i == _currentPage ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _currentPage
                          ? colorScheme.primary
                          : colorScheme.outline,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.md,
              ),
              child: ElevatedButton(
                onPressed: _next,
                child: Text(
                  _isLastPage
                      ? AppStrings.onboardingGetStarted
                      : AppStrings.onboardingNext,
                ),
              ),
            ),
            // The way in for someone who isn't ready to hand over their
            // location. Refusing the system dialog is a decision Android
            // remembers and the app can barely recover from; declining a
            // text button is one either of them can undo later.
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: SizedBox(
                height: _isLastPage ? null : 0,
                child: _isLastPage
                    ? TextButton(
                        onPressed: () => _finish(OnboardingExit.browseInstead),
                        child: const Text(AppStrings.onboardingBrowseInstead),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
