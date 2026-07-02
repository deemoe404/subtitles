(function () {
  function currentLanguage() {
    try {
      var params = new URLSearchParams(window.location.search);
      return params.get('lang') || localStorage.getItem('lang') || '';
    } catch (_) {
      return '';
    }
  }

  function homeSlug() {
    try {
      if (typeof window.__press_get_home_slug === 'function') {
        return window.__press_get_home_slug() || 'home';
      }
    } catch (_) {}
    return 'home';
  }

  function updateHomeLinks() {
    try {
      var lang = currentLanguage();
      var href = '?tab=' + encodeURIComponent(homeSlug());
      if (lang) href += '&lang=' + encodeURIComponent(lang);
      document.querySelectorAll('[data-site-home]').forEach(function (link) {
        link.setAttribute('href', href);
      });
    } catch (_) {}
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', updateHomeLinks, { once: true });
  } else {
    updateHomeLinks();
  }

  window.addEventListener('popstate', updateHomeLinks);
  window.addEventListener('ns:i18n-bundle-loaded', updateHomeLinks);

  try {
    new MutationObserver(updateHomeLinks).observe(document.documentElement, {
      childList: true,
      subtree: true
    });
  } catch (_) {}
})();
