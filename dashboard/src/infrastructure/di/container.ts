import { SupabaseAuthRepository } from "@infrastructure/repositories/SupabaseAuthRepository";
import { SupabaseAdminRepository } from "@infrastructure/repositories/SupabaseAdminRepository";
import { SupabaseSupervisorRepository } from "@infrastructure/repositories/SupabaseSupervisorRepository";
import { SupabaseLineRepository } from "@infrastructure/repositories/SupabaseLineRepository";
import { SupabaseFleetRepository } from "@infrastructure/repositories/SupabaseFleetRepository";
import { SupabasePhoneRepository } from "@infrastructure/repositories/SupabasePhoneRepository";
import { SupabaseWorkerRepository } from "@infrastructure/repositories/SupabaseWorkerRepository";

export const container = {
  authRepository: new SupabaseAuthRepository(),
  adminRepository: new SupabaseAdminRepository(),
  supervisorRepository: new SupabaseSupervisorRepository(),
  lineRepository: new SupabaseLineRepository(),
  fleetRepository: new SupabaseFleetRepository(),
  phoneRepository: new SupabasePhoneRepository(),
  workerRepository: new SupabaseWorkerRepository()
};
