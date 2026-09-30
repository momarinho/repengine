import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:server_mobile/src/services/go_core_client.dart';

final _goCoreBaseUrl =
    Platform.environment['GO_CORE_URL'] ?? 'http://localhost:8080';

final _goCoreClient = GoCoreClient(baseUrl: _goCoreBaseUrl);

Handler middleware(Handler handler) {
  return handler
      .use(provider<GoCoreClient>((_) => _goCoreClient))
      .use(requestLogger());
}
