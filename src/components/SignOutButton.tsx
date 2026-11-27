'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { LogOut } from 'lucide-react';
import { createClient } from '@/lib/supabase/client';

interface SignOutButtonProps {
  variant?: 'default' | 'subtle';
  className?: string;
}

export function SignOutButton({
  variant = 'default',
  className = '',
}: SignOutButtonProps) {
  const router = useRouter();
  const [loading, setLoading] = useState(false);

  async function handleSignOut() {
    if (loading) return;
    setLoading(true);
    try {
      const supabase = createClient();
      await supabase.auth.signOut();
    } finally {
      router.push('/login');
      router.refresh();
    }
  }

  const baseClass =
    variant === 'subtle'
      ? 'inline-flex items-center justify-center gap-2 rounded-lg px-3 py-2 text-sm font-medium text-slate-600 transition hover:bg-slate-100 hover:text-slate-900 disabled:opacity-50'
      : 'inline-flex w-full items-center justify-center gap-2 rounded-xl border border-slate-300 bg-white px-4 py-2.5 text-sm font-semibold text-slate-700 transition hover:bg-slate-50 disabled:opacity-50';

  return (
    <button
      type="button"
      onClick={handleSignOut}
      disabled={loading}
      className={`${baseClass} ${className}`.trim()}
    >
      <LogOut className="h-4 w-4 shrink-0" />
      <span>{loading ? 'Keluar...' : 'Keluar'}</span>
    </button>
  );
}
