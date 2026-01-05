import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';

class TotpService {
  TotpService._();
  static final TotpService instance = TotpService._();

  final ValueNotifier<String> current = ValueNotifier<String>('');
  final ValueNotifier<int> secondsRemaining = ValueNotifier<int>(30);

  String _secretBase32 = '';
  Timer? _timer;
  int _interval = 30;
  int _digits = 6;

  void setSharedSecret(String base32Secret) {
    _secretBase32 = base32Secret.replaceAll(' ', '').toUpperCase();
    _updateNow();
  }

  void start({int interval = 30, int digits = 6}) {
    _interval = interval;
    _digits = digits;
    _timer?.cancel();
    _updateNow();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateNow());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  String getCode() => current.value;

  void _updateNow() {
    if (_secretBase32.isEmpty) {
      current.value = '';
      secondsRemaining.value = _interval;
      return;
    }

    final now = DateTime.now().toUtc();
    final epochSeconds = now.millisecondsSinceEpoch ~/ 1000;
    final counter = epochSeconds ~/ _interval;
    final remaining = _interval - (epochSeconds % _interval);

    secondsRemaining.value = remaining;
    current.value = _generateTotp(_secretBase32, counter, _digits);
  }

  String _generateTotp(String secretBase32, int counter, int digits) {
    final key = _base32Decode(secretBase32);
    final counterBytes = _int64ToBytes(counter);
    final hmac = Hmac(sha1, key);
    final hash = hmac.convert(counterBytes).bytes;

    final offset = hash.last & 0x0f;
    final binary = ((hash[offset] & 0x7f) << 24) |
    ((hash[offset + 1] & 0xff) << 16) |
    ((hash[offset + 2] & 0xff) << 8) |
    (hash[offset + 3] & 0xff);
    final otp = binary % (pow10(digits));
    return otp.toString().padLeft(digits, '0');
  }

  static int pow10(int digits) {
    var v = 1;
    for (var i = 0; i < digits; i++) {
      v *= 10;
    }
    return v;
  }

  List<int> _int64ToBytes(int value) {
    final bytes = List.filled(8, 0);
    for (var i = 7; i >= 0; i--) {
      bytes[i] = value & 0xff;
      value = value >> 8;
    }
    return bytes;
  }

  Uint8List _base32Decode(String input) {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    final cleaned = input.replaceAll('=', '');
    final output = <int>[];
    var buffer = 0;
    var bitsLeft = 0;
    for (var i = 0; i < cleaned.length; i++) {
      final val = alphabet.indexOf(cleaned[i]);
      if (val < 0) continue;
      buffer = (buffer << 5) | val;
      bitsLeft += 5;
      if (bitsLeft >= 8) {
        bitsLeft -= 8;
        output.add((buffer >> bitsLeft) & 0xff);
      }
    }
    return Uint8List.fromList(output);
  }
}
