import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:scrcpy_client_flutter/display/display_geometry.dart';
import 'package:scrcpy_client_flutter/net/protocol.dart';

void main() {
  test('显示信息按大端序解析并严格校验', () {
    final body = Uint8List(9);
    final view = ByteData.sublistView(body);
    view.setUint32(0, 1280, Endian.big);
    view.setUint32(4, 800, Endian.big);
    view.setUint8(8, 3);

    final info = DisplayInfo.parse(body);

    expect(info.logicalWidth, 1280);
    expect(info.logicalHeight, 800);
    expect(info.rotation, 3);
    expect(() => DisplayInfo.parse(Uint8List(8)), throwsFormatException);

    body[8] = 4;
    expect(() => DisplayInfo.parse(body), throwsFormatException);

    view.setUint32(0, 0, Endian.big);
    body[8] = 0;
    expect(() => DisplayInfo.parse(body), throwsFormatException);
  });

  test('原生方向视频按设备 rotation 旋转到逻辑显示方向', () {
    const display = DisplayInfo(
      logicalWidth: 1280,
      logicalHeight: 800,
      rotation: 3,
    );

    expect(DisplayGeometry.videoQuarterTurns(720, 1152, display), 3);
    expect(
      DisplayGeometry.effectiveVideoSize(720, 1152, display),
      const PixelSize(1152, 720),
    );
  });

  test('PixelMap 已匹配逻辑显示方向时不再旋转', () {
    const display = DisplayInfo(
      logicalWidth: 1280,
      logicalHeight: 800,
      rotation: 3,
    );

    expect(DisplayGeometry.videoQuarterTurns(1152, 720, display), 0);
    expect(
      DisplayGeometry.effectiveVideoSize(1152, 720, display),
      const PixelSize(1152, 720),
    );
  });

  test('180 度设备在宽高不变时仍应用系统 rotation', () {
    const display = DisplayInfo(
      logicalWidth: 1920,
      logicalHeight: 560,
      rotation: 2,
    );

    expect(DisplayGeometry.videoQuarterTurns(1920, 560, display), 2);
    expect(
      DisplayGeometry.effectiveVideoSize(1920, 560, display),
      const PixelSize(1920, 560),
    );
  });

  test('基础 rotation 映射和有效尺寸保持确定', () {
    expect(DisplayGeometry.quarterTurns(0), 0);
    expect(DisplayGeometry.quarterTurns(1), 1);
    expect(DisplayGeometry.quarterTurns(2), 2);
    expect(DisplayGeometry.quarterTurns(3), 3);
    expect(
      DisplayGeometry.effectiveSize(720, 1152, 0),
      const PixelSize(720, 1152),
    );
    expect(
      DisplayGeometry.effectiveSize(720, 1152, 1),
      const PixelSize(1152, 720),
    );
    expect(
      DisplayGeometry.effectiveSize(720, 1152, 2),
      const PixelSize(720, 1152),
    );
    expect(
      DisplayGeometry.effectiveSize(720, 1152, 3),
      const PixelSize(1152, 720),
    );
  });

  test('连接默认分辨率区分 USB、TCP 和缩放比例', () {
    const display = DisplayInfo(
      logicalWidth: 1280,
      logicalHeight: 800,
      rotation: 3,
    );

    expect(DisplayGeometry.defaultMaxShort(display, isWifi: false), 800);
    expect(DisplayGeometry.defaultMaxShort(display, isWifi: true), 720);
    expect(
      DisplayGeometry.scalePercent(const PixelSize(1152, 720), display),
      90,
    );
    expect(
      DisplayGeometry.scalePercent(const PixelSize(1152, 700), display),
      isNull,
    );
  });
}
