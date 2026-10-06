import 'package:flutter/foundation.dart';

import '../api/api_client.dart';

/// Wire models for `GET /rewards` and `POST /rewards/{id}/claim`
/// (`App\Http\Controllers\Api\V1\RewardController`).
///
/// The endpoints are shared with the Labour app; the server decides which
/// campaigns a user sees from the campaign's `user_type`, so a Thekedar gets
/// their own "Share & Earn" and "Successful Match" with their own targets and
/// rewards. Nothing about a campaign is hard-coded on this side.

/// Everything `GET /rewards` returns: one entry per campaign running for this
/// user, plus whatever has been credited to the reward wallet.
@immutable
class RewardsData {
  const RewardsData({required this.campaigns, required this.walletBalance});

  static const empty = RewardsData(campaigns: [], walletBalance: 0);

  final List<RewardCampaign> campaigns;
  final int walletBalance;

  factory RewardsData.fromJson(Map<String, dynamic> json) => RewardsData(
    campaigns: json.listOfMaps('campaigns').map(RewardCampaign.fromJson).toList(),
    walletBalance: json.intVal('wallet_balance'),
  );
}

@immutable
class RewardCampaign {
  const RewardCampaign({
    required this.id,
    required this.name,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.bannerUrl,
    required this.iconUrl,
    required this.buttonText,
    required this.current,
    required this.target,
    required this.nextTarget,
    required this.progressPercentage,
    required this.levels,
    required this.steps,
    required this.tips,
    required this.referral,
  });

  static const typeSharing = 'sharing';
  static const typeMatch = 'match';

  final int id;
  final String name;
  final String type;
  final String title;
  final String subtitle;
  final String description;
  final String bannerUrl;
  final String iconUrl;
  final String buttonText;

  /// Verified referrals / successful matches counted so far.
  final int current;

  /// The largest level's target — the far end of the progress bar.
  final int target;

  /// The next level still ahead of [current]; null once every level is done.
  final int? nextTarget;
  final int progressPercentage;
  final List<RewardLevel> levels;
  final List<RewardStep> steps;
  final List<String> tips;

  /// Only the sharing campaign carries a referral code + link.
  final ReferralInfo? referral;

  bool get isSharing => type == typeSharing;

  /// How many more it takes to reach [nextTarget]; 0 when there is nothing ahead.
  int get remainingToNext =>
      nextTarget == null ? 0 : (nextTarget! - current).clamp(0, nextTarget!);

  factory RewardCampaign.fromJson(Map<String, dynamic> json) {
    final referral = json.mapOrNull('referral');
    return RewardCampaign(
      id: json.intVal('id'),
      name: json.str('name'),
      type: json.str('type'),
      title: json.strOrNull('title') ?? json.str('name'),
      subtitle: json.str('subtitle'),
      description: json.str('description'),
      bannerUrl: json.str('banner_image_url'),
      iconUrl: json.str('icon_url'),
      buttonText: json.str('button_text'),
      current: json.intVal('current'),
      target: json.intVal('target'),
      nextTarget: json['next_target'] == null ? null : json.intVal('next_target'),
      progressPercentage: json.intVal('progress_percentage').clamp(0, 100),
      levels: json.listOfMaps('levels').map(RewardLevel.fromJson).toList(),
      steps: json.listOfMaps('steps').map(RewardStep.fromJson).toList(),
      tips: json['tips'] is List
          ? [
              for (final tip in json['tips'] as List)
                if ('$tip'.trim().isNotEmpty) '$tip'.trim(),
            ]
          : const [],
      referral: referral == null ? null : ReferralInfo.fromJson(referral),
    );
  }
}

/// How a level should look, boiled down from the server's `status`.
enum LevelPhase {
  /// Target not reached yet — 🔒.
  locked,

  /// Reached with nothing more to do — ✓ (a milestone badge, or a reward that
  /// needs no claim).
  reached,

  /// Physical reward unlocked, waiting for the delivery details — 🎁.
  claimable,

  /// Claimed; admin is approving / packing / shipping it.
  inReview,

