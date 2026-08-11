(function () {
  'use strict';

  var STORAGE_KEY = 'securiace-theme-mode';
  var root = document.documentElement;

  function systemMode() {
    if (window.matchMedia && window.matchMedia('(prefers-color-scheme: light)').matches) {
      return 'light';
    }
    return 'dark';
  }

  function storedMode() {
    try {
      return window.localStorage.getItem(STORAGE_KEY) || '';
    } catch (err) {
      return '';
    }
  }

  function persistMode(mode, forced) {
    try {
      if (forced) {
        window.localStorage.setItem(STORAGE_KEY, mode);
      } else {
        window.localStorage.removeItem(STORAGE_KEY);
      }
    } catch (err) {
      /* ignore */
    }
  }

  function applyMode(mode) {
    var next = mode === 'light' ? 'light' : 'dark';
    root.setAttribute('data-theme', next);
    root.style.colorScheme = next;
    var toggle = document.getElementById('securiace-theme-toggle');
    if (toggle) {
      toggle.setAttribute('aria-pressed', next === 'dark' ? 'true' : 'false');
      toggle.setAttribute('data-mode', next);
      var label = toggle.querySelector('[data-mode-label]');
      if (label) {
        label.textContent = next === 'dark' ? 'Dark' : 'Light';
      }
    }
  }

  function resolveInitial() {
    var stored = storedMode();
    if (stored === 'light' || stored === 'dark') {
      return { mode: stored, forced: true };
    }
    return { mode: systemMode(), forced: false };
  }

  applyMode(resolveInitial().mode);

  function onToggleClick(event) {
    event.preventDefault();
    var current = root.getAttribute('data-theme') === 'light' ? 'light' : 'dark';
    var next = current === 'dark' ? 'light' : 'dark';
    applyMode(next);
    persistMode(next, true);
  }

  function ensureToggle() {
    if (document.getElementById('securiace-theme-toggle')) {
      return document.getElementById('securiace-theme-toggle');
    }
    var host =
      document.querySelector('.navbar-right') ||
      document.querySelector('#main-menu') ||
      document.querySelector('.navbar') ||
      document.body;
    if (!host) {
      return null;
    }
    var btn = document.createElement('button');
    btn.type = 'button';
    btn.id = 'securiace-theme-toggle';
    btn.className = 'securiace-theme-toggle';
    btn.setAttribute('aria-label', 'Toggle color mode');
    btn.innerHTML =
      '<span class="securiace-theme-toggle__icon" aria-hidden="true"></span>' +
      '<span data-mode-label>Dark</span>';
    host.appendChild(btn);
    return btn;
  }

  function bindToggle() {
    var toggle = ensureToggle();
    if (toggle && !toggle.getAttribute('data-bound')) {
      toggle.setAttribute('data-bound', '1');
      toggle.addEventListener('click', onToggleClick);
      applyMode(root.getAttribute('data-theme') || 'dark');
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', bindToggle);
  } else {
    bindToggle();
  }

  if (window.matchMedia) {
    var media = window.matchMedia('(prefers-color-scheme: light)');
    var onChange = function () {
      if (!storedMode()) {
        applyMode(systemMode());
      }
    };
    if (typeof media.addEventListener === 'function') {
      media.addEventListener('change', onChange);
    } else if (typeof media.addListener === 'function') {
      media.addListener(onChange);
    }
  }
})();
