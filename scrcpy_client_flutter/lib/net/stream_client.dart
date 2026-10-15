import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'protocol.dart';

class StreamClient {
  Socket? _socket;
  StreamSubscription<Uint8List>? _socketSubscription;
  final PacketParser _parser = PacketParser();

  final _packetCtrl = StreamController<Packet>.broadcast();
  Stream<Packet> get packets => _packetCtrl.stream;

  bool get connected => _socket != null;

  Future<void> connect(String host, int port) async {
    // 新连接前必须清掉上次残留的半包字节，否则首批字节会被错位解析。
    _parser.reset();
    final s = await Socket.connect(
      host,
      port,
      timeout: const Duration(seconds: 5),
    );
    s.setOption(SocketOption.tcpNoDelay, true);
    _socket = s;
    // 读流错误由 onError 上报；同时消费 done 的同一错误，避免成为未处理 Future。
    unawaited(s.done.then((_) {}, onError: (Object error) {}));
    _socketSubscription = s.listen(
      (data) {
        if (!identical(_socket, s)) return;
        for (final p in _parser.feed(Uint8List.fromList(data))) {
          _packetCtrl.add(p);
        }
      },
      onError: (e, st) {
        if (!identical(_socket, s)) return;
        _socket = null;
        _socketSubscription = null;
        _parser.reset();
        s.destroy();
        if (!_packetCtrl.isClosed) {
          _packetCtrl.addError(e, st);
        }
      },
      onDone: () {
        if (!identical(_socket, s)) return;
        _socket = null;
        _socketSubscription = null;
        _parser.reset();
        if (!_packetCtrl.isClosed) {
          _packetCtrl.addError(const SocketException('设备视频连接已关闭'));
        }
      },
      cancelOnError: true,
    );
  }

  void send(int type, Uint8List payload) {
    final s = _socket;
    if (s == null) return;
    s.add(encodePacket(type, payload).asUint8List());
  }

  Future<void> disconnect() async {
    final s = _socket;
    final subscription = _socketSubscription;
    _socket = null;
    _socketSubscription = null;
    _parser.reset();
    await subscription?.cancel();
    if (s != null) {
      try {
        await s.close();
      } catch (_) {}
    }
  }

  Future<void> dispose() async {
    await disconnect();
    await _packetCtrl.close();
  }
}
