import 'package:bustan_amari/core/errors/app_exception.dart';
import 'package:bustan_amari/core/l10n/app_localizations.dart';
import 'package:bustan_amari/core/types/result.dart';
import 'package:bustan_amari/domain/repositories/auth_repository.dart';

/// Handles user logout with error wrapping.
class LogoutUseCase {
  final AuthRepository _authRepository;

  const LogoutUseCase(this._authRepository);

  Future<Result<void>> call() async {
    try {
      await _authRepository.logout();
      return const Success(null);
    } on AppException catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(
        AppException(
          AppLocalizations.current.tr('logoutFailed'),
          ErrorType.unknown,
          e,
        ),
      );
    }
  }
}
