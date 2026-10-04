/* Receipt pixels stay in browser memory. All OCR assets are same-origin. */
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
      dialog.innerHTML = `<style>
        .receipt-dialog{box-sizing:border-box;width:min(100%,440px);height:100dvh;max-width:100%;max-height:100%;margin:0 auto;padding:20px;border:0;background:#f7f8fa;color:#16181d;font:15px Pretendard,Arial,sans-serif;overflow:auto}
        .receipt-dialog::backdrop{background:#e7eaf0}.receipt-dialog h1{font-size:20px}.receipt-dialog button,.receipt-dialog select{font:inherit;min-height:48px;border-radius:12px;padding:10px 14px;border:1px solid #e5e7eb;background:white;cursor:pointer}.receipt-dialog button:focus-visible{outline:3px solid #2f6fed;outline-offset:2px}.receipt-dialog .primary{background:#2f6fed;color:white;border:0}.receipt-dialog button:disabled{opacity:.5;cursor:default}.receipt-dialog header{display:flex;align-items:center;justify-content:space-between}.receipt-dialog .actions{display:flex;flex-wrap:wrap;gap:8px;margin:16px 0}.receipt-dialog .actions button{flex:1}.receipt-dialog .frame{position:relative;width:min(100%,40dvh);height:auto;aspect-ratio:2/3;min-height:0;max-height:60dvh;margin:0 auto;background:#16181d;border-radius:16px;overflow:hidden}.receipt-dialog video,.receipt-dialog img{width:100%;height:100%;object-fit:contain}.receipt-dialog .guide{position:absolute;inset:6% 12%;border:2px dashed white;border-radius:8px;pointer-events:none}.receipt-dialog .note{font-size:13px;line-height:1.6;color:#6b7280}.receipt-dialog [hidden]{display:none!important}.receipt-dialog .error{color:#d03434;line-height:1.6}.receipt-dialog input[type=file]{max-width:100%;min-height:48px}.receipt-dialog progress{width:100%}
        </style>
        <header><h1>영수증 촬영</h1><button type="button" id="receipt-close" aria-label="촬영 닫고 수동 입력으로 돌아가기">닫기</button></header>
        <p class="note">카메라는 시작 버튼을 누를 때만 권한을 요청해요. 사진과 인식 내용은 이 브라우저에서만 처리하며 외부 OCR 서비스로 보내지 않아요. 사진은 저장하지 않고 화면을 닫으면 버려요.</p>
        <p class="note">세로로 긴 영수증 전체를 직사각형 가이드 안에 넣어주세요. 밝은 곳에서 평평하게 펼치고 그림자·반사 없이 흔들리지 않게 촬영해요. 원본 비율을 유지하며 정사각형으로 자르지 않아요.</p>
        <div class="frame" hidden><video playsinline muted aria-label="후면 카메라 미리보기"></video><img hidden alt="촬영한 영수증 원본"><div class="guide" hidden></div></div>
        <p id="receipt-status" role="status" aria-live="polite"></p><p class="error" role="alert"></p>
        <div class="actions"><button class="primary" id="receipt-start">카메라 시작</button><button id="receipt-shot" hidden>촬영</button><button id="receipt-retake" hidden>재촬영</button></div>
        <label for="receipt-file">카메라 대신 사진 선택 (JPEG·PNG·WebP, 8MB 이하)</label><input id="receipt-file" type="file" accept="image/jpeg,image/png,image/webp">
        <div id="receipt-recognition" hidden><p><label for="receipt-language">영수증 언어 </label><select id="receipt-language"><option value="eng+kor">한국어 + English</option><option value="eng+jpn">日本語 + English</option><option value="eng">English</option></select></p>
        <progress hidden max="1" value="0" aria-label="실제 OCR 인식 진행률"></progress><div class="actions"><button class="primary" id="receipt-ocr">이 사진으로 인식</button></div></div>
        <p class="note">인식 결과는 직접 확인·수정한 뒤 저장해요. 초점·화질 자동 검사는 하지 않아요.</p>`;
      document.body.append(dialog);
      const $ = (selector) => dialog.querySelector(selector);
      const video = $('video'), image = $('img'), status = $('#receipt-status'), error = $('.error');
      let stream, worker, pixels, closed = false, busy = false, generation = 0;
      const cleanupCamera = () => { stop(stream); stream = undefined; video.srcObject = null; };
      const setBusy = (value) => {
        busy = value;
        for (const button of dialog.querySelectorAll('button:not(#receipt-close),input,select')) button.disabled = value;
      };
      const finish = (value) => {
        if (closed) return;
        closed = true;
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
      const preview = (data) => {
        cleanupCamera(); pixels = data; image.src = data; image.hidden = false;
        video.hidden = true; $('.frame').hidden = false; $('.guide').hidden = true;
        $('#receipt-shot').hidden = true; $('#receipt-start').hidden = true;
        $('#receipt-retake').hidden = false; $('#receipt-recognition').hidden = false;
        status.textContent = '写真 / 사진을 확인해주세요. 잘리지 않았는지 직접 확인한 뒤 인식하세요.';
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
          $('#receipt-start').hidden = true; $('#receipt-retake').hidden = true;
          await video.play(); status.textContent = '영수증 전체가 보이면 촬영해주세요.';
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
      $('#receipt-shot').onclick = () => {
        try { preview(encode(video, video.videoWidth, video.videoHeight)); }
        catch { error.textContent = '촬영 준비가 끝나지 않았어요. 잠시 후 다시 촬영해주세요.'; }
      };
      $('#receipt-file').onchange = async (event) => {
        const file = event.target.files?.[0];
        if (!file) return;
        if (file.size > 8 * 1024 * 1024 || !['image/jpeg', 'image/png', 'image/webp'].includes(file.type)) {
          error.textContent = 'JPEG·PNG·WebP 사진을 8MB 이하로 선택해주세요.'; event.target.value = ''; return;
        }
        setBusy(true); error.textContent = '';
        const url = URL.createObjectURL(file);
        try {
          const source = new Image(); source.src = url; await source.decode();
          if (!closed) preview(encode(source, source.naturalWidth, source.naturalHeight));
        } catch { if (!closed) error.textContent = '사진을 열지 못했어요. 다른 사진을 선택하거나 수동으로 입력해주세요.'; }
        finally { URL.revokeObjectURL(url); if (!closed) setBusy(false); }
      };
      $('#receipt-ocr').onclick = async () => {
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
              '영수증을 인식하지 못했어요. 사진을 다시 촬영하거나 인식을 재시도할 수 있어요. 닫으면 기존 입력으로 돌아가요.';
            status.textContent = ''; $('#receipt-ocr').textContent = '인식 재시도';
          }
        } finally { clearTimeout(timer); if (!closed) { setBusy(false); $('progress').hidden = true; } }
      };
      dialog.showModal(); $('#receipt-start').focus();
    }),
  };
})();
