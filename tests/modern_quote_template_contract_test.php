<?php

declare(strict_types=1);

$template = file_get_contents(__DIR__ . '/../quotepdf-modern.tpl');
if ($template === false) {
    throw new RuntimeException('Unable to read the modern quote template.');
}

$requiredContracts = array(
    '$securiaceQuoteRichHtml',
    'strip_tags($html,',
    "method_exists(\$pdf, 'RoundedRect')",
    "isset(\$item['qty'])",
    "isset(\$item['unitprice'])",
    "isset(\$item['discount'])",
    "isset(\$item['total'])",
    'Prepared for',
    'Prepared by',
    'COMMERCIAL PROPOSAL',
    'Validity and acceptance',
    '$securiaceQuoteStartPage',
    '$securiaceQuoteStampedPages',
    "__DIR__ . '/securiace-pdf-profile.php'",
    "'pay_to' => isset(\$companyaddress) ? \$companyaddress : array()",
    '$securiaceQuoteSellerRegistrations',
    '$securiaceQuotePaymentDetailsRendered = false',
);
foreach ($requiredContracts as $requiredContract) {
    if (strpos($template, $requiredContract) === false) {
        throw new RuntimeException('Modern quote template contract is missing: ' . $requiredContract);
    }
}

$invoiceOnlyContracts = array(
    '$stage',
    'write2DBarcode',
    'UPI payment',
    'Payment transactions',
    'Amount paid',
    'Authenticated invoice record',
    'Client notes',
    '$notes',
    'upi://pay?',
    "'Bank details'",
    '$securiaceQuotePaymentDetailsRendered = true',
    'Securiace Technologies',
);
foreach ($invoiceOnlyContracts as $invoiceOnlyContract) {
    if (stripos($template, $invoiceOnlyContract) !== false) {
        throw new RuntimeException('Modern quote template contains invoice-only logic: ' . $invoiceOnlyContract);
    }
}

fwrite(STDOUT, "Modern quote template contract tests passed.\n");
