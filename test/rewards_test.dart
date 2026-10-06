import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kaamwala_thekedar/core/i18n/app_strings.dart';
import 'package:kaamwala_thekedar/data/models/reward_models.dart';
import 'package:kaamwala_thekedar/data/repositories/mock_repository.dart';
import 'package:kaamwala_thekedar/features/account/account_screen.dart';
import 'package:kaamwala_thekedar/features/rewards/rewards_screen.dart';
import 'package:kaamwala_thekedar/widgets/kw_celebration.dart';

import 'widget_test.dart' show host;

/// What `GET /rewards` sends a Thekedar for the Share & Earn campaign: four
/// milestone ticks and a physical reward at the top. Numbers arrive as strings
/// here on purpose — MySQL/PHP does that often enough that the parser must not
/// care.
Map<String, dynamic> _sharingJson({Object current = '7'}) => {
  'id': 2,
  'name': 'Share & Earn',
  'type': 'sharing',
  'title': 'Share & Earn Rewards',
  'subtitle': 'Invite your friends and earn amazing gifts',
  'description': null,
  'banner_image_url': null,
  'button_text': 'Share App Now',
  'current': current,
  'target': '50',
  'next_target': 10,
  'progress_percentage': 14,
  'levels': [
    for (final t in [1, 5, 10, 20])
      {
        'id': t,
        'target': t,
        'reward_type': 'milestone',
        'completed': (int.parse('$current')) >= t,
        'status': int.parse('$current') >= t ? 'completed' : 'locked',
        'can_claim': false,
      },
    {
      'id': 10,
      'target': 50,
      'reward_type': 'physical',
      'reward_name': 'Free Toolbox',
      'completed': false,
      'status': 'locked',
      'can_claim': false,
    },
  ],
  'steps': [
    {'title': 'Share App', 'description': 'Share it', 'icon': 'share'},
  ],
  'tips': ['Share on WhatsApp', '  '],
  'referral': {'code': 'KWFGM346', 'link': 'https://x.test/?ref=KWFGM346'},
};

/// A repository whose only campaign is Successful Match — so there is nothing
/// to share and the bottom button has to be about finding labour.
class _MatchOnly extends MockRepository {
  _MatchOnly() : super(latency: Duration.zero);

  @override
  Future<RewardsData> rewards() async {
    final all = await super.rewards();
    return RewardsData(
      campaigns: all.campaigns.where((c) => !c.isSharing).toList(),
      walletBalance: 0,
    );
  }
}

/// Always has nothing running, as a role with no campaign configured would.
class _NoCampaigns extends MockRepository {
  _NoCampaigns() : super(latency: Duration.zero);

  @override
  Future<RewardsData> rewards() async => RewardsData.empty;
}

class _Offline extends MockRepository {
  _Offline() : super(latency: Duration.zero);

  @override
  Future<RewardsData> rewards() => Future.error(Exception('no network'));
}

MockRepository _repo() => MockRepository(latency: Duration.zero);

