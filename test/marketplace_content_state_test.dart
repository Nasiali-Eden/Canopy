import 'package:flutter_test/flutter_test.dart';
import 'package:impact_trail/Models/marketplace/marketplace_content_state.dart';

void main() {
  group('MarketplaceContentResolver', () {
    test('does not reveal samples while loading', () {
      expect(
        MarketplaceContentResolver.resolve(
          isLoading: true,
          hasError: false,
          rawOfferingCount: 0,
          rawWantedCount: 0,
          visibleCount: 0,
        ),
        MarketplacePresentationState.loading,
      );
    });

    test('shows all-sample mode only after a successful empty result', () {
      expect(
        MarketplaceContentResolver.resolve(
          isLoading: false,
          hasError: false,
          rawOfferingCount: 0,
          rawWantedCount: 0,
          visibleCount: 0,
        ),
        MarketplacePresentationState.sample,
      );
    });

    test('does not replace filtered-out database records with samples', () {
      expect(
        MarketplaceContentResolver.resolve(
          isLoading: false,
          hasError: false,
          rawOfferingCount: 3,
          rawWantedCount: 1,
          visibleCount: 0,
        ),
        MarketplacePresentationState.filteredEmpty,
      );
    });

    test('renders live mode when at least one real record is visible', () {
      expect(
        MarketplaceContentResolver.resolve(
          isLoading: false,
          hasError: false,
          rawOfferingCount: 2,
          rawWantedCount: 0,
          visibleCount: 1,
        ),
        MarketplacePresentationState.live,
      );
    });

    test('never turns an error into sample content', () {
      expect(
        MarketplaceContentResolver.resolve(
          isLoading: false,
          hasError: true,
          rawOfferingCount: 0,
          rawWantedCount: 0,
          visibleCount: 0,
        ),
        MarketplacePresentationState.error,
      );
    });
  });
}
