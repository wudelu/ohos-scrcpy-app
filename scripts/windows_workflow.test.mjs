import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const repositoryRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const workflowPath = path.join(repositoryRoot, '.github', 'workflows', 'build-windows.yml');

test('Windows 工作流使用受控触发器和最小权限', async () => {
  const workflow = await readFile(workflowPath, 'utf8');

  assert.match(workflow, /^\s*workflow_dispatch:\s*$/m);
  assert.match(workflow, /^\s*tags:\s*\n\s*- ['"]v\*['"]\s*$/m);
  assert.match(workflow, /^permissions:\s*\n\s+contents: read\s*$/m);
  assert.match(workflow, /^\s*runs-on: windows-2022\s*$/m);
  assert.match(workflow, /^\s*timeout-minutes: 60\s*$/m);
  assert.match(workflow, /^\s*cancel-in-progress: true\s*$/m);

  assert.doesNotMatch(workflow, /contents:\s*write/);
  assert.doesNotMatch(workflow, /(?:softprops\/action-gh-release|gh\s+release\s+create)/);
});

test('Windows 工作流检查客户端后调用唯一打包入口', async () => {
  const workflow = await readFile(workflowPath, 'utf8');

  assert.match(workflow, /uses: actions\/checkout@v4/);
  assert.match(workflow, /uses: subosito\/flutter-action@v2/);
  assert.match(workflow, /flutter-version: ['"]3\.41\.9['"]/);
  assert.match(workflow, /^\s*cache: true\s*$/m);
  assert.match(workflow, /choco install innosetup --yes --no-progress/);

  const pubGet = workflow.indexOf('flutter pub get');
  const analyze = workflow.indexOf('flutter analyze');
  const flutterTest = workflow.indexOf('flutter test');
  const packageScript = workflow.indexOf('package_win.ps1');
  assert.ok(pubGet >= 0, '缺少 flutter pub get');
  assert.ok(analyze > pubGet, 'flutter analyze 必须在依赖解析之后');
  assert.ok(flutterTest > analyze, 'flutter test 必须在静态检查之后');
  assert.ok(packageScript > flutterTest, '打包脚本必须在检查和测试通过后执行');

  assert.match(workflow, /WIN_PFX_BASE64:\s*\$\{\{ secrets\.WIN_PFX_BASE64 \}\}/);
  assert.match(workflow, /WIN_PFX_PASSWORD:\s*\$\{\{ secrets\.WIN_PFX_PASSWORD \}\}/);
});

test('Windows 工作流上传安装包并在产物缺失时失败', async () => {
  const workflow = await readFile(workflowPath, 'utf8');

  assert.match(workflow, /uses: actions\/upload-artifact@v4/);
  assert.match(workflow, /scrcpy_client_flutter\/build\/dist\/HongJing-Setup-\*\.exe/);
  assert.match(workflow, /^\s*if-no-files-found: error\s*$/m);
  assert.match(workflow, /^\s*retention-days: 14\s*$/m);
});
