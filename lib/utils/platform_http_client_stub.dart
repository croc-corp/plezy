import 'package:http/browser_client.dart';
import 'package:http/http.dart' as http;

import 'managed_http_client.dart';

/// Web client, selected via conditional imports next to
/// `platform_http_client_io.dart`. The browser owns connection pooling, proxy
/// and trust decisions, so there is nothing to tune here.
http.Client createPlatformClient() => ManagedHttpClient(BrowserClient(), debugLabel: 'BrowserClient');
