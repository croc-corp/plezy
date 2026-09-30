import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/utils/ip_literal.dart';

void main() {
  test('parses IPv4 and IPv6 into network-order bytes in browser-safe code', () {
    expect(parseIpLiteral('192.0.2.3'), [192, 0, 2, 3]);
    expect(parseIpLiteral('[2001:db8::1:2]'), [0x20, 0x01, 0x0d, 0xb8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 2]);
    expect(parseIpLiteral('::1'), [...List<int>.filled(15, 0), 1]);
    expect(parseIpLiteral('::ffff:192.0.2.1'), [...List<int>.filled(10, 0), 0xff, 0xff, 192, 0, 2, 1]);
  });

  test('rejects hostnames and malformed IP literals', () {
    for (final host in ['plex.tv', '256.1.1.1', '1.2.3', '2001::db8::1', '1:2:3:4:5:6:7:', '']) {
      expect(parseIpLiteral(host), isNull, reason: host);
    }
  });
}
