{{flutter_js}}
{{flutter_build_config}}

// GitHub Pages caches static files for ten minutes; don't mix two app releases.
const appVersion = {{flutter_service_worker_version}};
for (const build of _flutter.buildConfig.builds) {
  if (build.mainJsPath) build.mainJsPath += '?v=' + appVersion;
}
const receiptScript = document.createElement('script');
receiptScript.src = 'receipt.js?v=' + appVersion;
receiptScript.onload = receiptScript.onerror = () => _flutter.loader.load();
document.head.appendChild(receiptScript);
