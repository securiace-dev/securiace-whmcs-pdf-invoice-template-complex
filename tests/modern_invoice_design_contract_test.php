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
    'Payment received in full',
    'Authorized signature',
    'No payment action required',
    'UPI payment',
    '$securiaceModernDrawTransactionHeading',
    'Transaction history',
    "\$securiaceModernStatusKey === 'unpaid'",
    '!$securiaceModernIsProforma',
    "\$securiaceModernBatchScript === 'csvdownload.php'",
    "\$securiaceModernBatchRequestType === 'pdfbatch'",
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
