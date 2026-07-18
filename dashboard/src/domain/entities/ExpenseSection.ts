export type ExpenseSectionType = 'general' | 'salary' | 'vehicles';
export type ExpenseSectionKind = 'expense' | 'cost';

export type ExpenseSection = {
  id: string;
  name: string;
  type: ExpenseSectionType;
  kind: ExpenseSectionKind;
  sortOrder: number;
  isSystem: boolean;
  createdAt: string;
};
