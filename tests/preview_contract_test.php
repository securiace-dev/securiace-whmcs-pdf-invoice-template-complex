<?php

declare(strict_types=1);

$previewDirectory = __DIR__ . '/../preview';
$html = file_get_contents($previewDirectory . '/index.html');
$css = file_get_contents($previewDirectory . '/styles.css');
$javascript = file_get_contents($previewDirectory . '/app.js');

if ($html === false || $css === false || $javascript === false) {
    throw new RuntimeException('Unable to read the browser preview files.');
}

$requiredHtml = array(
    'href="#invoice-document"',
    'id="invoice-document" tabindex="-1"',
    'data-state-button="paid"',
    'data-state-button="unpaid"',
    'data-state-button="overdue"',
    'data-paid-only',
    'data-outstanding-only',
    '<table class="transaction-table"',
    '<th scope="col">Date</th>',
    'Authenticated invoice record',
    'Electronic record · IT Act 2000',
    'width="62" height="62"',
);

foreach ($requiredHtml as $required) {
    if (strpos($html, $required) === false) {
        throw new RuntimeException('Preview contract is missing: ' . $required);
    }
}

$forbiddenClaims = array('Digitally verified', 'IT Act 2000 compliant');
foreach ($forbiddenClaims as $forbidden) {
    if (stripos($html, $forbidden) !== false) {
        throw new RuntimeException('Preview contains an unsupported claim: ' . $forbidden);
    }
}

$requiredCss = array(
    '.skip-link:focus-visible',
    '.state-switch button:focus-visible',
    '.print-button:hover',
    'font-variant-numeric: tabular-nums',
    'html[data-invoice-state="overdue"] .status-pill',
    '@media print',
    '@media (prefers-reduced-motion: reduce)',
);
foreach ($requiredCss as $required) {
    if (strpos($css, $required) === false) {
        throw new RuntimeException('Preview stylesheet contract is missing: ' . $required);
    }
}

$requiredJavascript = array(
    'aria-pressed',
    'url.searchParams.set("state", normalizedState)',
    'window.history.replaceState',
    'window.print()',
);
foreach ($requiredJavascript as $required) {
    if (strpos($javascript, $required) === false) {
        throw new RuntimeException('Preview interaction contract is missing: ' . $required);
    }
}

fwrite(STDOUT, "Invoice browser preview contract tests passed.\n");
