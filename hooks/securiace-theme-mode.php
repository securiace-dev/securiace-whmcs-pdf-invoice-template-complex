<?php

/**
 * Securiace theme mode assets for the securiace child theme.
 * Install to: WHMCS_ROOT/includes/hooks/securiace-theme-mode.php
 */

if (!defined('WHMCS')) {
    return;
}

add_hook('ClientAreaHeadOutput', 1, function () {
    $early = <<<'HTML'
<script>
(function () {
  try {
    var stored = localStorage.getItem('securiace-theme-mode');
    var mode = stored || ((window.matchMedia && window.matchMedia('(prefers-color-scheme: light)').matches) ? 'light' : 'dark');
    if (mode !== 'light' && mode !== 'dark') { mode = 'dark'; }
    document.documentElement.setAttribute('data-theme', mode);
    document.documentElement.style.colorScheme = mode;
  } catch (e) {
    document.documentElement.setAttribute('data-theme', 'dark');
  }
})();
</script>
HTML;
    return $early;
});

add_hook('ClientAreaFooterOutput', 1, function () {
    $theme = defined('ROOTDIR') ? ROOTDIR . '/templates/securiace/js/custom.js' : '';
    if ($theme === '' || !is_readable($theme)) {
        return '';
    }
    $version = (string) @filemtime($theme);
    return '<script src="templates/securiace/js/custom.js?v=' . htmlspecialchars($version, ENT_QUOTES, 'UTF-8') . '" defer></script>';
});
