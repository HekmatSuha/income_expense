(function () {
  const cdnBase = 'https://cdn.jsdelivr.net/npm/sql.js@1.9.0/dist/';

  function wrapInitSqlJs(original) {
    function locateFile(file) {
      return cdnBase + file;
    }

    function wrapped(config) {
      if (config && typeof config === 'object') {
        const finalConfig = Object.assign({ locateFile }, config);
        return original(finalConfig);
      }

      return original({ locateFile });
    }

    wrapped.__driftWrapped = true;
    return wrapped;
  }

  function ensureSqlJsConfigured() {
    if (typeof window === 'undefined') {
      return;
    }

    const currentInit = window.initSqlJs;

    if (typeof currentInit !== 'function') {
      console.error('sql.js is not available on window.initSqlJs.');
      return;
    }

    if (currentInit.__driftWrapped) {
      return;
    }

    window.initSqlJs = wrapInitSqlJs(currentInit);
  }

  if (document.readyState === 'loading') {
    window.addEventListener('DOMContentLoaded', ensureSqlJsConfigured, {
      once: true,
    });
    window.addEventListener('load', ensureSqlJsConfigured, { once: true });
  } else {
    ensureSqlJsConfigured();
  }
})();
