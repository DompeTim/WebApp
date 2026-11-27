'use client';

import { useState } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import {
  LayoutDashboard,
  ArrowLeftRight,
  CalendarCheck,
  BarChart3,
  History,
  Users,
  Settings,
  Menu,
  X,
  Wallet,
} from 'lucide-react';
import type { Member } from '@/types/database';
import { SignOutButton } from './SignOutButton';

interface AppShellProps {
  member: Member;
  orgName: string;
  children: React.ReactNode;
}

interface NavItem {
  href: string;
  label: string;
  shortLabel: string;
  icon: React.ComponentType<{ className?: string }>;
}

const PRIMARY_NAV: NavItem[] = [
  { href: '/', label: 'Dashboard', shortLabel: 'Beranda', icon: LayoutDashboard },
  { href: '/transaksi', label: 'Transaksi', shortLabel: 'Transaksi', icon: ArrowLeftRight },
  { href: '/iuran', label: 'Iuran', shortLabel: 'Iuran', icon: CalendarCheck },
  { href: '/laporan', label: 'Laporan', shortLabel: 'Laporan', icon: BarChart3 },
];

const SECONDARY_NAV: NavItem[] = [
  { href: '/log', label: 'Log Aktivitas', shortLabel: 'Log', icon: History },
  { href: '/anggota', label: 'Anggota', shortLabel: 'Anggota', icon: Users },
];

const ADMIN_NAV: NavItem[] = [
  { href: '/pengaturan', label: 'Pengaturan', shortLabel: 'Pengaturan', icon: Settings },
];

