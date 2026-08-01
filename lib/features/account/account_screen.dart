import 'package:flutter/material.dart';

import '../../core/animations/entrance.dart';
import '../../core/animations/pressable.dart';
import '../../core/async/loadable.dart';
import '../../core/responsive/responsive.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/models.dart';
import '../../data/session.dart';
import '../../widgets/kw_async.dart';
import '../../widgets/kw_common.dart';
import '../../widgets/kw_scaffold.dart';

/// Account settings, backed by `GET /v1/thekedar/account` and
/// `PUT /v1/thekedar/account/preferences`.
///
/// Toggles apply optimistically and roll back if the write fails — a settings
/// switch that lags behind a round trip feels broken.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late final Loadable<AccountSettings> _settings = Loadable(
    () => context.repo.account(),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _settings.load();
    });
  }

  @override
  void dispose() {
    _settings.dispose();
    super.dispose();
  }

  Future<void> _update({
    String? language,
    bool? notifyPush,
    bool? notifyWhatsapp,
    bool? notifySms,
  }) async {
    final previous = _settings.value;
    if (previous == null) return;

    // Optimistic: paint the new state, then reconcile with the server.
    _settings.setValue(
      previous.copyWith(
        language: language,
        notifyPush: notifyPush,
        notifyWhatsapp: notifyWhatsapp,
        notifySms: notifySms,
      ),
    );

    try {
      final saved = await context.repo.updatePreferences(
        language: language,
        notifyPush: notifyPush,
        notifyWhatsapp: notifyWhatsapp,
        notifySms: notifySms,
      );
      if (!mounted) return;
      _settings.setValue(saved);

      // Keep the cached user in step; the same columns live on `users`.
      final user = context.session.user;
      if (user != null) {
        context.session.updateUser(
          user.copyWith(
            language: saved.language,
            notifyPush: saved.notifyPush,
            notifyWhatsapp: saved.notifyWhatsapp,
            notifySms: saved.notifySms,
          ),
        );
      }
    } on Object catch (e) {
      if (!mounted) return;
      _settings.setValue(previous);
      _toast(describeError(e));
    }
  }

  Future<void> _pickLanguage(AccountSettings current) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.white,
      builder: (context) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.x4l, 0, Gap.x4l, Gap.md),
              child: Text('Bhasha chunein', style: AppType.h3),
            ),
            ...Stagger.wrap(
              step: const Duration(milliseconds: 40),
              offset: 10,
              children: [
                for (final language in AppLanguage.values)
                  KwMenuRow(
                    icon: Icons.translate_rounded,
                    label: language.label,
                    showChevron: false,
                    divider: language != AppLanguage.values.last,
                    trailing: language.wire == current.language
                        ? const Icon(
                            Icons.check_circle_rounded,
                            size: 20,
                            color: AppColors.yellowDark,
                          )
                        : null,
                    onTap: () => Navigator.of(context).pop(language.wire),
                  ),
              ],
            ),
            Gap.v20,
          ],
        ),
      ),
    );

    if (picked != null && picked != current.language && mounted) {
      await _update(language: picked);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Logout karein?', style: AppType.h4),
        content: Text(
          'Aapko dobara OTP se login karna padega.',
          style: AppType.bodyMuted,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Rehne dein',
              style: AppType.buttonSmall.copyWith(color: AppColors.muted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Logout',
              style: AppType.buttonSmall.copyWith(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Revokes the Sanctum token server-side, then clears local state.
    await context.session.signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(Routes.login, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return KwScaffold(
      body: Column(
        children: [
          KwHeader(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            child: SafeArea(
              bottom: false,
              child: FadeSlideIn(
                from: SlideFrom.left,
                offset: 14,
                child: Text('Account Settings', style: AppType.h2),
              ),
            ),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: _settings,
              builder: (context, _) {
                final settings = _settings.value;
                if (settings == null) {
                  return _settings.error != null
                      ? ApiErrorState(
                          error: _settings.error!,
                          onRetry: () => _settings.load(),
                        )
                      : const Center(
                          child: SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(strokeWidth: 2.6),
                          ),
                        );
                }
                return _content(settings);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(AccountSettings settings) {
    final referral = context.session.user?.referralCode;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        SliverContentWidth(
          sliver: SliverPadding(
            padding: EdgeInsets.fromLTRB(
              context.pagePadding,
              Gap.x3l,
              context.pagePadding,
              Gap.x7l,
            ),
            sliver: SliverList.list(
              children: Stagger.wrap(
                step: const Duration(milliseconds: 50),
                offset: 18,
                children: [
                  const KwSectionTitle('Preferences'),
                  KwMenuCard(
                    children: [
                      KwMenuRow(
                        icon: Icons.notifications_none_rounded,
                        label: 'Notifications',
                        showChevron: false,
                        trailing: KwToggle(
                          value: settings.notifyPush,
                          onChanged: (v) => _update(notifyPush: v),
                        ),
                      ),
                      KwMenuRow(
                        icon: Icons.chat_bubble_outline_rounded,
                        label: 'WhatsApp Alerts',
                        showChevron: false,
                        trailing: KwToggle(
                          value: settings.notifyWhatsapp,
                          onChanged: (v) => _update(notifyWhatsapp: v),
                        ),
                      ),
                      KwMenuRow(
                        icon: Icons.sms_outlined,
                        label: 'SMS Alerts',
                        showChevron: false,
                        trailing: KwToggle(
                          value: settings.notifySms,
                          onChanged: (v) => _update(notifySms: v),
                        ),
                      ),
                      KwMenuRow(
                        icon: Icons.language_rounded,
                        label: 'Language / Bhasha',
                        divider: false,
                        trailing: AnimatedSwitcher(
                          duration: Motion.fast,
                          child: Text(
                            settings.languageLabel,
                            key: ValueKey(settings.language),
                            style: AppType.caption.copyWith(fontSize: 13),
                          ),
                        ),
                        onTap: () => _pickLanguage(settings),
                      ),
                    ],
                  ),
                  const KwSectionTitle('Payment'),
                  KwMenuCard(
                    children: [
                      KwMenuRow(
                        icon: Icons.credit_card_rounded,
                        label: 'Payment Methods',
                        onTap: () => _toast('Payment methods jald aayenge'),
                      ),
                      KwMenuRow(
                        icon: Icons.receipt_long_outlined,
                        label: 'Payment History',
                        onTap: () => _toast('Payment history jald aayegi'),
                      ),
                      KwMenuRow(
                        icon: Icons.card_giftcard_rounded,
                        label: 'Refer & Earn',
                        divider: false,
                        trailing: const KwBadge(label: 'New'),
                        onTap: () => _toast(
                          referral == null
                              ? 'Referral code jald aayega'
                              : 'Referral code: $referral',
                        ),
                      ),
                    ],
                  ),
                  const KwSectionTitle('Privacy & Security'),
                  KwMenuCard(
                    children: [
                      KwMenuRow(
                        icon: Icons.lock_outline_rounded,
                        label: 'Privacy Settings',
                        onTap: () => _toast('Privacy settings jald aayengi'),
                      ),
                      KwMenuRow(
                        icon: Icons.shield_outlined,
                        label: 'Account Security',
                        divider: false,
                        onTap: () => _toast('Account security jald aayegi'),
                      ),
                    ],
                  ),
                  const KwSectionTitle('Help'),
                  KwMenuCard(
                    children: [
                      KwMenuRow(
                        icon: Icons.help_outline_rounded,
                        label: 'Help & Support',
                        onTap: () => _toast('Support: 1800-123-4567'),
                      ),
                      KwMenuRow(
                        icon: Icons.description_outlined,
                        label: 'Terms & Conditions',
                        onTap: () => _toast('Terms & Conditions'),
                      ),
                      KwMenuRow(
                        icon: Icons.info_outline_rounded,
                        label: 'App Version',
                        showChevron: false,
                        divider: false,
                        trailing: Text(
                          settings.appVersion,
                          style: AppType.caption.copyWith(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  _logoutCard(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _logoutCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: Radii.rMd,
        border: Border.all(
          color: AppColors.danger.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Pressable(
        onTap: _logout,
        scale: 0.99,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Gap.x3l,
            vertical: Gap.xxl,
          ),
          child: Row(
            children: [
              const Icon(
                Icons.logout_rounded,
                size: 20,
                color: AppColors.danger,
              ),
              Gap.hXl,
              Expanded(
                child: Text(
                  'Logout',
                  style: AppType.bodyStrong.copyWith(color: AppColors.danger),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.danger,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
