<?php

declare(strict_types=1);

$previewDirectory = __DIR__ . '/../quote-preview';
$html = file_get_contents($previewDirectory . '/index.html');
$css = file_get_contents($previewDirectory . '/styles.css');
$javascript = file_get_contents($previewDirectory . '/app.js');
if ($html === false || $css === false || $javascript === false) {
    throw new RuntimeException('Unable to read quote preview files.');
}

$requiredHtml = array(
    'href="#quote-document"',
    'id="quote-document" tabindex="-1"',
    'Commercial proposal',
    'Valid until 19 Aug 2026',
    'Proposal summary',
    'Prepared for',
    'Prepared by',
    'class="issuer-registrations"',
    'Email · accounts@example.invalid',
    'class="item-detail-row"',
    'colspan="5"',
    '<th scope="col" class="numeric">Qty</th>',
    '<th scope="col" class="numeric">Unit price</th>',
    '<th scope="col" class="numeric">Discount</th>',
    'Validity and acceptance',
    'class="verification-panel"',
    'Sealed quote',
    '01AR-Z3ND-EKTS-V4RR-FFQ6-9G5F-AV',
    'does not extend or confirm the quote’s current validity.',
);
foreach ($requiredHtml as $required) {
    if (strpos($html, $required) === false) {
        throw new RuntimeException('Quote preview contract is missing: ' . $required);
    }
}

foreach (array('UPI payment', 'Payment transactions', 'Amount paid', 'Authenticated invoice record', 'Client notes') as $invoiceOnlyText) {
    if (stripos($html, $invoiceOnlyText) !== false) {
        throw new RuntimeException('Quote preview contains invoice-only content: ' . $invoiceOnlyText);
    }
}
foreach (array('Adobe', 'green tick') as $unsupportedClaim) {
    if (stripos($html, $unsupportedClaim) !== false) {
        throw new RuntimeException('Quote preview contains unsupported seal copy: ' . $unsupportedClaim);
    }
}

foreach (array('@import url("../preview/styles.css")', '.validity-pill', '.proposal-copy', '.issuer-registrations', '.item-detail-row', '.quote-financial', '@media print') as $required) {
    if (strpos($css, $required) === false) {
        throw new RuntimeException('Quote preview stylesheet contract is missing: ' . $required);
    }
}
foreach (array('window.print()', 'beforeprint', 'afterprint', 'aria-busy') as $required) {
    if (strpos($javascript, $required) === false) {
        throw new RuntimeException('Quote preview interaction contract is missing: ' . $required);
    }
}

fwrite(STDOUT, "Quote browser preview contract tests passed.\n");
