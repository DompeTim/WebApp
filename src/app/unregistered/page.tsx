import { redirect } from 'next/navigation';
import { ShieldAlert } from 'lucide-react';
import { getCurrentMembership } from '@/lib/auth';
import { SignOutButton } from '@/components/SignOutButton';

export const dynamic = 'force-dynamic';

export default async function UnregisteredPage() {
  const membership = await getCurrentMembership();

  if (
    membership.status === 'unconfigured' ||
    membership.status === 'unauthenticated'
  ) {
    redirect('/login');
  }
  if (membership.status === 'active') {
    redirect('/');
  }
  if (membership.status === 'inactive') {
    redirect('/inactive');
  }

  return (
    <main className="flex min-h-screen items-center justify-center bg-slate-50 px-4 py-10">
      <div className="w-full max-w-md rounded-2xl border border-slate-200 bg-white p-6 text-center shadow-sm sm:p-8">
        <div className="mx-auto mb-4 flex h-12 w-12 items-center justify-center rounded-2xl bg-amber-100 text-amber-700">
          <ShieldAlert className="h-6 w-6" />
        </div>
        <h1 className="text-xl font-bold text-slate-900">
          Akun Belum Terdaftar
        </h1>
        <p className="mt-2 text-sm leading-relaxed text-slate-600">
          Email{' '}
          <span className="font-semibold text-slate-900">
            {membership.email}
          </span>{' '}
          belum terdaftar di daftar anggota Dompetim.
        </p>
        <p className="mt-2 rounded-xl bg-slate-50 p-3 text-xs leading-relaxed text-slate-600">
          Silakan hubungi pengelola kas tim untuk mendaftarkan email Google Anda
          agar dapat melihat data kas dan status iuran.
        </p>
        <div className="mt-6">
          <SignOutButton />
        </div>
      </div>
    </main>
  );
}
