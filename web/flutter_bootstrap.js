{{flutter_js}}
{{flutter_build_config}}

// GitHub Pages caches static files for ten minutes; don't mix two app releases.
for (const build of _flutter.buildConfig.builds) {
  if (build.mainJsPath) build.mainJsPath += '?v={{flutter_service_worker_version}}';
}
_flutter.loader.load();
