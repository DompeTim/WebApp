import { requireAdmin } from '@/lib/auth';
import { PhasePlaceholder } from '@/components/PhasePlaceholder';

export const dynamic = 'force-dynamic';

export default async function PengaturanPage() {
  await requireAdmin();

  return (
    <PhasePlaceholder
      title="Pengaturan & Kategori"
      phase="Siap di Fase 2–3"
      description="Halaman khusus pengelola untuk mengelola kategori transaksi (Fase 2) serta nama organisasi, nominal iuran bulanan, dan tanggal jatuh tempo (Fase 3)."
    />
  );
}
