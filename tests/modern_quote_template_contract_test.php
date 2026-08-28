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
    "'date_order' => 'DMY'",
    '$securiaceQuoteParseDate',
    '$securiaceQuoteIssuedDisplay',
    '$securiaceQuoteIssuedLabel',
    '$securiaceQuoteValidUntilDisplay',
    '$securiaceQuoteDateWarnings',
    'valid-until-precedes-issue-date',
    'Proposal summary',
    'MultiCell($summaryInnerWidth, 3.6, $securiaceQuoteSubject',
    '$securiaceQuoteShowDiscount',
    '$securiaceQuoteSplitTextForHeight',
    '$securiaceQuoteMaxDetailContinuationHeaderHeight',
    '$securiaceQuoteUsableWidth - 8',
    'Item details · continued',
    '$footerReference .= \' · Quote \'',
    "'protected-config-include-failed'",
    "'profile-helper-runtime-failed'",
    '$securiaceQuoteNormalizeIssuerProfile',
    '$securiaceQuoteIsTcpdfDeprecation',
    '$securiaceQuotePreviousErrorHandler',
    'restore_error_handler()',
    '$securiaceQuoteHttpStatus >= 500',
    'A completed quote page must not inherit',
    '$securiaceQuoteInitialHttpStatus >= 500',
    '$securiaceQuoteRenderErrorObserved === false',
    'Let\'s Seal line-safe footer reserve',
    '$securiaceQuotePageHeight - 12',
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

if (strpos($template, '$securiaceQuoteTruncate($securiaceQuoteSubject') !== false) {
    throw new RuntimeException('Modern quote template silently truncates the proposal subject.');
}

fwrite(STDOUT, "Modern quote template contract tests passed.\n");
