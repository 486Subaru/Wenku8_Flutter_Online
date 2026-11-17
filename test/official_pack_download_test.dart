import 'package:flutter_test/flutter_test.dart';
import 'package:wenku8_flutter/legacy_transport.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('official pack format and node are validated before native call', () async {
    await expectLater(
      LegacyTransport.openPackDownload(1, type: 'pdf', node: 1),
      throwsFormatException,
    );
    await expectLater(
      LegacyTransport.openPackDownload(1, type: 'utf8', node: 3),
      throwsFormatException,
    );
  });

  test('all official TXT download choices route to native browser action', () async {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final observed = <Map>[];
    messenger.setMockMethodCallHandler(LegacyTransport.channel, (call) async {
      expect(call.method, 'openPackDownload');
      observed.add(call.arguments as Map);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(LegacyTransport.channel, null));
    for (final type in ['txt', 'utf8', 'big5']) {
      for (final node in [1, 2]) {
        await LegacyTransport.openPackDownload(2231, type: type, node: node);
      }
    }
    expect(observed, hasLength(6));
    expect(observed.first['bookId'], 2231);
  });
}
