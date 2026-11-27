const WIB_TIMEZONE = 'Asia/Jakarta';

const rupiahFormatter = new Intl.NumberFormat('id-ID', {
  maximumFractionDigits: 0,
});

const dateIDFormatter = new Intl.DateTimeFormat('id-ID', {
  day: 'numeric',
  month: 'short',
  year: 'numeric',
  timeZone: WIB_TIMEZONE,
});

const monthIDFormatter = new Intl.DateTimeFormat('id-ID', {
  month: 'long',
  year: 'numeric',
  timeZone: WIB_TIMEZONE,
});

const wibDateFormatter = new Intl.DateTimeFormat('en-CA', {
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
  timeZone: WIB_TIMEZONE,
});

export function formatRupiah(value: number | string | null | undefined): string {
  if (value === null || value === undefined || value === '') {
    return 'Rp 0';
  }
  const num = typeof value === 'string' ? Number(value) : value;
  if (!Number.isFinite(num)) {
    return 'Rp 0';
  }
  const rounded = Math.round(num);
  if (rounded < 0) {
    return `-Rp ${rupiahFormatter.format(Math.abs(rounded))}`;
  }
  return `Rp ${rupiahFormatter.format(rounded)}`;
}

export function todayWIB(): string {
  return wibDateFormatter.format(new Date());
}

export function currentMonthPeriodWIB(): string {
  return `${todayWIB().slice(0, 7)}-01`;
}

export function formatDateID(dateStr: string): string {
  if (!dateStr) return '-';
  const normalized = dateStr.length === 10 ? `${dateStr}T00:00:00+07:00` : dateStr;
  const parsed = new Date(normalized);
  if (Number.isNaN(parsed.getTime())) return dateStr;
  return dateIDFormatter.format(parsed);
}

export function formatMonthID(periodStr: string): string {
  if (!periodStr) return '-';
  const normalized = periodStr.length === 10 ? `${periodStr}T00:00:00+07:00` : periodStr;
  const parsed = new Date(normalized);
  if (Number.isNaN(parsed.getTime())) return periodStr;
  return monthIDFormatter.format(parsed);
}
