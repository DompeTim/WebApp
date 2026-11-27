import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'Dompetim — Kas Tim yang Transparan',
  description:
    'Aplikasi pencatatan uang kas dan iuran bulanan tim kantor secara transparan.',
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="id">
      <body className="min-h-screen bg-slate-50 text-slate-900">{children}</body>
    </html>
  );
}