export function AppShell({ member, orgName, children }: AppShellProps) {
  const pathname = usePathname();
  const [drawerOpen, setDrawerOpen] = useState(false);

  const isAdmin = member.role === 'admin';
  const secondaryItems = isAdmin ? [...SECONDARY_NAV, ...ADMIN_NAV] : SECONDARY_NAV;
  const allItems = [...PRIMARY_NAV, ...secondaryItems];

  function isActiveRoute(href: string) {
    if (href === '/') return pathname === '/';
    return pathname === href || pathname.startsWith(`${href}/`);
  }

  return (
    <div className="min-h-screen bg-slate-50 md:flex">
      {/* Sidebar Desktop */}
      <aside className="no-print hidden md:fixed md:inset-y-0 md:flex md:w-64 md:flex-col md:border-r md:border-slate-200 md:bg-white">
        <div className="flex h-16 items-center gap-3 border-b border-slate-100 px-5">
          <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-emerald-600 text-white">
            <Wallet className="h-5 w-5" />
          </div>
          <div className="min-w-0">
            <p className="truncate text-sm font-bold text-slate-900">{orgName}</p>
            <p className="truncate text-xs text-slate-500">Kas tim transparan</p>
          </div>
        </div>

        <nav className="flex-1 space-y-1 overflow-y-auto px-3 py-4">
          {allItems.map((item) => {
            const Icon = item.icon;
            const active = isActiveRoute(item.href);
            return (
              <Link
                key={item.href}
                href={item.href}
                className={`flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-medium transition ${
                  active
                    ? 'bg-emerald-50 text-emerald-700'
                    : 'text-slate-600 hover:bg-slate-50 hover:text-slate-900'
                }`}
              >
                <Icon
                  className={`h-4 w-4 shrink-0 ${
                    active ? 'text-emerald-600' : 'text-slate-400'
                  }`}
                />
                <span>{item.label}</span>
              </Link>
            );
          })}
        </nav>

        <div className="border-t border-slate-100 p-4">
          <div className="mb-3 rounded-xl bg-slate-50 px-3 py-2.5">
            <p className="truncate text-sm font-semibold text-slate-900">
              {member.full_name}
            </p>
            <span
              className={`mt-1 inline-flex items-center rounded-full px-2 py-0.5 text-[11px] font-semibold ${
                isAdmin
                  ? 'bg-emerald-100 text-emerald-800'
                  : 'bg-slate-200 text-slate-700'
              }`}
            >
              {isAdmin ? 'Pengelola' : 'Anggota'}
            </span>
          </div>
          <SignOutButton variant="subtle" className="w-full justify-start" />
        </div>
      </aside>

      {/* Top Bar Mobile */}
      <header className="no-print sticky top-0 z-30 flex h-14 items-center justify-between border-b border-slate-200 bg-white/95 px-4 backdrop-blur md:hidden">
        <div className="flex min-w-0 items-center gap-2.5">
          <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-emerald-600 text-white">
            <Wallet className="h-4 w-4" />
          </div>
          <span className="truncate text-sm font-bold text-slate-900">
            {orgName}
          </span>
        </div>

        <div className="flex items-center gap-2">
          <span
            className={`rounded-full px-2.5 py-0.5 text-[11px] font-semibold ${
              isAdmin
                ? 'bg-emerald-100 text-emerald-800'
                : 'bg-slate-100 text-slate-700'
            }`}
          >
            {isAdmin ? 'Pengelola' : 'Anggota'}
          </span>
          <button
            type="button"
            onClick={() => setDrawerOpen((prev) => !prev)}
            aria-label={drawerOpen ? 'Tutup menu' : 'Buka menu'}
            className="inline-flex h-9 w-9 items-center justify-center rounded-lg border border-slate-200 text-slate-700 hover:bg-slate-50"
          >
            {drawerOpen ? <X className="h-5 w-5" /> : <Menu className="h-5 w-5" />}
          </button>
        </div>
      </header>

      {/* Mobile Slide-Over Drawer */}
      {drawerOpen && (
        <div className="no-print fixed inset-0 z-40 md:hidden">
          <div
            className="fixed inset-0 bg-slate-900/40"
            onClick={() => setDrawerOpen(false)}
          />
          <div className="fixed inset-y-0 right-0 flex w-72 max-w-[85vw] flex-col bg-white shadow-xl">
            <div className="flex h-14 items-center justify-between border-b border-slate-100 px-4">
              <span className="text-sm font-bold text-slate-900">Menu Lainnya</span>
              <button
                type="button"
                onClick={() => setDrawerOpen(false)}
                aria-label="Tutup menu"
                className="inline-flex h-8 w-8 items-center justify-center rounded-lg text-slate-500 hover:bg-slate-100"
              >
                <X className="h-5 w-5" />
              </button>
            </div>

            <div className="flex-1 space-y-1 overflow-y-auto px-3 py-4">
              {secondaryItems.map((item) => {
                const Icon = item.icon;
                const active = isActiveRoute(item.href);
                return (
                  <Link
                    key={item.href}
                    href={item.href}
                    onClick={() => setDrawerOpen(false)}
                    className={`flex items-center gap-3 rounded-xl px-3 py-3 text-sm font-medium transition ${
                      active
                        ? 'bg-emerald-50 text-emerald-700'
                        : 'text-slate-700 hover:bg-slate-50'
                    }`}
                  >
                    <Icon
                      className={`h-4 w-4 shrink-0 ${
                        active ? 'text-emerald-600' : 'text-slate-400'
                      }`}
                    />
                    <span>{item.label}</span>
                  </Link>
                );
              })}
            </div>

            <div className="border-t border-slate-100 p-4">
              <div className="mb-3 rounded-xl bg-slate-50 px-3 py-2.5">
                <p className="truncate text-sm font-semibold text-slate-900">
                  {member.full_name}
                </p>
                <p className="text-xs text-slate-500">
                  {isAdmin ? 'Pengelola (Admin)' : 'Anggota (View Only)'}
                </p>
              </div>
              <SignOutButton />
            </div>
          </div>
        </div>
      )}

      {/* Main Content */}
      <main className="flex-1 md:pl-64">
        <div className="mx-auto max-w-5xl px-4 py-5 pb-24 md:px-8 md:py-8 md:pb-10">
          {children}
        </div>
      </main>

      {/* Mobile Bottom Navigation */}
      <nav className="no-print fixed inset-x-0 bottom-0 z-30 grid grid-cols-4 border-t border-slate-200 bg-white/95 backdrop-blur md:hidden">
        {PRIMARY_NAV.map((item) => {
          const Icon = item.icon;
          const active = isActiveRoute(item.href);
          return (
            <Link
              key={item.href}
              href={item.href}
              className={`flex flex-col items-center justify-center gap-1 py-2.5 text-[11px] font-medium transition ${
                active ? 'text-emerald-700' : 'text-slate-500 hover:text-slate-800'
              }`}
            >
              <Icon
                className={`h-5 w-5 ${
                  active ? 'text-emerald-600' : 'text-slate-400'
                }`}
              />
              <span className="truncate">{item.shortLabel}</span>
            </Link>
          );
        })}
      </nav>
    </div>
  );
}
