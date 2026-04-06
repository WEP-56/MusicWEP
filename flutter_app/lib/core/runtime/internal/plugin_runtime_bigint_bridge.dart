import 'dart:convert';

class PluginRuntimeBigIntBridge {
  String handle(dynamic args) {
    final payload = _readObject(args);
    final action = payload['action']?.toString() ?? '';

    try {
      switch (action) {
        case 'create':
          return jsonEncode(<String, dynamic>{
            'value': _parseBigInt(
              payload['value']?.toString() ?? '0',
              _readRadix(payload['radix']),
            ).toString(),
          });
        case 'modPow':
          final base = _parseBigInt(payload['base']?.toString() ?? '0', 10);
          final exponent = _parseBigInt(
            payload['exponent']?.toString() ?? '0',
            10,
          );
          final modulus = _parseBigInt(
            payload['modulus']?.toString() ?? '1',
            10,
          );
          return jsonEncode(<String, dynamic>{
            'value': base.modPow(exponent, modulus).toString(),
          });
        case 'binary':
          final left = _parseBigInt(payload['left']?.toString() ?? '0', 10);
          final right = _parseBigInt(payload['right']?.toString() ?? '0', 10);
          final operator = payload['operator']?.toString() ?? '';
          final result = switch (operator) {
            'add' => left + right,
            'subtract' || 'minus' => left - right,
            'multiply' => left * right,
            'divide' => left ~/ right,
            'mod' => left % right,
            _ => left,
          };
          return jsonEncode(<String, dynamic>{'value': result.toString()});
        case 'compare':
          final left = _parseBigInt(payload['left']?.toString() ?? '0', 10);
          final right = _parseBigInt(payload['right']?.toString() ?? '0', 10);
          final comparison = left.compareTo(right);
          return jsonEncode(<String, dynamic>{'value': comparison});
        case 'toString':
          final value = _parseBigInt(payload['value']?.toString() ?? '0', 10);
          final radix = _readRadix(payload['radix']) ?? 10;
          return jsonEncode(<String, dynamic>{
            'value': value.toRadixString(radix),
          });
        default:
          return jsonEncode(<String, dynamic>{
            'error': 'Unknown bigint action: $action',
          });
      }
    } catch (error, stackTrace) {
      return jsonEncode(<String, dynamic>{
        'error': error.toString(),
        'stackTrace': stackTrace.toString(),
      });
    }
  }

  BigInt _parseBigInt(String value, int? radix) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return BigInt.zero;
    }
    return BigInt.parse(normalized, radix: radix ?? 10);
  }

  int? _readRadix(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  Map<String, dynamic> _readObject(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, entry) => MapEntry(key.toString(), entry));
    }
    return <String, dynamic>{};
  }
}
