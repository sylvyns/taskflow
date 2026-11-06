import '../models/app_exception.dart';

/// Проверка корректности данных перед сохранением в БД.
class Validators {
  Validators._();

  static final RegExp _emailPattern = RegExp(r'^[\w.+\-]+@[\w\-]+(\.[\w\-]+)+$');

  /// Обязательная строка: обрезает пробелы, проверяет пустоту и длину.
  static String requiredText(String? value, String field, {int maxLength = 200}) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      throw ValidationException('Поле «$field» не может быть пустым');
    }
    if (text.length > maxLength) {
      throw ValidationException('Поле «$field» длиннее $maxLength символов');
    }
    return text;
  }

  /// Необязательная строка (может быть пустой).
  static String optionalText(String? value, String field, {int maxLength = 5000}) {
    final text = (value ?? '').trim();
    if (text.length > maxLength) {
      throw ValidationException('Поле «$field» длиннее $maxLength символов');
    }
    return text;
  }

  /// Email: приводится к нижнему регистру и проверяется по шаблону.
  static String email(String? value) {
    final text = (value ?? '').trim().toLowerCase();
    if (text.isEmpty) {
      throw const ValidationException('Укажите email');
    }
    if (text.length > 254 || !_emailPattern.hasMatch(text)) {
      throw ValidationException('Некорректный email: $text');
    }
    return text;
  }
}
