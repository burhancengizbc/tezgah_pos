/// Uygulama hatalari (kullaniciya gosterilecek mesajla).
sealed class Failure {
  final String message;
  const Failure(this.message);
}

class DatabaseFailure extends Failure {
  const DatabaseFailure([String m = 'Veritabani hatasi.']) : super(m);
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure([String m = 'Kayit bulunamadi.']) : super(m);
}

class BackupFailure extends Failure {
  const BackupFailure(super.message);
}

class SecurityFailure extends Failure {
  const SecurityFailure(super.message);
}

class UnexpectedFailure extends Failure {
  const UnexpectedFailure([String m = 'Beklenmeyen bir hata olustu.'])
      : super(m);
}

/// Dahili exception'lar.
class AppException implements Exception {
  final String message;
  AppException(this.message);
  @override
  String toString() => 'AppException: $message';
}
