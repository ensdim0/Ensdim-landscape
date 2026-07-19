import 'package:ensdim_landscape/domain/entities/contract.dart';
import 'package:ensdim_landscape/domain/entities/standalone_task.dart';
import 'package:ensdim_landscape/domain/entities/client_comment.dart';
import 'package:ensdim_landscape/domain/entities/contract_payment.dart';
import 'package:ensdim_landscape/domain/entities/contract_task.dart';
import 'package:ensdim_landscape/domain/entities/task_execution.dart';
import 'package:ensdim_landscape/domain/entities/task_photo.dart';
import 'package:ensdim_landscape/domain/entities/visit.dart';
import 'package:ensdim_landscape/domain/entities/visit_photo.dart';

/// Contract for all client-facing read operations.
///
/// Implementations must respect RLS so each user can only access
/// their own contracts and related records.
abstract class ClientRepository {
  Future<List<Contract>> listMyContracts();

  Future<Contract> updateContractGuardInfo({
    required String contractId,
    required String guardName,
    required String guardPhone,
  });

  Future<List<ContractPayment>> listContractPayments(String contractId);

  Future<List<Visit>> listContractVisits(String contractId);

  Future<List<ContractTask>> listContractTasks(String contractId);

  /// List standalone tasks that are linked to a specific contract.
  Future<List<StandaloneTask>> listStandaloneTasksByContract(String contractId);

  Future<List<VisitPhoto>> listVisitPhotos(String visitId);

  Future<List<TaskExecution>> listVisitTaskExecutions(String visitId);

  Future<List<TaskExecution>> listTaskExecutionsByTaskIds(List<String> taskIds);

  Future<List<TaskPhoto>> listTaskPhotosByExecutionIds(
    List<String> executionIds,
  );

  Future<List<ClientComment>> listVisitComments(String visitId);

  Future<ClientComment> createVisitComment({
    required String contractId,
    required String visitId,
    required String comment,
    String? attachmentFilePath,
  });
}
