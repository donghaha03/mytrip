// DOM/camera/worker test doubles verify lifecycle and failure handling only.
// Actual OCR is separately tested in the browser against receipt_en.png.
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import vm from 'node:vm';
import test from 'node:test';

const source = await readFile(new URL('../web/receipt.js', import.meta.url), 'utf8');
const deferred = () => { let resolve; const promise = new Promise(r => { resolve = r; }); return { promise, resolve }; };
function environment({ cameraError, noCamera = false, secure = true, mediaPromise, workerPromise, workerError, width = 100, height = 200, llm = false, fetchReceipt } = {}) {
  const elements = new Map(); const callbacks = new Map(); const timers = new Map();
  let stopCount = 0, cameraCalls = 0, terminateCount = 0, workerOptions;
  const stream = { getTracks: () => [{ stop: () => stopCount++ }] };
  const worker = { terminate: () => terminateCount++, setParameters: async () => {},
    recognize: async () => { throw new Error('failure'); } };
  const element = (key) => {
    if (!elements.has(key)) elements.set(key, { hidden: false, disabled: false, value: key === '#receipt-language' ? 'eng' : '',
      textContent: '', style: {}, focus() {}, setAttribute() {}, play: async () => {}, videoWidth: width, videoHeight: height });
    return elements.get(key);
  };
  const dialog = { setAttribute() {}, showModal() {}, close() {}, remove() { dialog.removed = true; },
    querySelector: element, querySelectorAll: () => ['#receipt-start','#receipt-shot','#receipt-retake','#receipt-file','#receipt-language','#receipt-ocr'].map(element),
    addEventListener: (name, cb) => callbacks.set(name, cb) };
  const canvas = { getContext: () => ({ fillRect() {}, drawImage() {} }), toDataURL: () => 'data:image/jpeg;base64,dGVzdA==' };
  const document = { baseURI: 'https://test.invalid/mytrip/', hidden: false, body: { append() {} },
    activeElement: { focus() {} }, createElement: (tag) => tag === 'dialog' ? dialog : canvas,
    addEventListener: (name, cb) => callbacks.set(name, cb), removeEventListener: (name) => callbacks.delete(name) };
  const window = { isSecureContext: secure, addEventListener: (name, cb) => callbacks.set(name, cb),
    removeEventListener: (name) => callbacks.delete(name) };
  if (llm) window.mytripReceiptLLM = { csrf: 'test-csrf' };
  const navigator = noCamera ? {} : { mediaDevices: { getUserMedia: async () => {
    cameraCalls++; if (cameraError) throw cameraError; return mediaPromise ?? stream;
  } } };
  const context = vm.createContext({ document, window, navigator, URL, console, AbortController, fetch: fetchReceipt,
    setTimeout: (cb) => { timers.set(1, cb); return 1; }, clearTimeout: (id) => timers.delete(id),
    Tesseract: { createWorker: async (_language, _engine, options) => {
      workerOptions = options; if (workerError) throw workerError; return workerPromise ?? worker;
    } } });
  vm.runInContext(source, context);
  return { window, document, dialog, element, callbacks, timers, stream, worker, canvas,
    counters: () => ({ stopCount, cameraCalls, terminateCount }), options: () => workerOptions };
}
async function captured(env) {
  const result = env.window.mytripReceipt.open();
  await env.element('#receipt-start').onclick();
  env.element('#receipt-shot').onclick();
  return { result };
}

