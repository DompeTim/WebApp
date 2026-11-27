import { requireActiveMember } from '@/lib/auth';
import { createClient } from '@/lib/supabase/server';
import { AppShell } from '@/components/AppShell';
import type { Settings } from '@/types/database';

export const dynamic = 'force-dynamic';

export default async function AuthenticatedLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  const member = await requireActiveMember();
  const supabase = await createClient();

  const { data: settings } = await supabase
    .from('settings')
    .select('org_name')
    .eq('id', 1)
    .maybeSingle<Pick<Settings, 'org_name'>>();

  const orgName = settings?.org_name ?? 'Dompetim';

  return (
    <AppShell member={member} orgName={orgName}>
      {children}
    </AppShell>
  );
}
