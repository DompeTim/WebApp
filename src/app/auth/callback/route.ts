import { NextResponse, type NextRequest } from 'next/server';
import { isSupabaseConfigured } from '@/lib/supabase/config';
import { createClient } from '@/lib/supabase/server';
import type { Member } from '@/types/database';

export async function GET(request: NextRequest) {
  const { searchParams, origin } = new URL(request.url);
  const forwardedHost = request.headers.get('x-forwarded-host');
  const isLocalEnv = process.env.NODE_ENV === 'development';
  const baseUrl =
    !isLocalEnv && forwardedHost ? `https://${forwardedHost}` : origin;

  if (!isSupabaseConfigured()) {
    return NextResponse.redirect(`${baseUrl}/login`);
  }

  const code = searchParams.get('code');
  if (!code) {
    return NextResponse.redirect(`${baseUrl}/login?error=missing_code`);
  }

  const supabase = await createClient();
  const { error } = await supabase.auth.exchangeCodeForSession(code);

  if (error) {
    return NextResponse.redirect(`${baseUrl}/login?error=auth_failed`);
  }

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user?.email) {
    return NextResponse.redirect(`${baseUrl}/login?error=auth_failed`);
  }

  const normalizedEmail = user.email.toLowerCase().trim();
  const { data: member } = await supabase
    .from('members')
    .select('id, is_active')
    .eq('email', normalizedEmail)
    .maybeSingle<Pick<Member, 'id' | 'is_active'>>();

  if (!member) {
    return NextResponse.redirect(`${baseUrl}/unregistered`);
  }

  if (!member.is_active) {
    return NextResponse.redirect(`${baseUrl}/inactive`);
  }

  return NextResponse.redirect(`${baseUrl}/`);
}
