import 'dart:io';

typedef FileExists = Future<bool> Function(String path);
typedef CommandLookup = Future<String?> Function(String command);

class HdcLocator {
  HdcLocator({
    Map<String, String>? environment,
    bool? isMacOS,
    bool? isWindows,
    bool? isLinux,
    FileExists? fileExists,
    CommandLookup? commandLookup,
    this.bundledPath,
  }) : environment = environment ?? Platform.environment,
       isMacOS = isMacOS ?? Platform.isMacOS,
       isWindows = isWindows ?? Platform.isWindows,
       isLinux = isLinux ?? Platform.isLinux,
       fileExists = fileExists ?? ((String path) => File(path).exists()),
       commandLookup = commandLookup ?? _defaultCommandLookup;

  final Map<String, String> environment;
  final bool isMacOS;
  final bool isWindows;
  final bool isLinux;
  final FileExists fileExists;
  final CommandLookup commandLookup;
  final String? bundledPath;

  Future<String> resolve(String requestedPath) async {
    if (requestedPath != 'hdc' && await fileExists(requestedPath)) {
      return requestedPath;
    }

    final configured = environment['HDC_PATH'];
    if (configured != null &&
        configured.isNotEmpty &&
        await fileExists(configured)) {
      return configured;
    }

    for (final candidate in _sdkCandidates()) {
      if (await fileExists(candidate)) return candidate;
    }

    if (bundledPath != null && await fileExists(bundledPath!)) {
      return bundledPath!;
    }

    final fromPath = await commandLookup('hdc');
    return fromPath ?? requestedPath;
  }

  List<String> _sdkCandidates() {
    final home = environment['HOME'] ?? '';
    final localAppData = environment['LOCALAPPDATA'] ?? '';
    final programFiles = environment['ProgramFiles'] ?? '';
    return <String>[
      if (isMacOS && home.isNotEmpty) ...<String>[
        '$home/Library/OpenHarmony/Sdk/23/toolchains/hdc',
      ],
      if (isMacOS)
        '/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc',
      if (isLinux && home.isNotEmpty) '$home/OpenHarmony/Sdk/23/toolchains/hdc',
      if (isWindows && localAppData.isNotEmpty)
        '$localAppData\\OpenHarmony\\Sdk\\23\\toolchains\\hdc.exe',
      if (isWindows && programFiles.isNotEmpty)
        '$programFiles\\Huawei\\DevEco Studio\\sdk\\default\\openharmony\\toolchains\\hdc.exe',
    ];
  }

  static Future<String?> _defaultCommandLookup(String command) async {
    final executable = Platform.isWindows ? 'where' : '/usr/bin/which';
    try {
      final result = await Process.run(executable, <String>[command]);
      if (result.exitCode != 0) return null;
      final first = result.stdout
          .toString()
          .trim()
          .split(RegExp(r'\r?\n'))
          .first;
      return first.isEmpty ? null : first;
    } on ProcessException {
      return null;
    }
  }
}