test('portrait and landscape captures keep the full image without a fixed frame or letterboxing', async () => {
  for (const [width, height] of [[100, 200], [1600, 900]]) {
    const env = environment({ width, height }); const { result } = await captured(env);
    assert.equal(env.element('.frame').style.aspectRatio, `${width} / ${height}`);
    assert.equal(env.canvas.width, width);
    assert.equal(env.canvas.height, height);
    assert.doesNotMatch(env.dialog.innerHTML, /写真|정사각형으로 자르지|초점·화질 자동 검사/);
    env.window.mytripReceipt.close(); assert.equal(await result, null);
  }
});
test('camera orientation changes resize the guide before capture', async () => {
  const env = environment(); const result = env.window.mytripReceipt.open();
  await env.element('#receipt-start').onclick();
  env.element('video').videoWidth = 200; env.element('video').videoHeight = 100;
  env.element('video').onresize();
  assert.equal(env.element('.frame').style.aspectRatio, '200 / 100');
  assert.equal(env.element('.guide').style.inset, '12% 6%');
  env.window.mytripReceipt.close(); assert.equal(await result, null);
});
test('right swipe closes the receipt camera, while short, left and vertical drags do not', async () => {
  const env = environment(); const result = env.window.mytripReceipt.open();
  await env.element('#receipt-start').onclick();
  const down = env.callbacks.get('pointerdown'), up = env.callbacks.get('pointerup');
  for (const [dx, dy] of [[40, 0], [-180, 0], [180, 200]]) {
    down({ pointerId: 1, isPrimary: true, clientX: 30, clientY: 200 });
    up({ pointerId: 1, clientX: 30 + dx, clientY: 200 + dy });
    assert.equal(env.dialog.removed, undefined);
  }
  down({ pointerId: 1, isPrimary: true, clientX: 30, clientY: 200 });
  up({ pointerId: 1, clientX: 230, clientY: 210 });
  assert.equal(await result, null); assert.equal(env.counters().stopCount, 1);
});
test('receipt UI uses bundled app fonts and keeps language settings out of capture-only controls', async () => {
  for (const llm of [false, true]) {
    const env = environment({ llm }); const result = env.window.mytripReceipt.open();
    assert.equal((env.dialog.innerHTML.match(/id="receipt-language"/g) ?? []).length, llm ? 0 : 1);
    assert.match(env.dialog.innerHTML, /https:\/\/test\.invalid\/mytrip\/assets\/assets\/fonts\/Pretendard-Regular\.otf/);
    assert.doesNotMatch(env.dialog.innerHTML, /JPEG|정사각형|写真/);
    const primary = env.dialog.innerHTML.split('id="receipt-recognition"')[1];
    assert.equal(primary.includes('id="receipt-language"'), !llm);
    env.window.mytripReceipt.close(); assert.equal(await result, null);
  }
});
test('permission is lazy, denial explains site permissions and manual fallback', async () => {
  const env = environment({ cameraError: { name: 'NotAllowedError' } });
  const result = env.window.mytripReceipt.open();
  assert.equal(env.counters().cameraCalls, 0);
  await env.element('#receipt-start').onclick();
  assert.match(env.element('.error').textContent, /권한.*거부/);
  assert.match(env.element('.error').textContent, /수동 입력/);
  env.element('#receipt-close').onclick(); assert.equal(await result, null);
});
test('missing camera and unsupported HTTP explain alternatives without requesting permissions', async () => {
  for (const options of [{ noCamera: true }, { secure: false }]) {
    const env = environment(options); const result = env.window.mytripReceipt.open();
    await env.element('#receipt-start').onclick();
    assert.equal(env.counters().cameraCalls, 0); assert.match(env.element('.error').textContent, /HTTPS/);
    env.window.mytripReceipt.close(); assert.equal(await result, null);
  }
  const env = environment({ cameraError: { name: 'NotFoundError' } });
  const result = env.window.mytripReceipt.open(); await env.element('#receipt-start').onclick();
  assert.match(env.element('.error').textContent, /카메라가 없/);
  env.window.mytripReceipt.close(); assert.equal(await result, null);
});
test('capture stops tracks, retake opens again, close and Escape release stream', async () => {
  const env = environment(); const { result } = await captured(env);
  assert.equal(env.counters().stopCount, 1); assert.equal(env.element('img').hidden, false);
  await env.element('#receipt-retake').onclick(); assert.equal(env.counters().cameraCalls, 2);
  env.callbacks.get('cancel')({ preventDefault() {} });
  assert.equal(await result, null); assert.equal(env.counters().stopCount, 2);
});
test('leaving during delayed permission resolution stops the late camera', async () => {
  const pending = deferred(); const env = environment({ mediaPromise: pending.promise });
  const result = env.window.mytripReceipt.open(); const starting = env.element('#receipt-start').onclick();
  env.window.mytripReceipt.close(); pending.resolve(env.stream); await starting;
  assert.equal(await result, null); assert.equal(env.counters().stopCount, 1);
});
test('backgrounding releases camera; pagehide cancels the workflow', async () => {
  const env = environment(); const result = env.window.mytripReceipt.open();
  await env.element('#receipt-start').onclick(); env.document.hidden = true;
  env.callbacks.get('visibilitychange')(); assert.equal(env.counters().stopCount, 1);
  assert.equal(env.element('#receipt-start').hidden, false);
  env.callbacks.get('pagehide')(); assert.equal(await result, null);
});
test('OCR network failure preserves photo, supports retry and manual close, assets are same-origin', async () => {
  const env = environment({ workerError: new Error('network') }); const { result } = await captured(env);
  const image = env.element('img').src; await env.element('#receipt-ocr').onclick();
  assert.equal(env.element('img').src, image); assert.match(env.element('.error').textContent, /다시 촬영|재시도/);
  assert.equal(env.element('#receipt-ocr').textContent, '인식 재시도');
  for (const path of ['workerPath', 'corePath', 'langPath']) assert.match(env.options()[path], /^https:\/\/test\.invalid\/mytrip\/ocr\//);
  env.window.mytripReceipt.close(); assert.equal(await result, null);
});
test('actual empty OCR output is not a successful receipt', async () => {
  const env = environment(); env.worker.recognize = async () => ({ data: { text: '  ' } });
  const { result } = await captured(env); await env.element('#receipt-ocr').onclick();
  assert.match(env.element('.error').textContent, /인식하지 못/);
  env.window.mytripReceipt.close(); assert.equal(await result, null);
});
test('timeout invalidates late worker initialization; no leaked worker and retry stays available', async () => {
  const pending = deferred(); const env = environment({ workerPromise: pending.promise });
  const { result } = await captured(env); const running = env.element('#receipt-ocr').onclick();
  await Promise.resolve(); env.timers.get(1)(); await running;
  assert.match(env.element('.error').textContent, /시간이 초과/);
  pending.resolve(env.worker); await new Promise(r => setImmediate(r));
  assert.equal(env.counters().terminateCount, 1);
  env.window.mytripReceipt.close(); assert.equal(await result, null);
});
test('close during OCR initialization cleans up the late worker', async () => {
  const pending = deferred(); const env = environment({ workerPromise: pending.promise });
  const { result } = await captured(env); const running = env.element('#receipt-ocr').onclick();
  env.window.mytripReceipt.close(); pending.resolve(env.worker); await running;
  assert.equal(await result, null); assert.equal(env.counters().terminateCount, 1);
});

test('local and public LLM modes only return the photo to Flutter, without uploads or OCR', async () => {
  for (const llm of [true, false]) {
    let calls = 0;
    const env = environment({ llm, fetchReceipt: async () => { calls++; throw new Error('must not upload before Flutter consent'); } });
    const result = env.window.mytripReceipt.open(true);
    await env.element('#receipt-start').onclick(); env.element('#receipt-shot').onclick();
    assert.match(env.dialog.innerHTML, /사진 사용/);
    env.element('#receipt-ocr').onclick(); env.element('#receipt-ocr').onclick();
    assert.deepEqual(JSON.parse(await result), { image: 'data:image/jpeg;base64,dGVzdA==' });
    assert.equal(calls, 0); assert.equal(env.options(), undefined);
  }
});

test('local runtime exposes only the endpoint and CSRF value, not OpenAI credentials', () => {
  const env = environment({ llm: true });
  assert.deepEqual(JSON.parse(env.window.mytripReceipt.connection()), { url: 'https://test.invalid/receipt/recognize', csrf: 'test-csrf' });
  assert.equal(environment().window.mytripReceipt.connection(), null);
});

test('cancelling the LLM photo workflow sends no photo and releases the camera', async () => {
  const env = environment({ llm: true }); const { result } = await captured(env);
  env.window.mytripReceipt.close();
  assert.equal(await result, null); assert.equal(env.counters().stopCount, 1); assert.equal(env.options(), undefined);
});
