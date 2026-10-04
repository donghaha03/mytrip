/* Device OCR stays local. The optional local runtime sends images to OpenAI. */
(() => {
  let active;
  const base = new URL('ocr/', document.baseURI);
  const message = (error) => ({
    NotAllowedError: '카메라 권한이 거부되었어요. 브라우저 주소창의 사이트 권한에서 카메라를 허용하거나 사진 선택·수동 입력을 이용해주세요.',
    NotFoundError: '사용할 수 있는 카메라가 없어요. 사진 선택 또는 수동 입력을 이용해주세요.',
    NotReadableError: '다른 앱이 카메라를 사용 중일 수 있어요. 다른 앱을 닫고 다시 시도해주세요.',
    SecurityError: '이 환경에서는 카메라를 사용할 수 없어요. HTTPS 주소에서 열어주세요.',
  })[error?.name] ?? '처리하지 못했어요. 연결을 확인하고 다시 시도하거나 수동으로 입력해주세요.';
  const stop = (stream) => stream?.getTracks().forEach((track) => track.stop());
  const supportsCamera = () => !!navigator.mediaDevices?.getUserMedia && window.isSecureContext;
  window.mytripReceipt = {
    close: () => active?.finish(null),
    open: () => new Promise((resolve, reject) => {
      if (active) { reject(new Error('이미 영수증 촬영 화면이 열려 있어요')); return; }
      const previousFocus = document.activeElement;
      const dialog = document.createElement('dialog');
      dialog.className = 'receipt-dialog';
      dialog.setAttribute('aria-label', '영수증 촬영');
      const language = `<p class="language"><label for="receipt-language">인식 언어</label><select id="receipt-language"><option value="eng+kor">한국어·영어</option><option value="eng+jpn">일본어·영어</option><option value="eng">영어</option></select></p>`;
      dialog.innerHTML = `<style>
        ${[400, 500, 600, 700].map((weight, i) => `@font-face{font-family:Pretendard;font-style:normal;font-weight:${weight};font-display:swap;src:url("${new URL(`assets/assets/fonts/Pretendard-${['Regular', 'Medium', 'SemiBold', 'Bold'][i]}.otf`, document.baseURI).href}") format("opentype")}`).join('\n')}
        .receipt-dialog{box-sizing:border-box;width:min(100%,440px);height:100dvh;max-width:100%;max-height:100%;margin:0 auto;padding:0 20px 20px;border:0;background:#f7f8fa;color:#16181d;font:15px Pretendard,Arial,sans-serif;overflow:auto}
        .receipt-dialog::backdrop{background:#e7eaf0}.receipt-dialog h1{font-size:20px;margin:0;font-weight:700}.receipt-dialog button,.receipt-dialog select{font:inherit;min-height:48px;border-radius:12px;padding:10px 14px;border:1px solid #e5e7eb;background:white;cursor:pointer}.receipt-dialog button:focus-visible,.receipt-dialog select:focus-visible{outline:3px solid #2f6fed;outline-offset:2px}.receipt-dialog .primary{background:#2f6fed;color:white;border:0}.receipt-dialog button:disabled{opacity:.5;cursor:default}.receipt-dialog header{position:sticky;top:0;z-index:1;display:flex;align-items:center;gap:4px;margin:0 -8px;padding:8px 0 12px;background:#f7f8fa}.receipt-dialog #receipt-close{display:grid;place-items:center;min-width:48px;padding:12px;background:transparent;border:0}.receipt-dialog .actions{display:flex;flex-wrap:wrap;gap:8px;margin:16px 0}.receipt-dialog .actions button{flex:1}.receipt-dialog .frame{position:relative;margin:0 auto;border-radius:16px;overflow:hidden}.receipt-dialog video,.receipt-dialog img{display:block;width:100%;height:100%;object-fit:contain}.receipt-dialog .guide{position:absolute;inset:6% 12%;border:2px dashed white;border-radius:8px;pointer-events:none;box-shadow:0 0 0 1000px #0002}.receipt-dialog .note{font-size:13px;line-height:1.6;color:#6b7280}.receipt-dialog [hidden]{display:none!important}.receipt-dialog .error{color:#d03434;line-height:1.6}.receipt-dialog progress{width:100%}.receipt-dialog .language{display:flex;align-items:center;justify-content:space-between;gap:12px}.receipt-dialog #receipt-status:empty,.receipt-dialog .error:empty{display:none}
        </style>
        <style>.receipt-dialog button{font-size:14px;font-weight:600}.receipt-dialog summary{min-height:44px;display:flex;align-items:center;cursor:pointer;color:#2f6fed}.receipt-dialog a{color:#2f6fed;font-size:14px}</style>
        <header><button type="button" id="receipt-close" aria-label="뒤로가기"><svg width="24" height="24" viewBox="0 0 24 24" aria-hidden="true"><path d="m12 4-8 8 8 8M4 12h16" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg></button><h1>영수증 촬영</h1></header>
        <p class="note">밝은 곳에서 영수증을 펼쳐, 전체가 보이게 촬영해주세요.</p>
        <div class="frame" hidden><video playsinline muted aria-label="후면 카메라 미리보기"></video><img hidden alt="촬영한 영수증 원본"><div class="guide" hidden></div></div>
        <p id="receipt-status" role="status" aria-live="polite"></p><p class="error" role="alert"></p>
        <div class="actions"><button class="primary" id="receipt-start">카메라 시작</button><button class="primary" id="receipt-shot" hidden>촬영</button><button id="receipt-retake" hidden>재촬영</button><button id="receipt-choose">사진 선택</button></div>
        <input id="receipt-file" hidden type="file" accept="image/jpeg,image/png,image/webp" aria-label="영수증 사진">
        <div id="receipt-recognition" hidden>${window.mytripReceiptLLM ? '' : language}
        <progress hidden max="1" value="0" aria-label="영수증 인식 진행률"></progress><div class="actions"><button class="primary" id="receipt-ocr">이 사진으로 인식</button></div></div>
        <div id="receipt-llm" hidden><p class="note">사진을 OpenAI로 보내 인식해요. 검토 후에만 적용됩니다.</p><p><a href="/receipt-connect" target="_blank" rel="noopener">ChatGPT 연결 관리</a></p><details><summary>기기에서 인식</summary>${window.mytripReceiptLLM ? language : ''}<div class="actions"><button id="receipt-ai">기기에서 인식</button></div><p class="note">사진은 기기에서만 처리해요.</p></details></div>
        ${window.mytripReceiptLLM ? '' : '<p class="note">사진은 기기에서만 인식해요.</p>'}`;
      document.body.append(dialog);
      const $ = (selector) => dialog.querySelector(selector);
      const video = $('video'), image = $('img'), status = $('#receipt-status'), error = $('.error');
      let stream, worker, pixels, controller, closed = false, busy = false, generation = 0;
      const cleanupCamera = () => { stop(stream); stream = undefined; video.srcObject = null; };
      const setBusy = (value) => {
        busy = value;
        for (const button of dialog.querySelectorAll('button:not(#receipt-close),input,select')) button.disabled = value;
      };
      const finish = (value) => {
        if (closed) return;
        closed = true;
        generation++; controller?.abort();
        cleanupCamera();
        worker?.terminate();
        window.removeEventListener('pagehide', onHide);
        document.removeEventListener('visibilitychange', onVisibility);
        dialog.close(); dialog.remove(); active = undefined;
        previousFocus?.focus(); resolve(value === null ? null : JSON.stringify(value));
      };
      const onHide = () => finish(null);
      const onVisibility = () => {
        if (document.hidden && stream) {
          cleanupCamera(); $('#receipt-shot').hidden = true; $('#receipt-start').hidden = false;
          status.textContent = '카메라를 멈췄어요. 돌아오면 카메라 시작을 눌러주세요.';
        }
      };
      active = { finish };
      window.addEventListener('pagehide', onHide);
      document.addEventListener('visibilitychange', onVisibility);
      dialog.addEventListener('cancel', (event) => { event.preventDefault(); finish(null); });
      $('#receipt-close').onclick = () => finish(null);
      let swipeStart;
      dialog.addEventListener('pointerdown', (event) => {
        swipeStart = event.isPrimary === false || event.target?.closest?.('input,select,textarea')
          ? undefined : { id: event.pointerId, x: event.clientX, y: event.clientY };
      });
      dialog.addEventListener('pointercancel', () => { swipeStart = undefined; });
      dialog.addEventListener('pointerup', (event) => {
        const start = swipeStart; swipeStart = undefined;
        if (!start || start.id !== event.pointerId) return;
        const dx = event.clientX - start.x, dy = event.clientY - start.y;
        if (dx >= 96 && Math.abs(dy) < dx / 2) finish(null);
      });
      const fitFrame = (width, height) => {
        if (!width || !height) return;
        $('.frame').style.aspectRatio = `${width} / ${height}`;
        $('.frame').style.width = `min(100%, ${56 * width / height}dvh)`;
        $('.guide').style.inset = width > height ? '12% 6%' : '6% 12%';
      };
      video.onresize = () => { if (stream) fitFrame(video.videoWidth, video.videoHeight); };
      const preview = (data, width, height) => {
        cleanupCamera(); pixels = data; image.src = data; image.hidden = false;
        fitFrame(width, height);
        video.hidden = true; $('.frame').hidden = false; $('.guide').hidden = true;
        $('#receipt-shot').hidden = true; $('#receipt-start').hidden = true;
        $('#receipt-retake').hidden = false; $('#receipt-recognition').hidden = false;
        $('#receipt-llm').hidden = !window.mytripReceiptLLM;
        status.textContent = '사진을 확인해주세요.';
      };
      const camera = async () => {
        if (busy) return;
        if (!supportsCamera()) { error.textContent = '이 환경은 앱 내 카메라를 지원하지 않아요. HTTPS 주소·최신 브라우저에서 열거나 사진 선택·수동 입력을 이용해주세요.'; return; }
        setBusy(true); error.textContent = ''; status.textContent = '카메라 권한과 연결을 기다리고 있어요…';
        cleanupCamera();
        try {
          const candidate = await navigator.mediaDevices.getUserMedia({ video: { facingMode: { ideal: 'environment' } }, audio: false });
          if (closed || document.hidden) { stop(candidate); return; }
          stream = candidate; video.srcObject = stream; video.hidden = false;
          image.hidden = true; $('.frame').hidden = false; $('.guide').hidden = false;
          $('#receipt-recognition').hidden = true; $('#receipt-shot').hidden = false;
          $('#receipt-llm').hidden = true;
          $('#receipt-start').hidden = true; $('#receipt-retake').hidden = true;
          await video.play(); fitFrame(video.videoWidth, video.videoHeight); status.textContent = '';
        } catch (e) { cleanupCamera(); if (!closed) { error.textContent = message(e); status.textContent = ''; $('#receipt-start').hidden = false; } }
        finally { if (!closed) setBusy(false); }
      };
      const encode = (source, width, height) => {
        if (width <= 0 || height <= 0 || width * height > 60_000_000) throw new Error('사진 크기를 확인해주세요');
        const scale = Math.min(1, 2000 / Math.max(width, height));
        const canvas = document.createElement('canvas');
        canvas.width = Math.round(width * scale); canvas.height = Math.round(height * scale);
        const context = canvas.getContext('2d'); context.fillStyle = '#fff'; context.fillRect(0, 0, canvas.width, canvas.height);
        context.drawImage(source, 0, 0, canvas.width, canvas.height);
        return canvas.toDataURL('image/jpeg', 0.95);
      };
      $('#receipt-start').onclick = camera; $('#receipt-retake').onclick = camera;
      $('#receipt-choose').onclick = () => $('#receipt-file').click();
      $('#receipt-shot').onclick = () => {
        try { preview(encode(video, video.videoWidth, video.videoHeight), video.videoWidth, video.videoHeight); }
        catch { error.textContent = '촬영 준비가 끝나지 않았어요. 잠시 후 다시 촬영해주세요.'; }
      };
      $('#receipt-file').onchange = async (event) => {
        const file = event.target.files?.[0];
        if (!file) return;
        if (file.size > 25 * 1024 * 1024 || !['image/jpeg', 'image/png', 'image/webp'].includes(file.type)) {
          error.textContent = '사진을 열 수 없어요. 다른 사진을 선택하거나 다시 촬영해주세요.'; event.target.value = ''; return;
        }
        setBusy(true); error.textContent = '';
        const url = URL.createObjectURL(file);
        try {
          const source = new Image(); source.src = url; await source.decode();
          if (!closed) preview(encode(source, source.naturalWidth, source.naturalHeight), source.naturalWidth, source.naturalHeight);
        } catch { if (!closed) error.textContent = '사진을 열지 못했어요. 다른 사진을 선택하거나 수동으로 입력해주세요.'; }
        finally { URL.revokeObjectURL(url); if (!closed) setBusy(false); }
      };
      const recognizeWithLLM = async () => {
        if (busy || !pixels || !window.mytripReceiptLLM) return;
        setBusy(true); error.textContent = ''; status.textContent = 'ChatGPT에서 영수증 사진을 읽고 있어요…';
        controller = new AbortController(); const current = controller;
        const attempt = ++generation;
        const timer = setTimeout(() => current.abort(), 90000);
        try {
          const response = await fetch('/receipt/recognize', {
            method: 'POST', signal: current.signal,
            headers: { 'Content-Type': 'application/json', 'X-mytrip-csrf': window.mytripReceiptLLM.csrf },
            body: JSON.stringify({ image: pixels }),
          });
          const result = await response.json();
          if (!response.ok) throw new Error(result.error || '인식하지 못했어요.');
          if (!result.draft || !Array.isArray(result.draft.items) || !Array.isArray(result.draft.warnings)) throw new Error('인식 결과가 올바르지 않아요.');
          if (!closed && attempt === generation) finish({ image: pixels, draft: result.draft });
        } catch (e) {
          if (!closed && attempt === generation) {
            error.textContent = e.name === 'AbortError' ? '인식 시간이 초과됐어요. 다시 시도하거나 수동으로 입력해주세요.' : e.message;
            status.textContent = ''; $('#receipt-ocr').textContent = '인식 재시도';
          }
        } finally { clearTimeout(timer); if (controller === current) controller = undefined; if (!closed) setBusy(false); }
      };
      const recognizeOnDevice = async () => {
        if (busy || !pixels) return;
        setBusy(true); error.textContent = ''; $('progress').hidden = false;
        let timer;
        const attempt = ++generation;
        try {
          const result = await Promise.race([
            (async () => {
              const candidate = await Tesseract.createWorker($('#receipt-language').value.split('+'), 1, {
                workerPath: new URL('worker.min.js', base).href,
                corePath: new URL('core/', base).href,
                langPath: new URL('lang', base).href, gzip: false, cacheMethod: 'none', workerBlobURL: false,
                logger: (m) => { if (!closed) { status.textContent = '기기에서 영수증을 인식하고 있어요…'; $('progress').value = m.progress ?? 0; } },
              });
              if (closed || attempt !== generation) { await candidate.terminate(); throw new Error('closed'); }
              worker = candidate;
              await worker.setParameters({ tessedit_pageseg_mode: '6', preserve_interword_spaces: '1' });
              const result = await worker.recognize(pixels);
              if (!result.data.text.trim()) throw new Error('empty');
              return result.data;
            })(),
            new Promise((_, rejectTimeout) => { timer = setTimeout(() => rejectTimeout(new Error('timeout')), 90000); }),
          ]);
          if (!closed) finish({ image: pixels, text: result.text, confidence: result.confidence });
        } catch (e) {
          generation++;
          worker?.terminate(); worker = undefined;
          if (!closed) {
            error.textContent = e.message === 'timeout' ? '인식 시간이 초과됐어요. 다시 시도하거나 수동으로 입력해주세요.' :
              '영수증을 인식하지 못했어요. 다시 촬영하거나 인식을 재시도해주세요.';
            status.textContent = ''; $(window.mytripReceiptLLM ? '#receipt-ai' : '#receipt-ocr').textContent = window.mytripReceiptLLM ? '기기 인식 재시도' : '인식 재시도';
          }
        } finally { clearTimeout(timer); if (!closed) { setBusy(false); $('progress').hidden = true; } }
      };
      $('#receipt-ocr').onclick = window.mytripReceiptLLM ? recognizeWithLLM : recognizeOnDevice;
      $('#receipt-ai').onclick = recognizeOnDevice;
      dialog.showModal(); $('#receipt-start').focus();
    }),
  };
})();
