<?php

declare(strict_types=1);

$templatePath = __DIR__ . '/../invoicepdf-modern.tpl';
$template = file_get_contents($templatePath);
if ($template === false) {
    throw new RuntimeException('Unable to read the modern invoice template.');
}

$requiredContracts = array(
    "\$securiaceModernBrand = array(79, 11, 112);",
    "\$securiaceModernPaper = array(255, 254, 253);",
    '$securiaceModernPaintPage',
    "method_exists(\$pdf, 'RoundedRect')",
    '$securiaceModernDrawItemsHeader',
    '$securiaceModernPreparedItems',
    '$securiaceModernSplitTextForHeight',
    'Payment status',
    'Paid in full',
    'No balance due',
    'Paid status needs review',
    'Reported balance',
    'WHMCS reports this invoice as Paid but retains a non-zero balance.',
    'Authorized signature',
    'Pay by bank transfer',
    'Payment instructions',
    "'support_email_valid'",
    'UPI payment',
    '$securiaceModernDrawTransactionHeading',
    'Transaction history',
    "in_array(\$securiaceModernStatusKey, array('unpaid', 'overdue'), true)",
    "'PI/' . \$securiaceModernInvoiceId",
    'Original proforma reference',
    'Overdue balance',
    'company_pan',
    'company_msme',
    "\$securiaceModernBatchScript === 'csvdownload.php'",
    "\$securiaceModernBatchRequestType === 'pdfbatch'",
    "__DIR__ . '/securiace-pdf-profile.php'",
    "'pay_to' => isset(\$companyaddress) ? \$companyaddress : array()",
    "\$securiaceModernCurrencyCode === 'INR'",
    '$securiaceModernRenderedBank',
    "'gst_registered' => false",
    "'gst_effective_date' => ''",
    "'commercial_invoice_currencies' => array()",
    '$securiaceModernGstActive',
    '$securiaceModernCommercialInvoiceActive',
    "'Commercial Invoice'",
    '$securiaceModernFinalNumberMaxLength = 16',
    "'/^[A-Za-z0-9\\/-]+$/'",
    '$securiaceModernNumberingDiagnostics',
    "'mod_securiace_pdf_issuer_snapshots'",
    "ROOTDIR . '/includes/securiace-pdf-snapshot.php'",
    '$securiaceModernSnapshotApplied',
    "'immutable.invoice'",
    "'protected-config-include-failed'",
    "'profile-helper-runtime-failed'",
    "'snapshot-validator-runtime-failed'",
    "'upi-qr-render-failed'",
    '$securiaceModernNormalizeIssuerProfile',
    '$securiaceModernIsTcpdfDeprecation',
    '$securiaceModernPreviousErrorHandler',
    'restore_error_handler()',
    '$securiaceModernHttpStatus >= 500',
    'A completed invoice page must not inherit',
    '$securiaceModernInitialHttpStatus >= 500',
    '$securiaceModernRenderErrorObserved === false',
    'Let\'s Seal line-safe footer reserve',
    '$securiaceModernPageHeight - 12',
);

foreach ($requiredContracts as $requiredContract) {
    if (strpos($template, $requiredContract) === false) {
        throw new RuntimeException('Modern invoice design contract is missing: ' . $requiredContract);
    }
}

$forbiddenContracts = array(
    '$securiaceModernItemsHtml',
    'DIGITALLY VERIFIED',
    'IT Act 2000 compliant',
    'Invoice QR record',
    'Securiace Technologies',
    'Overdue interest may apply at',
    "trim((string) \$taxCode) !== '' ? 'TAX INVOICE' : 'INVOICE'",
    'Authenticated invoice record',
    'Invoice checksum',
    'Electronic record · IT Act 2000',
    'verification_secret',
    'SECURIACE_INVOICE_VERIFY_SECRET',
    '$securiaceModernVerification',
    'hash_hmac(',
);
foreach ($forbiddenContracts as $forbiddenContract) {
    if (stripos($template, $forbiddenContract) !== false) {
        throw new RuntimeException('Modern invoice design contains a forbidden contract: ' . $forbiddenContract);
    }
}

$receiptPosition = strpos($template, "'Payment receipt'");
$stampPosition = strpos($template, "'/assets/img/stamp.png'");
$supportPosition = strpos($template, "'Payment terms & notes'");
if ($receiptPosition === false || $stampPosition === false || $supportPosition === false) {
    throw new RuntimeException('Unable to verify receipt composition order.');
}
if (!($receiptPosition < $stampPosition && $stampPosition < $supportPosition)) {
    throw new RuntimeException('Stamp/signature assets must remain inside the receipt composition.');
}

fwrite(STDOUT, "Modern invoice design contract tests passed.\n");
