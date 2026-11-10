import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import { formatISODate, parseISODate } from "./calendar-date";
import { estimateClawback, scaleCents } from "./clawback";

interface Vector {
  name: string;
  start_date: string;
  window_months: number;
  relocation_costs_cents: number;
  cap_cents: number | null;
  departure: string;
  expected: {
    months_served: number;
    months_remaining: number;
    prorated_cents: number;
    owed_cents: number;
    cap_applied: boolean;
    window_end: string;
  };
}

const vectorsPath = fileURLToPath(
  new URL("../../../../../schemas/test-vectors/clawback.json", import.meta.url),
);
const { cases } = JSON.parse(readFileSync(vectorsPath, "utf8")) as { cases: Vector[] };

describe("clawback shared vectors", () => {
  it("loads the shared vectors", () => {
    expect(cases.length).toBeGreaterThanOrEqual(10);
  });

  it.each(cases.map((c) => [c.name, c] as const))("%s", (_name, v) => {
    const start = parseISODate(v.start_date);
    const departure = parseISODate(v.departure);
    expect(start).not.toBeNull();
    expect(departure).not.toBeNull();

    const result = estimateClawback(
      { windowMonths: v.window_months, startDate: start!, capCents: v.cap_cents },
      departure!,
      v.relocation_costs_cents,
    );

    expect({
      months_served: result.monthsServed,
      months_remaining: result.monthsRemaining,
      prorated_cents: result.proratedCents,
      owed_cents: result.owedCents,
      cap_applied: result.capApplied,
      window_end: formatISODate(result.windowEnd),
    }).toEqual(v.expected);
  });
});

describe("scaleCents", () => {
  it("rounds half up", () => {
    expect(scaleCents(1, 1, 2)).toBe(1);
    expect(scaleCents(1, 1, 3)).toBe(0);
    expect(scaleCents(850_000, 8, 12)).toBe(566_667);
  });
});

describe("parseISODate", () => {
  it.each(["2027-02-29", "2027-13-01", "2027-04-31", "nope"])("rejects %s", (text) => {
    expect(parseISODate(text)).toBeNull();
  });
});
