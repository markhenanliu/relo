/**
 * Calendar dates with no time zone, mirroring RelocDomain.CalendarDate on iOS.
 * Contract dates are calendar days, so we never route them through `Date`.
 */
export interface CalendarDate {
  year: number;
  month: number; // 1–12
  day: number;
}

function isLeap(year: number): boolean {
  return (year % 4 === 0 && year % 100 !== 0) || year % 400 === 0;
}

export function daysIn(year: number, month: number): number {
  if (month === 2) return isLeap(year) ? 29 : 28;
  return [4, 6, 9, 11].includes(month) ? 30 : 31;
}

export function parseISODate(text: string): CalendarDate | null {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(text);
  if (!match) return null;
  const [year, month, day] = match.slice(1).map(Number);
  if (month < 1 || month > 12 || day < 1 || day > daysIn(year, month)) return null;
  return { year, month, day };
}

export function formatISODate(d: CalendarDate): string {
  return `${String(d.year).padStart(4, "0")}-${String(d.month).padStart(2, "0")}-${String(d.day).padStart(2, "0")}`;
}

export function compareDates(a: CalendarDate, b: CalendarDate): number {
  return a.year - b.year || a.month - b.month || a.day - b.day;
}

/** Adds whole months, clamping the day to the target month's length. */
export function addMonths(d: CalendarDate, months: number): CalendarDate {
  const zeroBased = d.year * 12 + (d.month - 1) + months;
  const year = Math.floor(zeroBased / 12);
  const month = (zeroBased % 12) + 1;
  return { year, month, day: Math.min(d.day, daysIn(year, month)) };
}

/** Complete months from `from` to `to`; 0 if `to` is not after `from`. */
export function completeMonths(from: CalendarDate, to: CalendarDate): number {
  if (compareDates(to, from) <= 0) return 0;
  let months = (to.year - from.year) * 12 + (to.month - from.month);
  if (compareDates(addMonths(from, months), to) > 0) months -= 1;
  return Math.max(0, months);
}
