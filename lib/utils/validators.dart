import 'package:flutter/services.dart';

/// Client-side form validators and input formatters.
/// These mirror the constraints the backend should enforce (Section 6 of
/// the report) so users get instant feedback before any request is sent.
class Validators {
  Validators._();

  static final RegExp _emailRegExp = RegExp(
    r'^[a-zA-Z0-9.!#$%&*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)+$',
  );

  // Bangladesh mobile numbers: 11 local digits starting with 01, optionally
  // prefixed with the +880 / 880 / 0 country code. Separators (space, dash)
  // are ignored during validation.
  static final RegExp _bdPhoneRegExp = RegExp(r'^(?:\+?880|0)1[3-9]\d{8}$');

  static String? name(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your full name';
    if (v.length < 3) return 'Name is too short';
    if (!RegExp(r"^[a-zA-Z .'-]+$").hasMatch(v)) {
      return 'Only letters, spaces, and . \' - allowed';
    }
    return null;
  }

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your email';
    if (!_emailRegExp.hasMatch(v)) return 'Enter a valid email address';
    return null;
  }

  static String? phone(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your phone number';
    final digitsOnly = v.replaceAll(RegExp(r'[\s-]'), '');
    if (!_bdPhoneRegExp.hasMatch(digitsOnly)) {
      return 'Enter a valid BD number, e.g. +880 1712-345678';
    }
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Create a password';
    if (v.length < 8) return 'At least 8 characters';
    if (!RegExp(r'[A-Za-z]').hasMatch(v) || !RegExp(r'\d').hasMatch(v)) {
      return 'Use both letters and numbers';
    }
    return null;
  }

  static String? loginPassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Enter your password';
    return null;
  }

  // Optional image URL: empty is fine (a default image is used), but if
  // provided it must be a valid http/https URL.
  static String? optionalUrl(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    final uri = Uri.tryParse(v);
    if (uri == null || !uri.isAbsolute || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      return 'Enter a valid http/https URL';
    }
    return null;
  }

  // Restricts phone input to digits, +, spaces and dashes, max 17 chars.
  static final List<TextInputFormatter> phoneInputFormatters = [
    FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s-]')),
    LengthLimitingTextInputFormatter(17),
  ];

  // Blocks whitespace in email input.
  static final List<TextInputFormatter> emailInputFormatters = [
    FilteringTextInputFormatter.deny(RegExp(r'\s')),
  ];

  // Letters, spaces and common name punctuation only.
  static final List<TextInputFormatter> nameInputFormatters = [
    FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z .'-]")),
    LengthLimitingTextInputFormatter(50),
  ];
}
