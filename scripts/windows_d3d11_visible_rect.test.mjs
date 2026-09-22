import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const decoder = readFileSync(
  new URL(
    '../scrcpy_client_flutter/windows/runner/h264_d3d11_decoder.cpp',
    import.meta.url,
  ),
  'utf8',
);

test('D3D11 硬解按协议视频尺寸裁掉解码纹理的对齐填充', () => {
  assert.match(decoder, /visible_w\s*=\s*width_\s*>\s*0\s*\?\s*width_\s*:\s*actual_w/);
  assert.match(decoder, /visible_h\s*=\s*height_\s*>\s*0\s*\?\s*height_\s*:\s*actual_h/);
  assert.match(decoder, /VideoProcessorSetStreamSourceRect\([\s\S]*?&source_rect\)/);
  assert.match(decoder, /VideoProcessorSetStreamDestRect\([\s\S]*?&destination_rect\)/);
  assert.match(decoder, /EnsureOutputTexture\(visible_w,\s*visible_h\)/);
  assert.match(decoder, /descriptor_\.visible_width\s*=\s*visible_w/);
  assert.match(decoder, /descriptor_\.visible_height\s*=\s*visible_h/);
});
