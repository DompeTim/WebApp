export type MemberRole = 'admin' | 'member';
export type TrxType = 'income' | 'expense';
export type DueStatus = 'unpaid' | 'paid';

export interface Member {
  id: string;
  email: string;
  full_name: string;
  role: MemberRole;
  is_active: boolean;
  billing_start_period: string;
  created_at: string;
  updated_at: string;
}

export interface Settings {
  id: number;
  org_name: string;
  monthly_due_amount: number;
  due_day: number;
  updated_at: string;
}

export interface Category {
  id: string;
  code: string | null;
  name: string;
  type: TrxType | null;
  is_system: boolean;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface VBalance {
  opening_balance: number;
  total_income: number;
  total_expense: number;
  balance: number;
  month_income: number;
  month_expense: number;
  month_net: number;
}

export interface VMonthlySummary {
  month: string;
  income: number;
  opening_balance: number;
  expense: number;
  net: number;
}

export interface VCategorySummary {
  month: string;
  category_id: string;
  category: string;
  category_code: string | null;
  type: TrxType;
  total: number;
  trx_count: number;
}

export interface VTransaction {
  id: string;
  type: TrxType;
  amount: number;
  trx_date: string;
  counterparty: string;
  purpose: string;
  category: string;
  category_code: string | null;
  category_id: string;
  receipt_path: string | null;
  has_receipt: boolean;
  due_id: string | null;
  is_due: boolean;
  created_by_name: string;
  created_at: string;
}

export interface VMember {
  id: string;
  full_name: string;
  role: MemberRole;
  is_active: boolean;
  billing_start_period: string;
  email: string | null;
  created_at: string;
  updated_at: string;
}

export interface VDuesBoard {
  due_id: string;
  period: string;
  member_id: string;
  full_name: string;
  member_is_active: boolean;
  amount: number;
  status: DueStatus;
  paid_at: string | null;
  transaction_id: string | null;
  receipt_path: string | null;
  is_overdue: boolean;
}

export interface VAuditLog {
  id: number;
  table_name: string;
  record_id: string | null;
  action: 'INSERT' | 'UPDATE' | 'DELETE';
  old_data: Record<string, unknown> | null;
  new_data: Record<string, unknown> | null;
  actor_name: string;
  actor_email: string | null;
  created_at: string;
}
