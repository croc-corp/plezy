/// Parses an IPv4 or IPv6 literal without `dart:io`, which is unavailable in
/// browser builds. Returns four or sixteen bytes, or null for a hostname or
/// malformed address.
List<int>? parseIpLiteral(String value) {
  final host = value.startsWith('[') && value.endsWith(']') ? value.substring(1, value.length - 1) : value;
  if (!host.contains(':')) return _parseIpv4(host);

  var ipv6 = host;
  if (ipv6.contains('.')) {
    final separator = ipv6.lastIndexOf(':');
    if (separator < 0) return null;
    final tail = _parseIpv4(ipv6.substring(separator + 1));
    if (tail == null) return null;
    final first = (tail[0] << 8) | tail[1];
    final second = (tail[2] << 8) | tail[3];
    ipv6 = '${ipv6.substring(0, separator + 1)}${first.toRadixString(16)}:${second.toRadixString(16)}';
  }

  final compression = ipv6.indexOf('::');
  if (compression >= 0 && ipv6.indexOf('::', compression + 2) >= 0) return null;
  final left = compression < 0 ? ipv6 : ipv6.substring(0, compression);
  final right = compression < 0 ? '' : ipv6.substring(compression + 2);

  List<int>? groups(String part) {
    if (part.isEmpty) return <int>[];
    final result = <int>[];
    for (final group in part.split(':')) {
      if (group.isEmpty || group.length > 4 || !RegExp(r'^[0-9a-fA-F]+$').hasMatch(group)) return null;
      result.add(int.parse(group, radix: 16));
    }
    return result;
  }

  final before = groups(left);
  final after = groups(right);
  if (before == null || after == null) return null;
  if (compression < 0 && before.length != 8) return null;
  if (compression >= 0 && before.length + after.length >= 8) return null;

  final words = <int>[
    ...before,
    ...List<int>.filled(compression < 0 ? 0 : 8 - before.length - after.length, 0),
    ...after,
  ];
  return [
    for (final word in words) ...[word >> 8, word & 0xff],
  ];
}

List<int>? _parseIpv4(String host) {
  final parts = host.split('.');
  if (parts.length != 4) return null;
  final bytes = <int>[];
  for (final part in parts) {
    if (part.isEmpty || !RegExp(r'^[0-9]+$').hasMatch(part)) return null;
    final byte = int.tryParse(part);
    if (byte == null || byte > 255) return null;
    bytes.add(byte);
  }
  return bytes;
}
