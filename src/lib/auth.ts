import { redirect } from 'next/navigation';
import { isSupabaseConfigured } from '@/lib/supabase/config';
import { createClient } from '@/lib/supabase/server';
import type { Member } from '@/types/database';

export type MembershipResult =
  | { status: 'unconfigured' }
  | { status: 'unauthenticated' }
  | { status: 'unregistered'; email: string }
  | { status: 'inactive'; email: string; member: Member }
  | { status: 'active'; email: string; member: Member };

export async function getCurrentMembership(): Promise<MembershipResult> {
  if (!isSupabaseConfigured()) {
    return { status: 'unconfigured' };
  }

  const supabase = await createClient();
  const {
    data: { user },
    error: authError,
  } = await supabase.auth.getUser();

  if (authError || !user?.email) {
    return { status: 'unauthenticated' };
  }

  const normalizedEmail = user.email.toLowerCase().trim();

  const { data: member, error: memberError } = await supabase
    .from('members')
    .select('*')
    .eq('email', normalizedEmail)
    .maybeSingle<Member>();

  if (memberError || !member) {
    return { status: 'unregistered', email: normalizedEmail };
  }

  if (!member.is_active) {
    return { status: 'inactive', email: normalizedEmail, member };
  }

  return { status: 'active', email: normalizedEmail, member };
}

export async function requireActiveMember(): Promise<Member> {
  const result = await getCurrentMembership();

  switch (result.status) {
    case 'unconfigured':
    case 'unauthenticated':
      redirect('/login');
    case 'unregistered':
      redirect('/unregistered');
    case 'inactive':
      redirect('/inactive');
    case 'active':
      return result.member;
  }
}

export async function requireAdmin(): Promise<Member> {
  const member = await requireActiveMember();
  if (member.role !== 'admin') {
    redirect('/');
  }
  return member;
}
