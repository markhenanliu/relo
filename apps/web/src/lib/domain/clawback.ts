import { addMonths, completeMonths, type CalendarDate } from "./calendar-date";

/**
 * Clawback estimate, mirroring RelocDomain.ClawbackRule on iOS (PRD CLAW-2).
 * Both implementations must pass schemas/test-vectors/clawback.json.
 * Amounts are integer cents.
 */
export interface ClawbackRule {
  windowMonths: number;
  startDate: CalendarDate;
  capCents: number | null;
}

export interface ClawbackEstimate {
  monthsServed: number;
  monthsRemaining: number;
  proratedCents: number;
  owedCents: number;
  capApplied: boolean;
  windowEnd: CalendarDate;
}

/** Multiplies by numerator/denominator, rounding half up to the nearest cent. */
export function scaleCents(cents: number, numerator: number, denominator: number): number {
  return Math.floor((cents * numerator * 2 + denominator) / (denominator * 2));
}

export function estimateClawback(
  rule: ClawbackRule,
  departure: CalendarDate,
  relocationCostsCents: number,
): ClawbackEstimate {
  const served = Math.min(completeMonths(rule.startDate, departure), rule.windowMonths);
  const remaining = rule.windowMonths - served;
  const prorated = scaleCents(relocationCostsCents, remaining, rule.windowMonths);
  const capApplied = rule.capCents !== null && rule.capCents < prorated;

  return {
    monthsServed: served,
    monthsRemaining: remaining,
    proratedCents: prorated,
    owedCents: capApplied ? (rule.capCents as number) : prorated,
    capApplied,
    windowEnd: addMonths(rule.startDate, rule.windowMonths),
  };
}
