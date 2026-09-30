// ignore_for_file: implementation_imports - the package's barrel pulls in its
// win32 IPC transport; only the platform-neutral models are re-exported here.
import 'dart:async';

import 'package:dart_discord_presence/src/models/discord_event.dart';
import 'package:dart_discord_presence/src/models/discord_presence.dart';

export 'package:dart_discord_presence/src/exceptions/discord_rpc_exception.dart';
export 'package:dart_discord_presence/src/models/discord_event.dart';
export 'package:dart_discord_presence/src/models/discord_presence.dart';
export 'package:dart_discord_presence/src/models/discord_user.dart';
export 'package:dart_discord_presence/src/models/enums.dart';

/// Web stand-in for `package:dart_discord_presence`: a browser has no access
/// to the Discord client's local IPC socket, so Rich Presence is unavailable.
class DiscordRPC {
  static bool get isAvailable => false;

  Stream<DiscordReadyEvent> get onReady => const Stream.empty();
  Stream<DiscordDisconnectedEvent> get onDisconnected => const Stream.empty();
  Stream<DiscordErrorEvent> get onError => const Stream.empty();

  Future<void> initialize(String applicationId) =>
      Future.error(UnsupportedError('Discord RPC is not supported on the web'));
  Future<void> setPresence(DiscordPresence presence) async {}
  Future<void> clearPresence() async {}
  Future<void> dispose() async {}
}
