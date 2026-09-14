import '../../Models/badge.dart';

class RecognitionService {
  List<Badge> computeBadges(
      {required int impactPoints, required int contributionsCount}) {
    final badges = <Badge>[];

    badges.add(
      Badge(
        id: 'welcome',
        title: 'Welcome',
        description: 'Joined the community and started your impact journey.',
        earned: true,
      ),
    );

    badges.add(
      Badge(
        id: 'first_contribution',
        title: 'First Contribution',
        description: 'Verified your first contribution.',
        earned: contributionsCount >= 1,
        requiredContributions: 1,
      ),
    );

    badges.add(
      Badge(
        id: 'contributor_5',
        title: 'Consistent Contributor',
        description: 'Completed 5 verified contributions.',
        earned: contributionsCount >= 5,
        requiredContributions: 5,
      ),
    );

    badges.add(
      Badge(
        id: 'impact_100',
        title: 'Impact 100',
        description: 'Reached 100 impact points.',
        earned: impactPoints >= 100,
        requiredPoints: 100,
      ),
    );

    badges.add(
      Badge(
        id: 'impact_500',
        title: 'Impact 500',
        description: 'Reached 500 impact points.',
        earned: impactPoints >= 500,
        requiredPoints: 500,
      ),
    );

    badges.add(
      Badge(
        id: 'impact_1000',
        title: 'Impact 1000',
        description: 'Reached 1,000 impact points.',
        earned: impactPoints >= 1000,
        requiredPoints: 1000,
      ),
    );

    return badges;
  }
}
