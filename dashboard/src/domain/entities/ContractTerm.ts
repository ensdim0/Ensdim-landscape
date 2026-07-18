export type TaskTemplate = { id: string; title: string };
export type VisitTemplate = {
  id: string;
  description: string;
  count?: number;
  intervalMonths?: number;
  tasks: TaskTemplate[];
};
export type ContractTerm = {
  id: string;
  content: string;
  isRequired?: boolean;
  visits?: VisitTemplate[];
};
