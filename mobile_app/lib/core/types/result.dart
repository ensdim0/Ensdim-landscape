import 'package:ensdim_landscape/core/errors/app_exception.dart';

/// A discriminated union representing either a successful result or a failure.
///
/// Usage:
/// ```dart
/// final result = await loginUseCase('email', 'pass');
/// switch (result) {
///   case Success(:final data): print(data);
///   case Failure(:final error): print(error.message);
/// }
/// ```
sealed class Result<T> {
  const Result();
}

/// Represents a successful operation with data of type [T].
final class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);
}

/// Represents a failed operation with an [AppException].
final class Failure<T> extends Result<T> {
  final AppException error;
  const Failure(this.error);
}