/// The test surface is 800x600 whatever the host's MediaQuery says, and the
/// delivery form is taller than that. On a phone the sheet scrolls; here it is
/// simpler to give it room.
void _tallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Rewards payload', () {
    test('reads the campaign the way the server sends it', () {
      final campaign = RewardCampaign.fromJson(_sharingJson());

      expect(campaign.isSharing, isTrue);
      expect(campaign.current, 7);
      expect(campaign.target, 50);
      expect(campaign.nextTarget, 10);
      expect(campaign.remainingToNext, 3);
      expect(campaign.referral?.code, 'KWFGM346');
      expect(campaign.levels.map((l) => l.target), [1, 5, 10, 20, 50]);
      // A blank tip is noise, not a bullet.
      expect(campaign.tips, ['Share on WhatsApp']);
    });

    test('a finished campaign has nothing left to chase', () {
      final json = _sharingJson(current: 50)..['next_target'] = null;
      final campaign = RewardCampaign.fromJson(json);

      expect(campaign.nextTarget, isNull);
      expect(campaign.remainingToNext, 0);
    });

    test('a level phase follows the status, and the count when it is new', () {
      RewardLevel level(String status, {bool canClaim = false, bool done = false}) =>
          RewardLevel.fromJson({
            'id': 1,
            'target': 5,
            'reward_type': 'physical',
            'status': status,
            'can_claim': canClaim,
            'completed': done,
          });

      expect(level('locked').phase, LevelPhase.locked);
      expect(level('completed', done: true).phase, LevelPhase.reached);
      expect(level('unlocked', canClaim: true).phase, LevelPhase.claimable);
      expect(level('unlocked').phase, LevelPhase.reached);
      expect(level('claimed').phase, LevelPhase.inReview);
      expect(level('approved').phase, LevelPhase.inReview);
      expect(level('processing').phase, LevelPhase.inReview);
      expect(level('delivered').phase, LevelPhase.delivered);
      expect(level('rejected').phase, LevelPhase.rejected);
      // A status a newer server invents: trust the count, not the string.
      expect(level('teleported', done: true).phase, LevelPhase.reached);
      expect(level('teleported').phase, LevelPhase.locked);
    });

    test('a claim goes out under the API field names', () {
      const details = ClaimDetails(
        name: 'Ramesh',
        phone: '9000000001',
        address: '12 MG Road',
        city: 'Gurgaon',
        state: 'Haryana',
        pincode: '122001',
      );

      expect(details.toJson(), {
        'claim_name': 'Ramesh',
        'claim_phone': '9000000001',
        'delivery_address': '12 MG Road',
        'city': 'Gurgaon',
        'state': 'Haryana',
        'pincode': '122001',
      });
    });
  });

  group('Rewards strings', () {
    test('every language answers every rewards line', () {
      for (final s in [
        AppStrings.hinglish,
        AppStrings.hindi,
        AppStrings.english,
        AppStrings.bhojpuri,
      ]) {
        final lines = [
          s.rewardsTitle,
          s.rewardsMenuSub,
          s.rewardsLoadFail,
          s.rewardsEmpty,
          s.rewardsHeroTop,
          s.rewardsHeroAccent,
          s.rewardsHeroSub,
          s.rewardsTagline,
          s.rewardsCampaignN(2),
          s.rewardsRibbonSharing,
          s.rewardsRibbonMatch,
          s.rewardsGet('Tool Kit'),
          s.rewardsAtLevel(20, s.rewardsUnitMatch),
          s.rewardsToNext(3),
          s.rewardsWalletCredit(500),
          s.rewardsStatusProcessing,
          s.rewardsClaim,
          s.rewardsShareBtn,
          s.rewardsFindLabourBtn,
          s.claimTitle,
          s.claimSubtitle('Tool Kit'),
          s.claimSubmit,
          s.claimDoneMsg,
        ];
        expect(lines.where((l) => l.trim().isEmpty), isEmpty);
      }
    });

    test('the share message carries the code and the link', () {
      for (final s in [
        AppStrings.hinglish,
        AppStrings.hindi,
        AppStrings.english,
        AppStrings.bhojpuri,
      ]) {
        final text = s.rewardsShareText('KWFGM346', 'https://x.test/?ref=A');
        expect(text, contains('KWFGM346'));
        expect(text, contains('https://x.test/?ref=A'));
        expect(text, contains('KaamJi'));
      }
    });
  });

  group('Rewards screen', () {
    testWidgets('lays out both campaigns with their numbers', (tester) async {
      await tester.pumpWidget(host(const RewardsScreen(), repository: _repo()));
      await tester.pumpAndSettle();

      expect(find.text('Share & Earn Rewards'), findsOneWidget);
      expect(find.text('Campaign 1'), findsOneWidget);
      expect(
        find.textContaining('/ 50 Shares', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('KWAMIT25'), findsOneWidget);

      await _scrollTo(tester, find.text('Successful Match Rewards'));
      expect(find.text('Campaign 2'), findsOneWidget);
      expect(
        find.textContaining('/ 50 Matches', findRichText: true),
        findsOneWidget,
      );
      // Every level is done on this campaign.
      expect(find.text('Aapne saare level poore kar liye 🎉'), findsOneWidget);
    });

    testWidgets('pins Share and Copy Link when there is a referral', (
      tester,
    ) async {
      await tester.pumpWidget(host(const RewardsScreen(), repository: _repo()));
      await tester.pumpAndSettle();

      expect(find.text('Share App Now'), findsOneWidget);
      expect(find.text('Link Copy'), findsOneWidget);
    });

    testWidgets('with nothing to share, the button goes to find labour', (
      tester,
    ) async {
      var went = 0;
      await tester.pumpWidget(
        host(
          RewardsScreen(onFindLabour: () => went++),
          repository: _MatchOnly(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Share App Now'), findsNothing);
      await tester.tap(find.text('Labour Dhundho'));
      await tester.pumpAndSettle();

      expect(went, 1);
    });

    testWidgets('says so when no campaign is running', (tester) async {
      await tester.pumpWidget(
        host(const RewardsScreen(), repository: _NoCampaigns()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Abhi koi reward nahi chal raha'), findsOneWidget);
      expect(find.text('Share App Now'), findsNothing);
    });

    testWidgets('offers a retry when the rewards cannot be loaded', (
      tester,
    ) async {
      await tester.pumpWidget(host(const RewardsScreen(), repository: _Offline()));
      await tester.pumpAndSettle();

      expect(find.text('Rewards load nahi hue'), findsOneWidget);
      expect(find.text('Dobara try karein'), findsOneWidget);
    });

    testWidgets('fits a wide window and a small phone', (tester) async {
      for (final size in const [Size(1280, 800), Size(320, 640)]) {
        await tester.pumpWidget(
          host(const RewardsScreen(), size: size, repository: _repo()),
        );
        await tester.pumpAndSettle();

        expect(find.text('Share & Earn Rewards'), findsOneWidget);
        // A layout overflow would already have failed the test.
      }
    });

    testWidgets('claims a physical reward end to end', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(host(const RewardsScreen(), repository: _repo()));
      await tester.pumpAndSettle();

      await _scrollTo(tester, find.text('Reward Claim Karein'));
      expect(find.text('Processing'), findsNothing);

      await tester.tap(find.text('Reward Claim Karein'));
      await tester.pumpAndSettle();

      // The delivery form, asking for what the account does not already have.
      expect(find.text('Delivery ki details'), findsOneWidget);
      expect(find.text('Tool Kit kahan bhejein?'), findsOneWidget);

      // Nothing filled in: every field complains and nothing is sent.
      await tester.tap(find.text('Claim bhejein'));
      await tester.pumpAndSettle();
      expect(find.text('Zaroori hai'), findsWidgets);
      expect(find.text('Claim bhej diya'), findsNothing);

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Ramesh Yadav');
      await tester.enterText(fields.at(1), '9000000001');
      await tester.enterText(fields.at(2), '12 MG Road, Sector 14');
      await tester.enterText(fields.at(3), 'Gurgaon');
      await tester.enterText(fields.at(4), 'Haryana');
      await tester.enterText(fields.at(5), '12200');

      // A five-digit pincode is not one.
      await tester.tap(find.text('Claim bhejein'));
      await tester.pumpAndSettle();
      expect(find.text('6 digit ka pincode daalein'), findsOneWidget);

      await tester.enterText(fields.at(5), '122001');
      await tester.tap(find.text('Claim bhejein'));
      await tester.pumpAndSettle();

      // The server took it: celebrate, then the level reads Processing.
      expect(find.byType(KwCelebration), findsOneWidget);
      expect(find.text('Claim bhej diya'), findsOneWidget);

      await tester.tap(find.text('Theek hai'));
      await tester.pumpAndSettle();

      expect(find.byType(KwCelebration), findsNothing);
      expect(find.text('Processing'), findsOneWidget);
      expect(find.text('Reward Claim Karein'), findsNothing);
    });

    testWidgets('a reward already on its way cannot be claimed twice', (
      tester,
    ) async {
      _tallSurface(tester);
      final repo = _repo();
      await tester.pumpWidget(host(const RewardsScreen(), repository: repo));
      await tester.pumpAndSettle();

      await _scrollTo(tester, find.text('Reward Claim Karein'));
      await tester.tap(find.text('Reward Claim Karein'));
      await tester.pumpAndSettle();

      // Claimed from another device while this sheet sat open.
      await repo.claimReward(
        701,
        const ClaimDetails(
          name: 'A',
          phone: '9000000001',
          address: 'B',
          city: 'C',
          state: 'D',
          pincode: '122001',
        ),
      );

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Ramesh Yadav');
      await tester.enterText(fields.at(1), '9000000001');
      await tester.enterText(fields.at(2), '12 MG Road');
      await tester.enterText(fields.at(3), 'Gurgaon');
      await tester.enterText(fields.at(4), 'Haryana');
      await tester.enterText(fields.at(5), '122001');
      await tester.tap(find.text('Claim bhejein'));
      await tester.pumpAndSettle();

      // The server's own wording, kept on the sheet beside the form.
      expect(
        find.text('Ye reward pehle se claim ho chuka hai.'),
        findsOneWidget,
      );
      expect(find.byType(KwCelebration), findsNothing);
    });
  });

  group('Rewards entry points', () {
    testWidgets('Refer & Earn in Account opens the Rewards screen', (
      tester,
    ) async {
      await tester.pumpWidget(host(const AccountScreen(), repository: _repo()));
      await tester.pumpAndSettle();

      await _scrollTo(tester, find.text('Refer & Earn'));
      await tester.tap(find.text('Refer & Earn'));
      await tester.pumpAndSettle();

      expect(find.byType(RewardsScreen), findsOneWidget);
      expect(find.text('Share & Earn Rewards'), findsOneWidget);
    });
  });
}
