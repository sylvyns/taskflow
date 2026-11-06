/// Ошибки бизнес-логики, которые репозитории бросают наверх,
/// а UI показывает пользователю понятным сообщением.
sealed class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Некорректные входные данные (пустое имя, неверный email и т.п.).
class ValidationException extends AppException {
  const ValidationException(super.message);
}

/// Запись не найдена (задача, проект, пользователь).
class NotFoundException extends AppException {
  const NotFoundException(super.message);
}

/// Нарушение правила предметной области
/// (исполнитель не в проекте, лимит задач, удаление пользователя с задачами…).
class BusinessRuleException extends AppException {
  const BusinessRuleException(super.message);
}
