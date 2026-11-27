import Link from 'next/link';
import {
  ArrowDownLeft,
  ArrowUpRight,
  CalendarCheck,
  Receipt,
  Wallet,
  ChevronRight,
} from 'lucide-react';
import { requireActiveMember } from '@/lib/auth';
import { createClient } from '@/lib/supabase/server';
import {
  currentMonthPeriodWIB,
  formatDateID,
  formatMonthID,
  formatRupiah,
} from '@/lib/format';
import type { VBalance, VDuesBoard, VTransaction } from '@/types/database';

export const dynamic = 'force-dynamic';

export default async function DashboardPage() {
  const member = await requireActiveMember();
  const supabase = await createClient();
  const currentPeriod = currentMonthPeriodWIB();

  const [{ data: balance }, { data: monthDues }, { data: recentTransactions }] =
    await Promise.all([
      supabase.from('v_balance').select('*').maybeSingle<VBalance>(),
      supabase
        .from('v_dues_board')
        .select('*')
        .eq('period', currentPeriod)
        .returns<VDuesBoard[]>(),
      supabase
        .from('v_transactions')
        .select('*')
        .limit(5)
        .returns<VTransaction[]>(),
    ]);

  const duesList = monthDues ?? [];
  const totalDues = duesList.length;
  const paidCount = duesList.filter((d) => d.status === 'paid').length;
  const unpaidCount = duesList.filter((d) => d.status === 'unpaid').length;
  const overdueCount = duesList.filter((d) => d.is_overdue).length;
  const myDue = duesList.find((d) => d.member_id === member.id) ?? null;

  const trxList = recentTransactions ?? [];
  const currentMonthLabel = formatMonthID(currentPeriod);

  return (
    <div className="space-y-6">
      {/* Header sapaan */}
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div>
          <h1 className="text-xl font-bold tracking-tight text-slate-900 sm:text-2xl">
            Halo, {member.full_name}
          </h1>
          <p className="text-sm text-slate-500">
            Ringkasan transparansi kas tim periode {currentMonthLabel}
          </p>
        </div>
        <span className="inline-flex items-center rounded-full border border-slate-200 bg-white px-3 py-1 text-xs font-medium text-slate-600">
          Zona Waktu WIB
        </span>
      </div>

      {/* Hero Saldo Saat Ini */}
      <section className="rounded-2xl bg-gradient-to-br from-emerald-700 to-emerald-600 p-5 text-white shadow-sm sm:p-6">
        <div className="flex items-start justify-between gap-4">
          <div>
            <p className="text-xs font-medium uppercase tracking-wider text-emerald-100">
              Saldo Kas Saat Ini
            </p>
            <p className="mt-2 text-3xl font-bold tracking-tight sm:text-4xl">
              {formatRupiah(balance?.balance ?? 0)}
            </p>
          </div>
          <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-white/15">
            <Wallet className="h-5 w-5" />
          </div>
        </div>
        {Number(balance?.opening_balance ?? 0) > 0 && (
          <p className="mt-3 text-xs text-emerald-100">
            Termasuk saldo awal tercatat sebesar{' '}
            <span className="font-semibold text-white">
              {formatRupiah(balance?.opening_balance)}
            </span>
          </p>
        )}
      </section>

      {/* Ringkasan Bulan Berjalan vs Sepanjang Masa */}
      <section className="grid gap-4 sm:grid-cols-2">
        <div className="rounded-2xl border border-slate-200 bg-white p-5 shadow-xs">
          <div className="mb-4 flex items-center justify-between">
            <h2 className="text-sm font-semibold text-slate-900">
              Bulan Berjalan
            </h2>
            <span className="rounded-full bg-slate-100 px-2.5 py-0.5 text-xs font-medium text-slate-600">
              {currentMonthLabel}
            </span>
          </div>
          <div className="space-y-3 text-sm">
            <div className="flex items-center justify-between">
              <span className="flex items-center gap-2 text-slate-600">
                <ArrowDownLeft className="h-4 w-4 text-emerald-600" />
                Pemasukan
              </span>
              <span className="font-semibold text-emerald-700">
                {formatRupiah(balance?.month_income ?? 0)}
              </span>
            </div>
            <div className="flex items-center justify-between">
              <span className="flex items-center gap-2 text-slate-600">
                <ArrowUpRight className="h-4 w-4 text-rose-600" />
                Pengeluaran
              </span>
              <span className="font-semibold text-rose-700">
                {formatRupiah(balance?.month_expense ?? 0)}
              </span>
            </div>
            <div className="flex items-center justify-between border-t border-slate-100 pt-2.5">
              <span className="font-medium text-slate-700">Selisih Bulan Ini</span>
              <span className="font-bold text-slate-900">
                {formatRupiah(balance?.month_net ?? 0)}
              </span>
            </div>
          </div>
        </div>

        <div className="rounded-2xl border border-slate-200 bg-white p-5 shadow-xs">
          <div className="mb-4 flex items-center justify-between">
            <h2 className="text-sm font-semibold text-slate-900">
              Sepanjang Masa
            </h2>
            <span className="rounded-full bg-slate-100 px-2.5 py-0.5 text-xs font-medium text-slate-600">
              Total Akumulasi
            </span>
          </div>
          <div className="space-y-3 text-sm">
            <div className="flex items-center justify-between">
              <span className="flex items-center gap-2 text-slate-600">
                <ArrowDownLeft className="h-4 w-4 text-emerald-600" />
                Total Pemasukan
              </span>
              <span className="font-semibold text-emerald-700">
                {formatRupiah(balance?.total_income ?? 0)}
              </span>
            </div>
            <div className="flex items-center justify-between">
              <span className="flex items-center gap-2 text-slate-600">
                <ArrowUpRight className="h-4 w-4 text-rose-600" />
                Total Pengeluaran
              </span>
              <span className="font-semibold text-rose-700">
                {formatRupiah(balance?.total_expense ?? 0)}
              </span>
            </div>
            <div className="flex items-center justify-between border-t border-slate-100 pt-2.5">
              <span className="font-medium text-slate-700">Saldo Akhir</span>
              <span className="font-bold text-slate-900">
                {formatRupiah(balance?.balance ?? 0)}
              </span>
            </div>
          </div>
        </div>
      </section>

      {/* Status Iuran Bulan Berjalan */}
      <section className="rounded-2xl border border-slate-200 bg-white p-5 shadow-xs">
        <div className="mb-4 flex items-center justify-between gap-2">
          <div className="flex items-center gap-2">
            <CalendarCheck className="h-4 w-4 text-emerald-600" />
            <h2 className="text-sm font-semibold text-slate-900">
              Status Iuran {currentMonthLabel}
            </h2>
          </div>
          <Link
            href="/iuran"
            className="inline-flex items-center gap-1 text-xs font-semibold text-emerald-700 hover:text-emerald-800"
          >
            <span>Lihat papan</span>
            <ChevronRight className="h-3.5 w-3.5" />
          </Link>
        </div>

        {totalDues === 0 ? (
          <p className="rounded-xl bg-slate-50 px-4 py-3 text-sm text-slate-600">
            Tagihan iuran untuk bulan {currentMonthLabel} belum dibuat oleh pengelola.
          </p>
        ) : (
          <div className="space-y-3">
            <div className="grid grid-cols-3 gap-2.5 text-center sm:gap-3">
              <div className="rounded-xl bg-emerald-50 px-3 py-2.5">
                <p className="text-lg font-bold text-emerald-700">{paidCount}</p>
                <p className="text-[11px] font-medium text-emerald-800">Lunas</p>
              </div>
              <div className="rounded-xl bg-amber-50 px-3 py-2.5">
                <p className="text-lg font-bold text-amber-700">{unpaidCount}</p>
                <p className="text-[11px] font-medium text-amber-800">Belum Lunas</p>
              </div>
              <div className="rounded-xl bg-rose-50 px-3 py-2.5">
                <p className="text-lg font-bold text-rose-700">{overdueCount}</p>
                <p className="text-[11px] font-medium text-rose-800">Terlambat</p>
              </div>
            </div>

            {myDue && (
              <div className="flex flex-wrap items-center justify-between gap-2 rounded-xl border border-slate-100 bg-slate-50 px-3.5 py-2.5 text-xs">
                <span className="text-slate-600">
                  Iuran Anda bulan ini ({formatRupiah(myDue.amount)}):
                </span>
                {myDue.status === 'paid' ? (
                  <span className="rounded-full bg-emerald-100 px-2.5 py-0.5 font-semibold text-emerald-800">
                    Lunas {myDue.paid_at ? `(${formatDateID(myDue.paid_at)})` : ''}
                  </span>
                ) : myDue.is_overdue ? (
                  <span className="rounded-full bg-rose-100 px-2.5 py-0.5 font-semibold text-rose-800">
                    Terlambat
                  </span>
                ) : (
                  <span className="rounded-full bg-amber-100 px-2.5 py-0.5 font-semibold text-amber-800">
                    Belum Lunas
                  </span>
                )}
              </div>
            )}
          </div>
        )}
      </section>

      {/* Transaksi Terbaru */}
      <section className="rounded-2xl border border-slate-200 bg-white p-5 shadow-xs">
        <div className="mb-4 flex items-center justify-between gap-2">
          <div className="flex items-center gap-2">
            <Receipt className="h-4 w-4 text-emerald-600" />
            <h2 className="text-sm font-semibold text-slate-900">
              Transaksi Terbaru
            </h2>
          </div>
          <Link
            href="/transaksi"
            className="inline-flex items-center gap-1 text-xs font-semibold text-emerald-700 hover:text-emerald-800"
          >
            <span>Semua transaksi</span>
            <ChevronRight className="h-3.5 w-3.5" />
          </Link>
        </div>

        {trxList.length === 0 ? (
          <p className="rounded-xl bg-slate-50 px-4 py-4 text-center text-sm text-slate-600">
            Belum ada transaksi tercatat. Kas dimulai fresh dari Rp 0.
          </p>
        ) : (
          <ul className="divide-y divide-slate-100">
            {trxList.map((trx) => {
              const isIncome = trx.type === 'income';
              return (
                <li
                  key={trx.id}
                  className="flex items-center justify-between gap-3 py-3 first:pt-0 last:pb-0"
                >
                  <div className="min-w-0">
                    <p className="truncate text-sm font-medium text-slate-900">
                      {trx.purpose}
                    </p>
                    <p className="mt-0.5 truncate text-xs text-slate-500">
                      {trx.counterparty} · {trx.category} ·{' '}
                      {formatDateID(trx.trx_date)}
                    </p>
                  </div>
                  <span
                    className={`shrink-0 text-sm font-semibold ${
                      isIncome ? 'text-emerald-700' : 'text-rose-700'
                    }`}
                  >
                    {isIncome ? '+' : '-'}
                    {formatRupiah(trx.amount)}
                  </span>
                </li>
              );
            })}
          </ul>
        )}
      </section>
    </div>
  );
}
