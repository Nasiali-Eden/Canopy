/** Versioned, evidence-based participation scoring. Client estimates never award points. */
export const SCORING_VERSION = 1;

export function calculatePoints(data: Record<string, unknown>): number {
  if (data.type === "Time") {
    const hours = data.hours;
    if (typeof hours !== "number" || !Number.isFinite(hours) || hours <= 0 || hours > 24) {
      throw new Error("Time contributions require between 0 and 24 hours (exclusive of zero).");
    }
    return Math.max(1, Math.round(hours * 10));
  }
  if (data.type === "Effort") {
    if (typeof data.effort !== "string" || !data.effort.trim()) {
      throw new Error("Describe the work completed.");
    }
    return 20;
  }
  if (data.type === "Materials") {
    if (!Array.isArray(data.materials) || !data.materials.some(x => typeof x === "string" && x.trim())) {
      throw new Error("Provide the materials contributed.");
    }
    return 20;
  }
  throw new Error("Unsupported contribution type.");
}
