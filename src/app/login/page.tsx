import { redirect } from 'next/navigation';
import { Wallet, AlertTriangle } from 'lucide-react';
import { getCurrentMembership } from '@/lib/auth';
import { GoogleSignInButton } from '@/components/GoogleSignInButton';

export const dynamic = 'force-dynamic';

interface LoginPageProps {
  searchParams: Promise<{ error?: string }>;
}

export default async function LoginPage({ searchParams }: LoginPageProps) {
  const membership = await getCurrentMembership();

  if (membership.status === 'active') {
    redirect('/');
  }
  if (membership.status === 'inactive') {
    redirect('/inactive');
  }
  if (membership.status === 'unregistered') {
    redirect('/unregistered');
  }

  const { error } = await searchParams;

  const errorText =
    error === 'auth_failed'
      ? 'Proses autentikasi Google gagal atau dibatalkan. Silakan coba lagi.'
      : error === 'missing_code'
        ? 'Kode verifikasi login tidak ditemukan. Silakan masuk kembali.'
        : null;

  const isConfigured = membership.status !== 'unconfigured';

  return (
    <main className="flex min-h-screen items-center justify-center bg-slate-50 px-4 py-10">
      <div className="w-full max-w-md rounded-2xl border border-slate-200 bg-white p-6 shadow-sm sm:p-8">
        <div className="mb-6 flex flex-col items-center text-center">
          <div className="mb-3 flex h-12 w-12 items-center justify-center rounded-2xl bg-emerald-600 text-white shadow-sm">
            <Wallet className="h-6 w-6" />
          </div>
          <h1 className="text-2xl font-bold tracking-tight text-slate-900">
            Dompetim
          </h1>
          <p className="mt-1 text-sm text-slate-500">
            Kas tim yang transparan &amp; mudah dipantau
          </p>
        </div>

        {!isConfigured && (
          <div className="mb-5 rounded-xl border border-amber-200 bg-amber-50 p-4 text-xs leading-relaxed text-amber-900">
            <div className="mb-1 flex items-center gap-2 font-semibold">
              <AlertTriangle className="h-4 w-4 shrink-0 text-amber-600" />
              <span>Konfigurasi Supabase Belum Diisi</span>
            </div>
            <p>
              Isi <code className="rounded bg-amber-100 px-1 py-0.5 font-mono">NEXT_PUBLIC_SUPABASE_URL</code> dan{' '}
              <code className="rounded bg-amber-100 px-1 py-0.5 font-mono">NEXT_PUBLIC_SUPABASE_ANON_KEY</code> di file{' '}
              <code className="rounded bg-amber-100 px-1 py-0.5 font-mono">.env.local</code>, lalu restart server untuk mengaktifkan login Google.
            </p>
          </div>
        )}

        {errorText && (
          <div className="mb-5 rounded-xl border border-rose-200 bg-rose-50 px-4 py-3 text-xs font-medium text-rose-700">
            {errorText}
          </div>
        )}

        <GoogleSignInButton isConfigured={isConfigured} />

        <p className="mt-6 text-center text-xs leading-relaxed text-slate-500">
          Akses hanya dibuka untuk akun Google anggota yang telah didaftarkan oleh pengelola tim.
        </p>
      </div>
    </main>
  );
}
