/// A single source of truth for deciding whether marketplace samples may be
/// rendered. Sample content is all-or-nothing and only appears after a
/// successful empty database result.
enum MarketplacePresentationState {
  loading,
  live,
  filteredEmpty,
  sample,
  error,
}

abstract final class MarketplaceContentResolver {
  static MarketplacePresentationState resolve({
    required bool isLoading,
    required bool hasError,
    required int rawOfferingCount,
    required int rawWantedCount,
    required int visibleCount,
  }) {
    if (isLoading) return MarketplacePresentationState.loading;
    if (hasError) return MarketplacePresentationState.error;

    final hasRealListings = rawOfferingCount > 0 || rawWantedCount > 0;
    if (!hasRealListings) return MarketplacePresentationState.sample;
    if (visibleCount == 0) return MarketplacePresentationState.filteredEmpty;
    return MarketplacePresentationState.live;
  }
}