  /// In the Thekedar's hands (or, for a wallet reward, in their wallet) — ✓.
  delivered,

  /// Admin turned the claim down; the reason travels in the history payload.
  rejected,
}

@immutable
class RewardLevel {
  const RewardLevel({
    required this.id,
    required this.target,
    required this.rewardType,
    required this.rewardName,
    required this.rewardDescription,
    required this.rewardValue,
    required this.imageUrl,
    required this.completed,
    required this.status,
    required this.userRewardId,
    required this.canClaim,
  });

  static const typeMilestone = 'milestone';
  static const typePhysical = 'physical';
  static const typeWallet = 'wallet';

  final int id;
  final int target;
  final String rewardType;
  final String rewardName;
  final String rewardDescription;
  final int rewardValue;
  final String imageUrl;
  final bool completed;
  final String status;
  final int? userRewardId;
  final bool canClaim;

  bool get isMilestone => rewardType == typeMilestone;
  bool get isWallet => rewardType == typeWallet;
  bool get isPhysical => rewardType == typePhysical;

  LevelPhase get phase => switch (status) {
    'unlocked' => canClaim ? LevelPhase.claimable : LevelPhase.reached,
    'claimed' || 'approved' || 'processing' => LevelPhase.inReview,
    'delivered' => LevelPhase.delivered,
    'rejected' => LevelPhase.rejected,
    'completed' => LevelPhase.reached,
    'locked' => LevelPhase.locked,
    // A status this build does not know: trust the count, not the string.
    _ => completed ? LevelPhase.reached : LevelPhase.locked,
  };

  factory RewardLevel.fromJson(Map<String, dynamic> json) => RewardLevel(
    id: json.intVal('id'),
    target: json.intVal('target'),
    rewardType: json.strOrNull('reward_type') ?? typeMilestone,
    rewardName: json.str('reward_name'),
    rewardDescription: json.str('reward_description'),
    rewardValue: json.intVal('reward_value'),
    imageUrl: json.str('image_url'),
    completed: json.flag('completed'),
    status: json.strOrNull('status') ?? 'locked',
    userRewardId: json['user_reward_id'] == null
        ? null
        : json.intVal('user_reward_id'),
    canClaim: json.flag('can_claim'),
  );
}

@immutable
class RewardStep {
  const RewardStep({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final String icon;

  factory RewardStep.fromJson(Map<String, dynamic> json) => RewardStep(
    title: json.str('title'),
    description: json.str('description'),
    icon: json.str('icon'),
  );
}

@immutable
class ReferralInfo {
  const ReferralInfo({required this.code, required this.link});

  final String code;
  final String link;

  factory ReferralInfo.fromJson(Map<String, dynamic> json) =>
      ReferralInfo(code: json.str('code'), link: json.str('link'));
}

/// One row of `GET /rewards/history` → `rewards`. The campaign payload leaves
/// out the admin's note and the courier tracking number; this carries them so a
/// rejected or shipped reward can say why / where.
@immutable
class UserReward {
  const UserReward({
    required this.id,
    required this.status,
    required this.trackingNumber,
    required this.adminNote,
  });

  final int id;
  final String status;
  final String trackingNumber;
  final String adminNote;

  factory UserReward.fromJson(Map<String, dynamic> json) => UserReward(
    id: json.intVal('id'),
    status: json.str('status'),
    trackingNumber: json.str('tracking_number'),
    adminNote: json.str('admin_note'),
  );
}

/// Where a physical reward is to be delivered — the body of
/// `POST /rewards/{id}/claim`. The field names are the API's.
@immutable
class ClaimDetails {
  const ClaimDetails({
    required this.name,
    required this.phone,
    required this.address,
    required this.city,
    required this.state,
    required this.pincode,
  });

  final String name;
  final String phone;
  final String address;
  final String city;
  final String state;
  final String pincode;

  Map<String, dynamic> toJson() => {
    'claim_name': name,
    'claim_phone': phone,
    'delivery_address': address,
    'city': city,
    'state': state,
    'pincode': pincode,
  };
}
