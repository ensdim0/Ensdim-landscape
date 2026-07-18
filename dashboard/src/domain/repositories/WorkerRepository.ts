import { Worker } from "@domain/entities/Worker";

export interface WorkerRepository {
  listWorkers(): Promise<Worker[]>;
  createWorker(payload: {
    name: string;
    phone: string;
    visaStart: string;
    visaEnd: string;
    salary: number;
    notes?: string | null;
  }): Promise<Worker>;
  updateWorker(payload: {
    id: string;
    name: string;
    phone: string;
    visaStart: string;
    visaEnd: string;
    salary: number;
    notes?: string | null;
  }): Promise<Worker>;
  deleteWorker(id: string): Promise<void>;
}
