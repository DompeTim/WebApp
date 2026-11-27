import { redirect } from 'next/navigation';
import { UserX } from 'lucide-react';
import { getCurrentMembership } from '@/lib/auth';
import { SignOutButton } from '@/components/SignOutButton';

export const dynamic = 'force-dynamic';

export default async function InactivePage() {
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
  if (membership.status === 'unregistered') {
    redirect('/unregistered');
  }

  return (
    <main className="flex min-h-screen items-center justify-center bg-slate-50 px-4 py-10">
      <div className="w-full max-w-md rounded-2xl border border-slate-200 bg-white p-6 text-center shadow-sm sm:p-8">
        <div className="mx-auto mb-4 flex h-12 w-12 items-center justify-center rounded-2xl bg-slate-100 text-slate-700">
          <UserX className="h-6 w-6" />
        </div>
        <h1 className="text-xl font-bold text-slate-900">
          Status Keanggotaan Nonaktif
        </h1>
        <p className="mt-2 text-sm leading-relaxed text-slate-600">
          Halo <span className="font-semibold text-slate-900">{membership.member.full_name}</span>, akun Anda (
          <span className="font-medium text-slate-800">{membership.email}</span>) saat ini tercatat{' '}
          <span className="font-semibold text-rose-700">tidak aktif</span>.
        </p>
        <p className="mt-3 rounded-xl bg-slate-50 p-3 text-xs leading-relaxed text-slate-600">
          Akun yang telah dinonaktifkan tidak lagi memiliki akses ke data kas, transaksi, maupun laporan tim, namun riwayat iuran Anda tetap tersimpan dengan aman. Jika ini merupakan kekeliruan, silakan hubungi pengelola kas tim untuk mengaktifkan kembali akun Anda.
        </p>
        <div className="mt-6">
          <SignOutButton />
        </div>
      </div>
    </main>
  );
}
