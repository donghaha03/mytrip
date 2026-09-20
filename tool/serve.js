// build/web 를 그냥 띄워 보기 위한 최소 정적 서버.
// 앱 코드와는 무관하고, `flutter build web` 결과를 브라우저에서 확인할 때만 쓴다.
//   node tool/serve.js   ->  http://localhost:8099
const http = require('http');
const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..', 'build', 'web');
const PORT = 8099;

const TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.otf': 'font/otf',
  '.ttf': 'font/ttf',
  '.woff2': 'font/woff2',
  '.wasm': 'application/wasm',
  '.bin': 'application/octet-stream',
  '.symbols': 'text/plain; charset=utf-8',
};

http
  .createServer((req, res) => {
    const urlPath = decodeURIComponent(req.url.split('?')[0]);
    let filePath = path.join(ROOT, urlPath === '/' ? 'index.html' : urlPath);

    // 디렉터리 밖으로 나가는 경로 차단
    if (!filePath.startsWith(ROOT)) {
      res.writeHead(403).end('forbidden');
      return;
    }
    if (!fs.existsSync(filePath) || fs.statSync(filePath).isDirectory()) {
      filePath = path.join(ROOT, 'index.html');
    }

    res.writeHead(200, {
      'Content-Type': TYPES[path.extname(filePath)] || 'application/octet-stream',
      'Cache-Control': 'no-store',
      // CanvasKit / wasm 로딩에 필요
      'Cross-Origin-Opener-Policy': 'same-origin',
      'Cross-Origin-Embedder-Policy': 'require-corp',
    });
    fs.createReadStream(filePath).pipe(res);
  })
  .listen(PORT, () => console.log(`serving build/web on http://localhost:${PORT}`));
