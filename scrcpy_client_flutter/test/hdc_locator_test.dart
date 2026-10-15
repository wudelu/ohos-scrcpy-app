import 'package:flutter_test/flutter_test.dart';
import 'package:scrcpy_client_flutter/hdc/hdc_locator.dart';

void main() {
  test('显式存在的 HDC 路径优先', () async {
    final locator = HdcLocator(
      environment: const <String, String>{},
      isMacOS: true,
      isWindows: false,
      isLinux: false,
      fileExists: (String path) async => path == '/custom/hdc',
      commandLookup: (String _) async => null,
      bundledPath: null,
    );

    expect(await locator.resolve('/custom/hdc'), '/custom/hdc');
  });

  test('HDC_PATH 优先于 SDK、内置工具与 PATH', () async {
    final locator = HdcLocator(
      environment: const <String, String>{
        'HDC_PATH': '/env/hdc',
        'HOME': '/Users/tester',
      },
      isMacOS: true,
      isWindows: false,
      isLinux: false,
      fileExists: (String path) async =>
          path == '/env/hdc' || path.contains('/Sdk/23/'),
      commandLookup: (String _) async => '/path/hdc',
      bundledPath: '/bundle/hdc',
    );

    expect(await locator.resolve('hdc'), '/env/hdc');
  });

  test('SDK 23 优先于 DevEco、内置工具与 PATH', () async {
    final locator = HdcLocator(
      environment: const <String, String>{'HOME': '/Users/tester'},
      isMacOS: true,
      isWindows: false,
      isLinux: false,
      fileExists: (String path) async =>
          path == '/Users/tester/Library/OpenHarmony/Sdk/23/toolchains/hdc',
      commandLookup: (String _) async => '/path/hdc',
      bundledPath: null,
    );

    expect(
      await locator.resolve('hdc'),
      '/Users/tester/Library/OpenHarmony/Sdk/23/toolchains/hdc',
    );
  });

  test('DevEco SDK 优先于内置工具与 PATH', () async {
    const devecoPath =
        '/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc';
    final locator = HdcLocator(
      environment: const <String, String>{},
      isMacOS: true,
      isWindows: false,
      isLinux: false,
      fileExists: (String path) async => path == devecoPath,
      commandLookup: (String _) async => '/path/hdc',
      bundledPath: '/bundle/hdc',
    );

    expect(await locator.resolve('hdc'), devecoPath);
  });

  test('常见 SDK 均不可用时使用应用内置 HDC', () async {
    final locator = HdcLocator(
      environment: const <String, String>{},
      isMacOS: true,
      isWindows: false,
      isLinux: false,
      fileExists: (String path) async => path == '/bundle/hdc',
      commandLookup: (String _) async => null,
      bundledPath: '/bundle/hdc',
    );

    expect(await locator.resolve('hdc'), '/bundle/hdc');
  });

  test('配置与常见路径不可用时回退到 PATH', () async {
    final locator = HdcLocator(
      environment: const <String, String>{},
      isMacOS: true,
      isWindows: false,
      isLinux: false,
      fileExists: (String _) async => false,
      commandLookup: (String command) async =>
          command == 'hdc' ? '/path/hdc' : null,
      bundledPath: null,
    );

    expect(await locator.resolve('hdc'), '/path/hdc');
  });
}
