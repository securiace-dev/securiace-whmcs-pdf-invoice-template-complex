<?php

/**
 * Securiace Modern WHMCS PDF Invoice Template
 *
 * Target: WHMCS 8.x and 9.x, PHP 7.4 through 8.3, TCPDF.
 * Install by copying this file as invoicepdf.tpl into the active WHMCS system
 * theme. Keep the existing invoicepdf.tpl as the rollback template.
 *
 * Optional protected configuration:
 *   ROOTDIR/includes/securiace-invoice-config.php
 */

// -------------------------------------------------------------------------
// Configuration and collision-safe local helpers
// -------------------------------------------------------------------------

$securiaceModernDefaults = array(
    'company_email' => '',
    'company_phone' => '',
    'company_pan' => '',
    'company_msme' => '',
    'bank' => array(
        'account_name' => '',
        'account_number' => '',
        'ifsc' => '',
        'account_type' => '',
        'bank_name' => '',
    ),
    'upi_id' => '',
    'verification_secret' => getenv('SECURIACE_INVOICE_VERIFY_SECRET') ?: '',
    'date_order' => 'DMY',
    'show_it_act_label' => true,
    'jurisdiction' => 'Pune, Maharashtra',
    'overdue_interest' => '18% p.a.',
    'tds_note' => 'If applicable, deduct TDS under Section 194J and provide Form 16A.',
);

$securiaceModernConfig = $securiaceModernDefaults;
$securiaceModernConfigPath = defined('ROOTDIR')
    ? ROOTDIR . '/includes/securiace-invoice-config.php'
    : '';

if ($securiaceModernConfigPath !== '' && is_readable($securiaceModernConfigPath)) {
    $securiaceModernLoadedConfig = include $securiaceModernConfigPath;
    if (is_array($securiaceModernLoadedConfig)) {
        $securiaceModernConfig = array_replace_recursive(
            $securiaceModernConfig,
            $securiaceModernLoadedConfig
        );
    }
}

// Tests and advanced integrations can inject config without writing a file.
if (isset($securiaceInvoiceConfig) && is_array($securiaceInvoiceConfig)) {
    $securiaceModernConfig = array_replace_recursive(
        $securiaceModernConfig,
        $securiaceInvoiceConfig
    );
}

if (!isset($securiaceModernConfig['bank']) || !is_array($securiaceModernConfig['bank'])) {
    $securiaceModernConfig['bank'] = $securiaceModernDefaults['bank'];
} else {
    $securiaceModernConfig['bank'] = array_replace(
        $securiaceModernDefaults['bank'],
        $securiaceModernConfig['bank']
    );
}

$securiaceModernConfigStringKeys = array(
    'company_email', 'company_phone', 'company_pan', 'company_msme', 'upi_id',
    'verification_secret', 'date_order', 'jurisdiction', 'overdue_interest', 'tds_note'
);
foreach ($securiaceModernConfigStringKeys as $securiaceModernConfigStringKey) {
    $securiaceModernConfigValue = isset($securiaceModernConfig[$securiaceModernConfigStringKey])
        ? $securiaceModernConfig[$securiaceModernConfigStringKey]
        : '';
    if (!is_scalar($securiaceModernConfigValue)
        && !(is_object($securiaceModernConfigValue) && method_exists($securiaceModernConfigValue, '__toString'))
    ) {
        $securiaceModernConfigValue = $securiaceModernDefaults[$securiaceModernConfigStringKey];
    }
    $securiaceModernConfig[$securiaceModernConfigStringKey] = (string) $securiaceModernConfigValue;
}
foreach ($securiaceModernConfig['bank'] as $securiaceModernBankConfigKey => $securiaceModernBankConfigValue) {
    if (!is_scalar($securiaceModernBankConfigValue)
        && !(is_object($securiaceModernBankConfigValue) && method_exists($securiaceModernBankConfigValue, '__toString'))
    ) {
        $securiaceModernBankConfigValue = '';
    }
    $securiaceModernConfig['bank'][$securiaceModernBankConfigKey] = (string) $securiaceModernBankConfigValue;
}

$securiaceModernInputCurrencyFormat = isset($currencyformat) && is_numeric($currencyformat)
    ? (int) $currencyformat
    : 0;

$securiaceModernEscape = static function ($value) {
    if (is_object($value) && method_exists($value, '__toString')) {
        $value = (string) $value;
    }
    return htmlspecialchars((string) $value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
};

$securiaceModernMoneyToFloat = static function ($value) use ($securiaceModernInputCurrencyFormat) {
    if (is_int($value) || is_float($value)) {
        return (float) $value;
    }
    if (is_object($value) && method_exists($value, '__toString')) {
        $value = (string) $value;
    }
    if (!is_string($value)) {
        return 0.0;
    }

    $negative = strpos($value, '(') !== false && strpos($value, ')') !== false;
    $clean = preg_replace('/[^0-9,\.\-]/u', '', $value);
    if ($clean === null || $clean === '' || $clean === '-') {
        return 0.0;
    }

    if ($securiaceModernInputCurrencyFormat === 2) {
        $number = (float) str_replace(array('.', ','), array('', '.'), $clean);
        return $negative ? -abs($number) : $number;
    }
    if (in_array($securiaceModernInputCurrencyFormat, array(1, 3, 4), true)) {
        $number = (float) str_replace(',', '', $clean);
        return $negative ? -abs($number) : $number;
    }

    $lastDot = strrpos($clean, '.');
    $lastComma = strrpos($clean, ',');
    if ($lastDot !== false && $lastComma !== false) {
        if ($lastDot > $lastComma) {
            $clean = str_replace(',', '', $clean);
        } else {
            $clean = str_replace('.', '', $clean);
            $clean = str_replace(',', '.', $clean);
        }
    } elseif ($lastComma !== false) {
        $digitsAfter = strlen($clean) - $lastComma - 1;
        if (substr_count($clean, ',') === 1 && $digitsAfter > 0 && $digitsAfter <= 2) {
            $clean = str_replace(',', '.', $clean);
        } else {
            $clean = str_replace(',', '', $clean);
        }
    } elseif ($lastDot !== false && substr_count($clean, '.') > 1) {
        $parts = explode('.', $clean);
        $decimal = array_pop($parts);
        $clean = implode('', $parts) . (strlen($decimal) <= 3 ? '.' . $decimal : $decimal);
    }

    $number = (float) $clean;
    return $negative ? -abs($number) : $number;
};

$securiaceModernCurrencyCode = '';
if (isset($currencycode) && trim((string) $currencycode) !== '') {
    $securiaceModernCurrencyCode = strtoupper(trim((string) $currencycode));
} elseif (isset($currencysuffix)) {
    $securiaceModernCurrencyCode = strtoupper(trim((string) $currencysuffix));
}
if ($securiaceModernCurrencyCode === '') {
    $securiaceModernCurrencyCode = 'INR';
}

$securiaceModernCurrencyPrefix = isset($currencyprefix) ? trim((string) $currencyprefix) : '';
$securiaceModernCurrencySuffix = isset($currencysuffix) ? trim((string) $currencysuffix) : '';
$securiaceModernCurrencyFormat = $securiaceModernInputCurrencyFormat > 0
    ? $securiaceModernInputCurrencyFormat
    : 1;

$securiaceModernFormatMoney = static function ($amount) use (
    $securiaceModernCurrencyPrefix,
    $securiaceModernCurrencySuffix,
    $securiaceModernCurrencyFormat,
    $securiaceModernCurrencyCode
) {
    $zeroDecimal = array(
        'BIF', 'CLP', 'DJF', 'GNF', 'ISK', 'JPY', 'KMF', 'KRW', 'PYG',
        'RWF', 'UGX', 'VND', 'VUV', 'XAF', 'XOF', 'XPF'
    );
    $threeDecimal = array('BHD', 'IQD', 'JOD', 'KWD', 'LYD', 'OMR', 'TND');
    $decimals = in_array($securiaceModernCurrencyCode, $zeroDecimal, true)
        ? 0
        : (in_array($securiaceModernCurrencyCode, $threeDecimal, true) ? 3 : 2);

    $decimalSeparator = '.';
    $thousandsSeparator = ',';
    $format = $securiaceModernCurrencyFormat;
    if ($format === 2) {
        $decimalSeparator = ',';
        $thousandsSeparator = '.';
    } elseif ($format === 3) {
        $decimalSeparator = '.';
        $thousandsSeparator = ' ';
    } elseif ($format === 4) {
        $thousandsSeparator = '';
    }

    $formatted = number_format((float) $amount, $decimals, $decimalSeparator, $thousandsSeparator);
    return ($securiaceModernCurrencyPrefix !== '' ? $securiaceModernCurrencyPrefix . ' ' : '')
        . $formatted
        . ($securiaceModernCurrencySuffix !== '' ? ' ' . $securiaceModernCurrencySuffix : '');
};

$securiaceModernDisplay = static function ($value, $numericFallback) use ($securiaceModernFormatMoney) {
    if (is_object($value) && method_exists($value, '__toString')) {
        $value = (string) $value;
    }
    if (is_string($value) && trim($value) !== '') {
        return trim($value);
    }
    if (is_numeric($value)) {
        return $securiaceModernFormatMoney((float) $value);
    }
    return $securiaceModernFormatMoney((float) $numericFallback);
};

$securiaceModernRgb = static function ($hex) {
    $hex = ltrim((string) $hex, '#');
    return array(
        hexdec(substr($hex, 0, 2)),
        hexdec(substr($hex, 2, 2)),
        hexdec(substr($hex, 4, 2)),
    );
};

$securiaceModernPlainText = static function ($value) {
    $text = strip_tags((string) $value);
    $text = preg_replace('/\s+/u', ' ', $text);
    return trim($text === null ? '' : $text);
};

$securiaceModernTruncate = static function ($value, $maxLength) {
    $value = (string) $value;
    if (function_exists('mb_strlen') && function_exists('mb_substr')) {
        return mb_strlen($value, 'UTF-8') > $maxLength
            ? mb_substr($value, 0, $maxLength - 1, 'UTF-8') . '…'
            : $value;
    }
    return strlen($value) > $maxLength
        ? substr($value, 0, $maxLength - 3) . '...'
        : $value;
};

$securiaceModernIsUsableImage = static function ($path) {
    return is_string($path) && $path !== '' && is_readable($path) && @getimagesize($path) !== false;
};

$securiaceModernParseDate = static function ($value) use (&$securiaceModernConfig) {
    $value = trim((string) $value);
    if ($value === '') {
        return null;
    }

    $dateOrder = strtoupper(trim((string) $securiaceModernConfig['date_order']));
    $dateOrder = in_array($dateOrder, array('DMY', 'MDY'), true) ? $dateOrder : 'DMY';
    $formats = preg_match('/^\d{4}[\/-]/', $value)
        ? array('!Y-m-d', '!Y/m/d')
        : ($dateOrder === 'MDY'
            ? array('!m/d/Y', '!m-d-Y', '!d/m/Y', '!d-m-Y')
            : array('!d/m/Y', '!d-m-Y', '!m/d/Y', '!m-d-Y'));

    foreach ($formats as $format) {
        $date = DateTimeImmutable::createFromFormat($format, $value);
        $errors = DateTimeImmutable::getLastErrors();
        if ($date !== false && ($errors === false || ($errors['warning_count'] === 0 && $errors['error_count'] === 0))) {
            return $date;
        }
    }

    return null;
};

// -------------------------------------------------------------------------
// WHMCS data normalization
// -------------------------------------------------------------------------

$securiaceModernFont = isset($pdfFont) && trim((string) $pdfFont) !== ''
    ? (string) $pdfFont
    : 'dejavusans';
$securiaceModernStatus = isset($status) ? trim((string) $status) : 'Draft';
$securiaceModernStatusKey = strtolower($securiaceModernStatus);
$securiaceModernInvoiceId = isset($invoiceid) ? (string) $invoiceid : '';
$securiaceModernInvoiceNumber = isset($invoicenum) && trim((string) $invoicenum) !== ''
    ? trim((string) $invoicenum)
    : $securiaceModernInvoiceId;
if ($securiaceModernInvoiceNumber === '') {
    $securiaceModernInvoiceNumber = '—';
}

$securiaceModernPageTitle = isset($pagetitle) ? $securiaceModernPlainText($pagetitle) : '';
$securiaceModernIsProforma = stripos($securiaceModernPageTitle, 'proforma') !== false;
if (isset($isProformaInvoice)) {
    $securiaceModernIsProforma = (bool) $isProformaInvoice;
}
$securiaceModernDocumentTitle = $securiaceModernIsProforma ? 'Proforma Invoice' : 'Invoice';
$securiaceModernDocumentKicker = $securiaceModernIsProforma
    ? 'PROFORMA'
    : (isset($taxCode) && trim((string) $taxCode) !== '' ? 'TAX INVOICE' : 'INVOICE');

$securiaceModernItems = isset($invoiceitems) && is_array($invoiceitems) ? $invoiceitems : array();
$securiaceModernTransactions = isset($transactions) && is_array($transactions) ? $transactions : array();
$securiaceModernCustomFields = isset($customfields) && is_array($customfields) ? $customfields : array();
if (!isset($clientsdetails) || !is_array($clientsdetails)) {
    $clientsdetails = array();
}

$securiaceModernSubtotalNumeric = isset($subtotal) ? $securiaceModernMoneyToFloat($subtotal) : 0.0;
$securiaceModernTaxNumeric = isset($tax) ? $securiaceModernMoneyToFloat($tax) : 0.0;
$securiaceModernTax2Numeric = isset($tax2) ? $securiaceModernMoneyToFloat($tax2) : 0.0;
$securiaceModernCreditNumeric = isset($credit) ? $securiaceModernMoneyToFloat($credit) : 0.0;
$securiaceModernDiscountNumeric = isset($discount) ? $securiaceModernMoneyToFloat($discount) : 0.0;
$securiaceModernTotalNumeric = isset($total) ? $securiaceModernMoneyToFloat($total) : 0.0;
$securiaceModernBalanceNumeric = isset($balance) ? $securiaceModernMoneyToFloat($balance) : 0.0;

$securiaceModernSubtotalDisplay = $securiaceModernDisplay(isset($subtotal) ? $subtotal : null, $securiaceModernSubtotalNumeric);
$securiaceModernTaxDisplay = $securiaceModernDisplay(isset($tax) ? $tax : null, $securiaceModernTaxNumeric);
$securiaceModernTax2Display = $securiaceModernDisplay(isset($tax2) ? $tax2 : null, $securiaceModernTax2Numeric);
$securiaceModernCreditDisplay = $securiaceModernDisplay(isset($credit) ? $credit : null, $securiaceModernCreditNumeric);
$securiaceModernDiscountDisplay = $securiaceModernDisplay(isset($discount) ? $discount : null, $securiaceModernDiscountNumeric);
$securiaceModernTotalDisplay = $securiaceModernDisplay(isset($total) ? $total : null, $securiaceModernTotalNumeric);
$securiaceModernBalanceDisplay = $securiaceModernDisplay(isset($balance) ? $balance : null, $securiaceModernBalanceNumeric);
$securiaceModernExpectedTotalNumeric = $securiaceModernSubtotalNumeric
    - $securiaceModernDiscountNumeric
    + $securiaceModernTaxNumeric
    + $securiaceModernTax2Numeric
    - $securiaceModernCreditNumeric;
$securiaceModernReconciliationDeltaNumeric = $securiaceModernTotalNumeric - $securiaceModernExpectedTotalNumeric;

$securiaceModernIsPaid = $securiaceModernStatusKey === 'paid';
$securiaceModernIsRefunded = $securiaceModernStatusKey === 'refunded';
$securiaceModernNoPaymentStatuses = array('paid', 'cancelled', 'collections', 'draft', 'refunded');
$securiaceModernIsPayable = $securiaceModernBalanceNumeric > 0.00001
    && !in_array($securiaceModernStatusKey, $securiaceModernNoPaymentStatuses, true);

$securiaceModernStatusPalette = array(
    'paid' => array('ink' => '#0B7542', 'soft' => '#EAF6EF', 'line' => '#B8DDC8'),
    'unpaid' => array('ink' => '#9A5700', 'soft' => '#FFF5E5', 'line' => '#EFD4A3'),
    'payment pending' => array('ink' => '#9A5700', 'soft' => '#FFF5E5', 'line' => '#EFD4A3'),
    'overdue' => array('ink' => '#A6382F', 'soft' => '#FCEDEC', 'line' => '#E8B9B5'),
    'refunded' => array('ink' => '#245E86', 'soft' => '#EBF4FA', 'line' => '#B9D4E5'),
    'cancelled' => array('ink' => '#5D5662', 'soft' => '#F1EFF2', 'line' => '#D7D1DA'),
    'collections' => array('ink' => '#5D5662', 'soft' => '#F1EFF2', 'line' => '#D7D1DA'),
    'draft' => array('ink' => '#5D5662', 'soft' => '#F1EFF2', 'line' => '#D7D1DA'),
);
$securiaceModernPalette = isset($securiaceModernStatusPalette[$securiaceModernStatusKey])
    ? $securiaceModernStatusPalette[$securiaceModernStatusKey]
    : $securiaceModernStatusPalette['unpaid'];

$securiaceModernBrand = array(79, 11, 112);
$securiaceModernBrandDark = array(50, 16, 68);
$securiaceModernInk = array(32, 28, 36);
$securiaceModernMuted = array(109, 102, 114);
$securiaceModernLine = array(221, 215, 225);
$securiaceModernSurface = array(248, 246, 248);
$securiaceModernPaper = array(255, 254, 253);
$securiaceModernStatusInk = $securiaceModernRgb($securiaceModernPalette['ink']);
$securiaceModernStatusSoft = $securiaceModernRgb($securiaceModernPalette['soft']);
$securiaceModernStatusLine = $securiaceModernRgb($securiaceModernPalette['line']);

$securiaceModernCompanyName = isset($companyname) && trim((string) $companyname) !== ''
    ? trim((string) $companyname)
    : 'Securiace Technologies';
$securiaceModernCompanyAddress = array();
if (isset($companyaddress) && is_array($companyaddress)) {
    foreach ($companyaddress as $securiaceModernCompanyAddressLine) {
        if (is_scalar($securiaceModernCompanyAddressLine)
            || (is_object($securiaceModernCompanyAddressLine) && method_exists($securiaceModernCompanyAddressLine, '__toString'))
        ) {
            $securiaceModernCompanyAddressLine = trim((string) $securiaceModernCompanyAddressLine);
            if ($securiaceModernCompanyAddressLine !== '') {
                $securiaceModernCompanyAddress[] = $securiaceModernCompanyAddressLine;
            }
        }
    }
}

$securiaceModernClientName = '';
if (!empty($clientsdetails['companyname'])) {
    $securiaceModernClientName = trim((string) $clientsdetails['companyname']);
} else {
    $securiaceModernClientName = trim(
        (isset($clientsdetails['firstname']) ? $clientsdetails['firstname'] : '')
        . ' '
        . (isset($clientsdetails['lastname']) ? $clientsdetails['lastname'] : '')
    );
}
if ($securiaceModernClientName === '') {
    $securiaceModernClientName = 'Client';
}

$securiaceModernClientLines = array();
foreach (array('address1', 'address2') as $securiaceModernAddressKey) {
    if (!empty($clientsdetails[$securiaceModernAddressKey])) {
        $securiaceModernClientLines[] = trim((string) $clientsdetails[$securiaceModernAddressKey]);
    }
}
$securiaceModernCityLine = array();
foreach (array('city', 'state', 'postcode') as $securiaceModernCityKey) {
    if (!empty($clientsdetails[$securiaceModernCityKey])) {
        $securiaceModernCityLine[] = trim((string) $clientsdetails[$securiaceModernCityKey]);
    }
}
if (!empty($securiaceModernCityLine)) {
    $securiaceModernClientLines[] = implode(', ', $securiaceModernCityLine);
}
if (!empty($clientsdetails['country'])) {
    $securiaceModernClientLines[] = trim((string) $clientsdetails['country']);
}
if (!empty($clientsdetails['email'])) {
    $securiaceModernClientLines[] = trim((string) $clientsdetails['email']);
}
if (!empty($clientsdetails['phonenumber'])) {
    $securiaceModernClientLines[] = trim((string) $clientsdetails['phonenumber']);
}
if (!empty($clientsdetails['tax_id'])) {
    $securiaceModernClientLines[] = (isset($taxIdLabel) && trim((string) $taxIdLabel) !== ''
        ? trim((string) $taxIdLabel)
        : 'Tax ID') . ': ' . trim((string) $clientsdetails['tax_id']);
}
foreach ($securiaceModernCustomFields as $securiaceModernCustomField) {
    if (!empty($securiaceModernCustomField['fieldname']) && isset($securiaceModernCustomField['value'])) {
        $securiaceModernClientLines[] = trim((string) $securiaceModernCustomField['fieldname'])
            . ': ' . trim((string) $securiaceModernCustomField['value']);
    }
}

$securiaceModernSellerLines = $securiaceModernCompanyAddress;
foreach (array('company_email', 'company_phone') as $securiaceModernSellerConfigKey) {
    if (trim((string) $securiaceModernConfig[$securiaceModernSellerConfigKey]) !== '') {
        $securiaceModernSellerLines[] = trim((string) $securiaceModernConfig[$securiaceModernSellerConfigKey]);
    }
}
if (trim((string) $securiaceModernConfig['company_pan']) !== '') {
    $securiaceModernSellerLines[] = 'PAN: ' . trim((string) $securiaceModernConfig['company_pan']);
}
if (trim((string) $securiaceModernConfig['company_msme']) !== '') {
    $securiaceModernSellerLines[] = 'MSME: ' . trim((string) $securiaceModernConfig['company_msme']);
}
if (isset($taxCode) && trim((string) $taxCode) !== '') {
    $securiaceModernSellerLines[] = (isset($taxIdLabel) && trim((string) $taxIdLabel) !== ''
        ? trim((string) $taxIdLabel)
        : 'Tax ID') . ': ' . trim((string) $taxCode);
}

// Stable verification: immutable invoice fields only. The generation timestamp
// is displayed separately and never changes the verification ID.
$securiaceModernVerificationInput = implode('|', array(
    $securiaceModernInvoiceId,
    $securiaceModernInvoiceNumber,
    number_format($securiaceModernTotalNumeric, 3, '.', ''),
    isset($datecreated) ? (string) $datecreated : '',
    isset($duedate) ? (string) $duedate : '',
    isset($clientsdetails['id']) ? (string) $clientsdetails['id'] : '',
    isset($clientsdetails['email']) ? (string) $clientsdetails['email'] : '',
    $securiaceModernCompanyName,
));
$securiaceModernVerificationSecret = trim((string) $securiaceModernConfig['verification_secret']);
$securiaceModernVerificationHash = $securiaceModernVerificationSecret !== ''
    ? hash_hmac('sha256', $securiaceModernVerificationInput, $securiaceModernVerificationSecret)
    : hash('sha256', $securiaceModernVerificationInput);
$securiaceModernVerificationId = strtoupper(substr($securiaceModernVerificationHash, 0, 12))
    . ' · ' . strtoupper(substr($securiaceModernVerificationHash, 12, 8));
$securiaceModernHasAuthenticatedVerification = $securiaceModernVerificationSecret !== '';

$securiaceModernTransactionTotal = 0.0;
$securiaceModernHasTransactionStatus = false;
foreach ($securiaceModernTransactions as $securiaceModernTransaction) {
    $securiaceModernTransactionTotal += isset($securiaceModernTransaction['amount'])
        ? $securiaceModernMoneyToFloat($securiaceModernTransaction['amount'])
        : 0.0;
    if (!empty($securiaceModernTransaction['status'])) {
        $securiaceModernHasTransactionStatus = true;
    }
}

$securiaceModernSettlementMismatch = $securiaceModernIsPaid
    && abs(($securiaceModernTransactionTotal + $securiaceModernCreditNumeric) - $securiaceModernTotalNumeric) > 0.01;

$securiaceModernRenewals = array();
foreach ($securiaceModernItems as $securiaceModernItem) {
    $securiaceModernDescription = isset($securiaceModernItem['description'])
        ? (string) $securiaceModernItem['description']
        : '';
    if (preg_match(
        '/(\d{1,4}[\/-]\d{1,2}[\/-]\d{1,4})\s*[-–]\s*(\d{1,4}[\/-]\d{1,2}[\/-]\d{1,4})/u',
        $securiaceModernDescription,
        $securiaceModernDateMatches
    )) {
        $securiaceModernRenewalDate = $securiaceModernParseDate($securiaceModernDateMatches[2]);
        if ($securiaceModernRenewalDate instanceof DateTimeImmutable) {
            $securiaceModernRenewals[] = array(
                'description' => $securiaceModernPlainText($securiaceModernDescription),
                'date' => $securiaceModernRenewalDate->format('j M Y'),
            );
        }
    }
}

// -------------------------------------------------------------------------
// PDF setup and shared drawing helpers
// -------------------------------------------------------------------------

$securiaceModernMargin = 14.0;
$securiaceModernTopMargin = 20.0;
$securiaceModernBottomMargin = 15.0;
$pdf->SetMargins($securiaceModernMargin, $securiaceModernTopMargin, $securiaceModernMargin);
$pdf->SetAutoPageBreak(true, $securiaceModernBottomMargin);
$pdf->SetFont($securiaceModernFont, '', 8);
$pdf->SetTextColor($securiaceModernInk[0], $securiaceModernInk[1], $securiaceModernInk[2]);
$pdf->SetDrawColor($securiaceModernLine[0], $securiaceModernLine[1], $securiaceModernLine[2]);
$pdf->SetFillColor($securiaceModernPaper[0], $securiaceModernPaper[1], $securiaceModernPaper[2]);

$securiaceModernPageWidth = $pdf->getPageWidth();
$securiaceModernPageHeight = $pdf->getPageHeight();
$securiaceModernUsableWidth = $securiaceModernPageWidth - ($securiaceModernMargin * 2);

$securiaceModernEnsureSpace = static function ($height) use (
    $pdf,
    $securiaceModernPageHeight,
    $securiaceModernBottomMargin,
    $securiaceModernTopMargin
) {
    if ($pdf->GetY() + $height > $securiaceModernPageHeight - $securiaceModernBottomMargin) {
        $pdf->AddPage();
        $pdf->SetY($securiaceModernTopMargin);
        return true;
    }
    return false;
};

$securiaceModernDrawLabel = static function ($label, $x, $y, $width) use (
    $pdf,
    $securiaceModernFont,
    $securiaceModernBrand
) {
    $pdf->SetFont($securiaceModernFont, 'B', 6.5);
    $pdf->SetTextColor($securiaceModernBrand[0], $securiaceModernBrand[1], $securiaceModernBrand[2]);
    $pdf->SetXY($x, $y);
    $pdf->Cell($width, 3.5, strtoupper((string) $label), 0, 0, 'L');
};

$securiaceModernDrawCard = static function ($x, $y, $width, $height, $fill, $line) use ($pdf) {
    $pdf->SetFillColor($fill[0], $fill[1], $fill[2]);
    $pdf->SetDrawColor($line[0], $line[1], $line[2]);
    $pdf->SetLineWidth(0.25);
    $pdf->Rect($x, $y, $width, $height, 'DF');
};

// -------------------------------------------------------------------------
// Header and document identity
// -------------------------------------------------------------------------

$securiaceModernHeaderY = $securiaceModernTopMargin;
$securiaceModernLogoPath = '';
if (defined('ROOTDIR')) {
    foreach (array('logo.png', 'logo.jpg', 'logo.jpeg') as $securiaceModernLogoFile) {
        $securiaceModernCandidateLogo = ROOTDIR . '/assets/img/' . $securiaceModernLogoFile;
        if ($securiaceModernIsUsableImage($securiaceModernCandidateLogo)) {
            $securiaceModernLogoPath = $securiaceModernCandidateLogo;
            break;
        }
    }
}

if ($securiaceModernLogoPath !== '') {
    $pdf->Image($securiaceModernLogoPath, $securiaceModernMargin, $securiaceModernHeaderY, 42, 0, '', '', '', false, 300);
} else {
    $pdf->SetFont($securiaceModernFont, 'B', 17);
    $pdf->SetTextColor($securiaceModernInk[0], $securiaceModernInk[1], $securiaceModernInk[2]);
    $pdf->SetXY($securiaceModernMargin, $securiaceModernHeaderY + 1);
    $pdf->Cell(90, 7, $securiaceModernCompanyName, 0, 1, 'L');
}

$pdf->SetFont($securiaceModernFont, 'B', 6.5);
$pdf->SetTextColor($securiaceModernBrand[0], $securiaceModernBrand[1], $securiaceModernBrand[2]);
$pdf->SetXY($securiaceModernPageWidth - $securiaceModernMargin - 66, $securiaceModernHeaderY);
$pdf->Cell(66, 4, $securiaceModernDocumentKicker, 0, 1, 'R');
$pdf->SetFont($securiaceModernFont, 'B', 22);
$pdf->SetTextColor($securiaceModernInk[0], $securiaceModernInk[1], $securiaceModernInk[2]);
$pdf->SetX($securiaceModernPageWidth - $securiaceModernMargin - 66);
$pdf->Cell(66, 8, $securiaceModernDocumentTitle, 0, 1, 'R');

$securiaceModernStatusWidth = max(28, min(52, strlen($securiaceModernStatus) * 2.2 + 12));
$securiaceModernStatusX = $securiaceModernPageWidth - $securiaceModernMargin - $securiaceModernStatusWidth;
$pdf->SetFillColor($securiaceModernStatusSoft[0], $securiaceModernStatusSoft[1], $securiaceModernStatusSoft[2]);
$pdf->SetDrawColor($securiaceModernStatusLine[0], $securiaceModernStatusLine[1], $securiaceModernStatusLine[2]);
$pdf->Rect($securiaceModernStatusX, $securiaceModernHeaderY + 14, $securiaceModernStatusWidth, 7, 'DF');
$pdf->SetFont($securiaceModernFont, 'B', 7);
$pdf->SetTextColor($securiaceModernStatusInk[0], $securiaceModernStatusInk[1], $securiaceModernStatusInk[2]);
$pdf->SetXY($securiaceModernStatusX, $securiaceModernHeaderY + 15.3);
$pdf->Cell($securiaceModernStatusWidth, 4, strtoupper($securiaceModernStatus), 0, 1, 'C');

$securiaceModernRuleY = $securiaceModernHeaderY + 26;
$pdf->SetDrawColor($securiaceModernBrand[0], $securiaceModernBrand[1], $securiaceModernBrand[2]);
$pdf->SetLineWidth(0.35);
$pdf->Line(
    $securiaceModernMargin,
    $securiaceModernRuleY,
    $securiaceModernPageWidth - $securiaceModernMargin,
    $securiaceModernRuleY
);

$securiaceModernMetaY = $securiaceModernRuleY + 5;
$securiaceModernMetaWidth = ($securiaceModernUsableWidth - 72) / 3;
$securiaceModernMeta = array(
    array('Invoice number', $securiaceModernInvoiceNumber),
    array('Invoice date', isset($datecreated) ? $datecreated : '—'),
);
if ($securiaceModernIsPaid && $securiaceModernInvoiceId !== '' && $securiaceModernInvoiceId !== $securiaceModernInvoiceNumber) {
    $securiaceModernMeta[] = array('Original reference', $securiaceModernInvoiceId);
} else {
    $securiaceModernMeta[] = array('Due date', isset($duedate) ? $duedate : '—');
}

foreach ($securiaceModernMeta as $securiaceModernMetaIndex => $securiaceModernMetaItem) {
    $securiaceModernMetaX = $securiaceModernMargin + ($securiaceModernMetaIndex * $securiaceModernMetaWidth);
    $pdf->SetFont($securiaceModernFont, '', 6.5);
    $pdf->SetTextColor($securiaceModernMuted[0], $securiaceModernMuted[1], $securiaceModernMuted[2]);
    $pdf->SetXY($securiaceModernMetaX, $securiaceModernMetaY);
    $pdf->Cell($securiaceModernMetaWidth - 3, 3.5, $securiaceModernMetaItem[0], 0, 1, 'L');
    $pdf->SetFont($securiaceModernFont, 'B', 8);
    $pdf->SetTextColor($securiaceModernInk[0], $securiaceModernInk[1], $securiaceModernInk[2]);
    $pdf->SetX($securiaceModernMetaX);
    $pdf->Cell($securiaceModernMetaWidth - 3, 4.5, (string) $securiaceModernMetaItem[1], 0, 1, 'L');
}

$securiaceModernStatePanelX = $securiaceModernPageWidth - $securiaceModernMargin - 68;
$securiaceModernStatePanelY = $securiaceModernMetaY - 1;
$securiaceModernDrawCard(
    $securiaceModernStatePanelX,
    $securiaceModernStatePanelY,
    68,
    16,
    $securiaceModernStatusSoft,
    $securiaceModernStatusLine
);
$pdf->SetFont($securiaceModernFont, 'B', 7.5);
$pdf->SetTextColor($securiaceModernStatusInk[0], $securiaceModernStatusInk[1], $securiaceModernStatusInk[2]);
$pdf->SetXY($securiaceModernStatePanelX + 4, $securiaceModernStatePanelY + 2);

if ($securiaceModernIsPaid) {
    $pdf->Cell(60, 4, $securiaceModernHasAuthenticatedVerification ? 'Authenticated invoice record' : 'Invoice checksum', 0, 1, 'L');
    $pdf->SetFont($securiaceModernFont, '', 6);
    $pdf->SetX($securiaceModernStatePanelX + 4);
    $pdf->Cell(60, 3.5, 'ID ' . $securiaceModernVerificationId, 0, 1, 'L');
    if ($securiaceModernHasAuthenticatedVerification && !empty($securiaceModernConfig['show_it_act_label'])) {
        $pdf->SetX($securiaceModernStatePanelX + 4);
        $pdf->Cell(60, 3.5, 'Electronic record · IT Act 2000', 0, 1, 'L');
    }
} elseif ($securiaceModernIsPayable) {
    $pdf->Cell(60, 4, 'Balance due', 0, 1, 'L');
    $pdf->SetFont($securiaceModernFont, 'B', 10);
    $pdf->SetX($securiaceModernStatePanelX + 4);
    $pdf->Cell(60, 5, $securiaceModernBalanceDisplay, 0, 1, 'L');
    $pdf->SetFont($securiaceModernFont, '', 6);
    $pdf->SetX($securiaceModernStatePanelX + 4);
    $pdf->Cell(60, 3.5, 'Pay by ' . (isset($duedate) ? $duedate : 'the due date'), 0, 1, 'L');
} else {
    $pdf->Cell(60, 4, ucfirst($securiaceModernStatusKey) . ' invoice', 0, 1, 'L');
    $pdf->SetFont($securiaceModernFont, '', 6.5);
    $pdf->SetX($securiaceModernStatePanelX + 4);
    $pdf->MultiCell(60, 3.5, 'No payment action is available for this document state.', 0, 'L');
}

$pdf->SetY($securiaceModernStatePanelY + 21);

// -------------------------------------------------------------------------
// Billing parties
// -------------------------------------------------------------------------

$securiaceModernPartyGap = 4;
$securiaceModernPartyWidth = ($securiaceModernUsableWidth - $securiaceModernPartyGap) / 2;
$securiaceModernPartyY = $pdf->GetY();
$securiaceModernClientText = implode("\n", $securiaceModernClientLines);
$securiaceModernSellerText = implode("\n", $securiaceModernSellerLines);
$pdf->SetFont($securiaceModernFont, '', 7);
$securiaceModernClientHeight = $pdf->getStringHeight($securiaceModernPartyWidth - 8, $securiaceModernClientText);
$securiaceModernSellerHeight = $pdf->getStringHeight($securiaceModernPartyWidth - 8, $securiaceModernSellerText);
$securiaceModernPartyHeight = max(35, 16 + max($securiaceModernClientHeight, $securiaceModernSellerHeight));

$securiaceModernDrawCard(
    $securiaceModernMargin,
    $securiaceModernPartyY,
    $securiaceModernPartyWidth,
    $securiaceModernPartyHeight,
    $securiaceModernPaper,
    $securiaceModernLine
);
$securiaceModernDrawCard(
    $securiaceModernMargin + $securiaceModernPartyWidth + $securiaceModernPartyGap,
    $securiaceModernPartyY,
    $securiaceModernPartyWidth,
    $securiaceModernPartyHeight,
    $securiaceModernPaper,
    $securiaceModernLine
);
$pdf->SetFillColor($securiaceModernBrand[0], $securiaceModernBrand[1], $securiaceModernBrand[2]);
$pdf->Rect($securiaceModernMargin, $securiaceModernPartyY, $securiaceModernPartyWidth, 0.8, 'F');

$securiaceModernPartyColumns = array(
    array('Billed to', $securiaceModernClientName, $securiaceModernClientText, $securiaceModernMargin),
    array(
        'Billed by',
        $securiaceModernCompanyName,
        $securiaceModernSellerText,
        $securiaceModernMargin + $securiaceModernPartyWidth + $securiaceModernPartyGap
    ),
);
foreach ($securiaceModernPartyColumns as $securiaceModernPartyColumn) {
    $securiaceModernPartyX = $securiaceModernPartyColumn[3];
    $securiaceModernDrawLabel($securiaceModernPartyColumn[0], $securiaceModernPartyX + 4, $securiaceModernPartyY + 4, $securiaceModernPartyWidth - 8);
    $pdf->SetFont($securiaceModernFont, 'B', 9);
    $pdf->SetTextColor($securiaceModernInk[0], $securiaceModernInk[1], $securiaceModernInk[2]);
    $pdf->SetXY($securiaceModernPartyX + 4, $securiaceModernPartyY + 8);
    $pdf->MultiCell($securiaceModernPartyWidth - 8, 4, $securiaceModernPartyColumn[1], 0, 'L');
    $pdf->SetFont($securiaceModernFont, '', 7);
    $pdf->SetTextColor($securiaceModernMuted[0], $securiaceModernMuted[1], $securiaceModernMuted[2]);
    $pdf->SetXY($securiaceModernPartyX + 4, $pdf->GetY() + 1);
    $pdf->MultiCell($securiaceModernPartyWidth - 8, 3.5, $securiaceModernPartyColumn[2], 0, 'L');
}
$pdf->SetY($securiaceModernPartyY + $securiaceModernPartyHeight + 5);

// -------------------------------------------------------------------------
// Line items — use WHMCS line totals as line totals; quantity is conditional.
// -------------------------------------------------------------------------

$securiaceModernDrawLabel('Charges', $securiaceModernMargin, $pdf->GetY(), $securiaceModernUsableWidth);
$pdf->SetFont($securiaceModernFont, 'B', 9.5);
$pdf->SetTextColor($securiaceModernInk[0], $securiaceModernInk[1], $securiaceModernInk[2]);
$pdf->SetXY($securiaceModernMargin, $pdf->GetY() + 3.5);
$pdf->Cell($securiaceModernUsableWidth - 40, 4.5, 'Services and billing period', 0, 0, 'L');
$pdf->SetFont($securiaceModernFont, 'B', 6);
$pdf->SetTextColor($securiaceModernMuted[0], $securiaceModernMuted[1], $securiaceModernMuted[2]);
$pdf->Cell(40, 4.5, 'Currency · ' . $securiaceModernCurrencyCode, 0, 1, 'R');
$pdf->Ln(1.5);

$securiaceModernHasExplicitQuantity = false;
foreach ($securiaceModernItems as $securiaceModernItem) {
    if (isset($securiaceModernItem['qty']) && is_numeric($securiaceModernItem['qty']) && (float) $securiaceModernItem['qty'] > 0) {
        $securiaceModernHasExplicitQuantity = true;
        break;
    }
}

$securiaceModernDescriptionWidth = $securiaceModernHasExplicitQuantity
    ? $securiaceModernUsableWidth * 0.58
    : $securiaceModernUsableWidth * 0.78;
$securiaceModernQtyWidth = $securiaceModernHasExplicitQuantity ? $securiaceModernUsableWidth * 0.09 : 0;
$securiaceModernRateWidth = $securiaceModernHasExplicitQuantity ? $securiaceModernUsableWidth * 0.15 : 0;
$securiaceModernAmountWidth = $securiaceModernUsableWidth
    - $securiaceModernDescriptionWidth
    - $securiaceModernQtyWidth
    - $securiaceModernRateWidth;

$securiaceModernItemsHtml = '<table width="100%" border="0" cellspacing="0" cellpadding="5">'
    . '<thead><tr bgcolor="#4F0B70" color="#FFFFFF" style="font-size:7px;font-weight:bold;">'
    . '<th width="' . round(($securiaceModernDescriptionWidth / $securiaceModernUsableWidth) * 100, 2) . '%" align="left">DESCRIPTION</th>';
if ($securiaceModernHasExplicitQuantity) {
    $securiaceModernItemsHtml .= '<th width="9%" align="right">QTY</th>'
        . '<th width="15%" align="right">RATE</th>';
}
$securiaceModernItemsHtml .= '<th width="' . round(($securiaceModernAmountWidth / $securiaceModernUsableWidth) * 100, 2) . '%" align="right">AMOUNT</th>'
    . '</tr></thead><tbody>';

if (empty($securiaceModernItems)) {
    $securiaceModernItemsHtml .= '<tr bgcolor="#FFFefd"><td colspan="4" align="center" color="#6D6672">No line items found.</td></tr>';
} else {
    foreach ($securiaceModernItems as $securiaceModernItemIndex => $securiaceModernItem) {
        $securiaceModernItemDescription = isset($securiaceModernItem['description'])
            ? (string) $securiaceModernItem['description']
            : 'Invoice item';
        $securiaceModernItemAmountRaw = isset($securiaceModernItem['amount'])
            ? $securiaceModernItem['amount']
            : 0;
        $securiaceModernItemAmountNumeric = $securiaceModernMoneyToFloat($securiaceModernItemAmountRaw);
        $securiaceModernItemAmountDisplay = $securiaceModernDisplay(
            $securiaceModernItemAmountRaw,
            $securiaceModernItemAmountNumeric
        );
        $securiaceModernRowColor = $securiaceModernItemIndex % 2 === 0 ? '#FFFEFD' : '#F8F6F8';
        $securiaceModernItemsHtml .= '<tr bgcolor="' . $securiaceModernRowColor . '" style="font-size:8px;">'
            . '<td width="' . round(($securiaceModernDescriptionWidth / $securiaceModernUsableWidth) * 100, 2) . '%" align="left">'
            . nl2br($securiaceModernEscape($securiaceModernItemDescription)) . '</td>';
        if ($securiaceModernHasExplicitQuantity) {
            $securiaceModernItemHasQuantity = isset($securiaceModernItem['qty'])
                && is_numeric($securiaceModernItem['qty'])
                && (float) $securiaceModernItem['qty'] > 0;
            $securiaceModernQuantity = $securiaceModernItemHasQuantity
                ? (float) $securiaceModernItem['qty']
                : 0;
            $securiaceModernRate = $securiaceModernItemHasQuantity
                ? $securiaceModernItemAmountNumeric / $securiaceModernQuantity
                : 0;
            $securiaceModernQuantityDisplay = $securiaceModernItemHasQuantity
                ? (floor($securiaceModernQuantity) == $securiaceModernQuantity
                    ? (string) (int) $securiaceModernQuantity
                    : rtrim(rtrim(number_format($securiaceModernQuantity, 3, '.', ''), '0'), '.'))
                : '—';
            $securiaceModernRateDisplay = $securiaceModernItemHasQuantity
                ? $securiaceModernFormatMoney($securiaceModernRate)
                : '—';
            $securiaceModernItemsHtml .= '<td width="9%" align="right">' . $securiaceModernEscape($securiaceModernQuantityDisplay) . '</td>'
                . '<td width="15%" align="right">' . $securiaceModernEscape($securiaceModernRateDisplay) . '</td>';
        }
        $securiaceModernItemsHtml .= '<td width="' . round(($securiaceModernAmountWidth / $securiaceModernUsableWidth) * 100, 2) . '%" align="right"><b>'
            . $securiaceModernEscape($securiaceModernItemAmountDisplay) . '</b></td></tr>';
    }
}
$securiaceModernItemsHtml .= '</tbody></table>';

$pdf->SetFont($securiaceModernFont, '', 8);
$pdf->writeHTML($securiaceModernItemsHtml, true, false, true, false, '');
$pdf->Ln(2);

// -------------------------------------------------------------------------
// Reconciliation and state-aware settlement
// -------------------------------------------------------------------------

$securiaceModernTotalRows = array(
    array('Subtotal', $securiaceModernSubtotalDisplay, false),
);
if ($securiaceModernDiscountNumeric > 0.00001) {
    $securiaceModernTotalRows[] = array('Discount', '− ' . $securiaceModernDiscountDisplay, false);
}
if ($securiaceModernTaxNumeric > 0.00001 || (isset($taxname) && trim((string) $taxname) !== '')) {
    $securiaceModernTaxLabel = isset($taxname) && trim((string) $taxname) !== ''
        ? trim((string) $taxname) . (isset($taxrate) && $taxrate !== '' ? ' · ' . $taxrate . '%' : '')
        : 'Tax';
    $securiaceModernTotalRows[] = array($securiaceModernTaxLabel, $securiaceModernTaxDisplay, false);
}
if ($securiaceModernTax2Numeric > 0.00001 || (isset($taxname2) && trim((string) $taxname2) !== '')) {
    $securiaceModernTax2Label = isset($taxname2) && trim((string) $taxname2) !== ''
        ? trim((string) $taxname2) . (isset($taxrate2) && $taxrate2 !== '' ? ' · ' . $taxrate2 . '%' : '')
        : 'Additional tax';
    $securiaceModernTotalRows[] = array($securiaceModernTax2Label, $securiaceModernTax2Display, false);
}
if ($securiaceModernCreditNumeric > 0.00001) {
    $securiaceModernTotalRows[] = array('Credit applied', '− ' . $securiaceModernCreditDisplay, false);
}
if (abs($securiaceModernReconciliationDeltaNumeric) > 0.01) {
    $securiaceModernAdjustmentDisplay = $securiaceModernFormatMoney(abs($securiaceModernReconciliationDeltaNumeric));
    $securiaceModernTotalRows[] = array(
        'Invoice adjustment',
        ($securiaceModernReconciliationDeltaNumeric < 0 ? '− ' : '+ ') . $securiaceModernAdjustmentDisplay,
        false
    );
}
$securiaceModernTotalRows[] = array('Grand total', $securiaceModernTotalDisplay, true);

if ($securiaceModernIsPaid) {
    $securiaceModernStateTotalLabel = 'Amount settled';
    $securiaceModernStateTotalDisplay = $securiaceModernTotalDisplay;
} elseif ($securiaceModernIsPayable) {
    $securiaceModernStateTotalLabel = 'Balance due';
    $securiaceModernStateTotalDisplay = $securiaceModernBalanceDisplay;
} elseif ($securiaceModernIsRefunded) {
    $securiaceModernStateTotalLabel = 'Refunded invoice total';
    $securiaceModernStateTotalDisplay = $securiaceModernTotalDisplay;
} else {
    $securiaceModernStateTotalLabel = 'Balance';
    $securiaceModernStateTotalDisplay = $securiaceModernBalanceDisplay;
}

$securiaceModernTotalsHeight = 8 + (count($securiaceModernTotalRows) * 6) + 7;
$securiaceModernEnsureSpace($securiaceModernTotalsHeight + 3);
$securiaceModernTotalsY = $pdf->GetY();
$securiaceModernTotalsWidth = min(82, $securiaceModernUsableWidth * 0.42);
$securiaceModernSettlementWidth = $securiaceModernUsableWidth - $securiaceModernTotalsWidth - 4;

$securiaceModernDrawCard(
    $securiaceModernMargin,
    $securiaceModernTotalsY,
    $securiaceModernSettlementWidth,
    $securiaceModernTotalsHeight,
    $securiaceModernStatusSoft,
    $securiaceModernStatusLine
);
$securiaceModernDrawLabel(
    $securiaceModernIsPaid ? 'Payment receipt' : ($securiaceModernIsPayable ? 'Payment required' : 'Invoice state'),
    $securiaceModernMargin + 4,
    $securiaceModernTotalsY + 3,
    $securiaceModernSettlementWidth - 8
);
$pdf->SetFont($securiaceModernFont, 'B', 10);
$pdf->SetTextColor($securiaceModernStatusInk[0], $securiaceModernStatusInk[1], $securiaceModernStatusInk[2]);
$pdf->SetXY($securiaceModernMargin + 4, $securiaceModernTotalsY + 8);

if ($securiaceModernIsPaid) {
    $securiaceModernSettlementHeading = 'Payment received in full';
    $securiaceModernSettlementBody = 'Settled'
        . (!empty($datepaid) ? ' on ' . $datepaid : '')
        . (!empty($securiaceModernTransactions[0]['gateway']) ? ' · ' . $securiaceModernTransactions[0]['gateway'] : '');
} elseif ($securiaceModernIsPayable) {
    $securiaceModernSettlementHeading = $securiaceModernBalanceDisplay . ' is due';
    $securiaceModernSettlementBody = 'Use invoice ' . $securiaceModernInvoiceNumber . ' as the payment reference.';
} elseif ($securiaceModernIsRefunded) {
    $securiaceModernSettlementHeading = 'Refund recorded';
    $securiaceModernSettlementBody = 'No payment action is required.';
} else {
    $securiaceModernSettlementHeading = ucfirst($securiaceModernStatusKey) . ' invoice';
    $securiaceModernSettlementBody = 'No payment action is available for this document state.';
}

$pdf->MultiCell($securiaceModernSettlementWidth - 8, 5, $securiaceModernSettlementHeading, 0, 'L');
$pdf->SetFont($securiaceModernFont, '', 7);
$pdf->SetTextColor($securiaceModernMuted[0], $securiaceModernMuted[1], $securiaceModernMuted[2]);
$pdf->SetX($securiaceModernMargin + 4);
$pdf->MultiCell($securiaceModernSettlementWidth - 8, 4, $securiaceModernSettlementBody, 0, 'L');
if ($securiaceModernSettlementMismatch) {
    $pdf->SetFont($securiaceModernFont, '', 6.5);
    $pdf->SetTextColor($securiaceModernStatusInk[0], $securiaceModernStatusInk[1], $securiaceModernStatusInk[2]);
    $pdf->SetX($securiaceModernMargin + 4);
    $pdf->MultiCell(
        $securiaceModernSettlementWidth - 8,
        3.5,
        'Settlement includes account credit or an administrative adjustment.',
        0,
        'L'
    );
}

$securiaceModernTotalsX = $securiaceModernMargin + $securiaceModernSettlementWidth + 4;
$securiaceModernDrawCard(
    $securiaceModernTotalsX,
    $securiaceModernTotalsY,
    $securiaceModernTotalsWidth,
    $securiaceModernTotalsHeight,
    $securiaceModernSurface,
    $securiaceModernLine
);
$securiaceModernTotalsRowY = $securiaceModernTotalsY + 3;
foreach ($securiaceModernTotalRows as $securiaceModernTotalRow) {
    if ($securiaceModernTotalRow[2]) {
        $pdf->SetDrawColor($securiaceModernLine[0], $securiaceModernLine[1], $securiaceModernLine[2]);
        $pdf->Line(
            $securiaceModernTotalsX + 3,
            $securiaceModernTotalsRowY,
            $securiaceModernTotalsX + $securiaceModernTotalsWidth - 3,
            $securiaceModernTotalsRowY
        );
        $securiaceModernTotalsRowY += 1.5;
    }
    $pdf->SetFont($securiaceModernFont, $securiaceModernTotalRow[2] ? 'B' : '', $securiaceModernTotalRow[2] ? 8 : 7);
    $pdf->SetTextColor($securiaceModernTotalRow[2] ? $securiaceModernInk[0] : $securiaceModernMuted[0], $securiaceModernTotalRow[2] ? $securiaceModernInk[1] : $securiaceModernMuted[1], $securiaceModernTotalRow[2] ? $securiaceModernInk[2] : $securiaceModernMuted[2]);
    $pdf->SetXY($securiaceModernTotalsX + 3, $securiaceModernTotalsRowY);
    $pdf->Cell($securiaceModernTotalsWidth * 0.48, 4, $securiaceModernTotalRow[0], 0, 0, 'L');
    $pdf->SetFont($securiaceModernFont, 'B', $securiaceModernTotalRow[2] ? 8 : 7);
    $pdf->SetTextColor($securiaceModernInk[0], $securiaceModernInk[1], $securiaceModernInk[2]);
    $pdf->Cell($securiaceModernTotalsWidth * 0.46, 4, $securiaceModernTotalRow[1], 0, 1, 'R');
    $securiaceModernTotalsRowY += 5.5;
}

$securiaceModernStateBarY = $securiaceModernTotalsY + $securiaceModernTotalsHeight - 7;
$pdf->SetFillColor($securiaceModernStatusInk[0], $securiaceModernStatusInk[1], $securiaceModernStatusInk[2]);
$pdf->Rect($securiaceModernTotalsX, $securiaceModernStateBarY, $securiaceModernTotalsWidth, 7, 'F');
$pdf->SetFont($securiaceModernFont, 'B', 7);
$pdf->SetTextColor(255, 255, 255);
$pdf->SetXY($securiaceModernTotalsX + 3, $securiaceModernStateBarY + 1.3);
$pdf->Cell($securiaceModernTotalsWidth * 0.48, 4, $securiaceModernStateTotalLabel, 0, 0, 'L');
$pdf->Cell($securiaceModernTotalsWidth * 0.46, 4, $securiaceModernStateTotalDisplay, 0, 1, 'R');
$pdf->SetY($securiaceModernTotalsY + $securiaceModernTotalsHeight + 4);

// -------------------------------------------------------------------------
// Terms, bank details, and status-aware payment/authorization panel
// -------------------------------------------------------------------------

$securiaceModernSupportHeight = 43;
$securiaceModernEnsureSpace($securiaceModernSupportHeight + 3);
$securiaceModernSupportY = $pdf->GetY();
$securiaceModernTermsWidth = $securiaceModernUsableWidth * 0.42;
$securiaceModernBankWidth = $securiaceModernUsableWidth * 0.31;
$securiaceModernActionWidth = $securiaceModernUsableWidth - $securiaceModernTermsWidth - $securiaceModernBankWidth - 6;
$securiaceModernBankX = $securiaceModernMargin + $securiaceModernTermsWidth + 3;
$securiaceModernActionX = $securiaceModernBankX + $securiaceModernBankWidth + 3;

$securiaceModernDrawCard($securiaceModernMargin, $securiaceModernSupportY, $securiaceModernTermsWidth, $securiaceModernSupportHeight, $securiaceModernSurface, $securiaceModernLine);
$securiaceModernDrawCard($securiaceModernBankX, $securiaceModernSupportY, $securiaceModernBankWidth, $securiaceModernSupportHeight, $securiaceModernSurface, $securiaceModernLine);
$securiaceModernDrawCard(
    $securiaceModernActionX,
    $securiaceModernSupportY,
    $securiaceModernActionWidth,
    $securiaceModernSupportHeight,
    $securiaceModernIsPayable ? $securiaceModernStatusSoft : $securiaceModernPaper,
    $securiaceModernIsPayable ? $securiaceModernStatusLine : $securiaceModernLine
);

$securiaceModernNotesText = isset($notes) ? trim((string) $notes) : '';
$securiaceModernNotesRenderedInTerms = $securiaceModernNotesText !== ''
    && strlen($securiaceModernNotesText) <= 220
    && substr_count($securiaceModernNotesText, "\n") <= 2;
$securiaceModernDrawLabel(
    $securiaceModernNotesRenderedInTerms ? 'Payment terms & notes' : 'Payment terms',
    $securiaceModernMargin + 3,
    $securiaceModernSupportY + 3,
    $securiaceModernTermsWidth - 6
);
$securiaceModernTerms = array();
if ($securiaceModernIsPayable && isset($duedate) && trim((string) $duedate) !== '') {
    $securiaceModernTerms[] = 'Payment is due by ' . trim((string) $duedate) . '.';
}
$securiaceModernTerms[] = 'Overdue interest may apply at ' . trim((string) $securiaceModernConfig['overdue_interest']) . '.';
if (trim((string) $securiaceModernConfig['tds_note']) !== '') {
    $securiaceModernTerms[] = trim((string) $securiaceModernConfig['tds_note']);
}
if (trim((string) $securiaceModernConfig['jurisdiction']) !== '') {
    $securiaceModernTerms[] = 'Jurisdiction: ' . trim((string) $securiaceModernConfig['jurisdiction']) . '.';
}
$securiaceModernTermsText = '';
foreach ($securiaceModernTerms as $securiaceModernTermIndex => $securiaceModernTerm) {
    $securiaceModernTermsText .= ($securiaceModernTermIndex + 1) . '. ' . $securiaceModernTerm . "\n";
}
if ($securiaceModernNotesRenderedInTerms) {
    $securiaceModernTermsText .= "\nNote · " . $securiaceModernNotesText;
}
$pdf->SetFont($securiaceModernFont, '', 6.5);
$pdf->SetTextColor($securiaceModernMuted[0], $securiaceModernMuted[1], $securiaceModernMuted[2]);
$pdf->SetXY($securiaceModernMargin + 3, $securiaceModernSupportY + 8);
$pdf->MultiCell($securiaceModernTermsWidth - 6, 3.5, trim($securiaceModernTermsText), 0, 'L');

$securiaceModernDrawLabel('Bank details', $securiaceModernBankX + 3, $securiaceModernSupportY + 3, $securiaceModernBankWidth - 6);
$securiaceModernBankRows = array(
    'Account' => $securiaceModernConfig['bank']['account_name'],
    'Number' => $securiaceModernConfig['bank']['account_number'],
    'IFSC' => $securiaceModernConfig['bank']['ifsc'],
    'Type' => $securiaceModernConfig['bank']['account_type'],
    'Bank' => $securiaceModernConfig['bank']['bank_name'],
);
$securiaceModernBankY = $securiaceModernSupportY + 8;
$securiaceModernHasBankDetails = false;
foreach ($securiaceModernBankRows as $securiaceModernBankLabel => $securiaceModernBankValue) {
    if (trim((string) $securiaceModernBankValue) === '') {
        continue;
    }
    $securiaceModernHasBankDetails = true;
    $pdf->SetFont($securiaceModernFont, '', 6);
    $pdf->SetTextColor($securiaceModernMuted[0], $securiaceModernMuted[1], $securiaceModernMuted[2]);
    $pdf->SetXY($securiaceModernBankX + 3, $securiaceModernBankY);
    $pdf->Cell($securiaceModernBankWidth * 0.32, 4, $securiaceModernBankLabel, 0, 0, 'L');
    $pdf->SetFont($securiaceModernFont, 'B', 6);
    $pdf->SetTextColor($securiaceModernInk[0], $securiaceModernInk[1], $securiaceModernInk[2]);
    $pdf->Cell($securiaceModernBankWidth * 0.58, 4, (string) $securiaceModernBankValue, 0, 1, 'R');
    $securiaceModernBankY += 5;
}
if (!$securiaceModernHasBankDetails) {
    $pdf->SetFont($securiaceModernFont, '', 6.5);
    $pdf->SetTextColor($securiaceModernMuted[0], $securiaceModernMuted[1], $securiaceModernMuted[2]);
    $pdf->SetXY($securiaceModernBankX + 3, $securiaceModernSupportY + 9);
    $pdf->MultiCell($securiaceModernBankWidth - 6, 3.5, 'Configure protected bank details before deployment.', 0, 'L');
}

$securiaceModernUpiId = trim((string) $securiaceModernConfig['upi_id']);
$securiaceModernCanUseUpi = $securiaceModernIsPayable
    && $securiaceModernCurrencyCode === 'INR'
    && $securiaceModernUpiId !== '';

if ($securiaceModernCanUseUpi && method_exists($pdf, 'write2DBarcode')) {
    $securiaceModernDrawLabel('UPI payment', $securiaceModernActionX + 3, $securiaceModernSupportY + 3, $securiaceModernActionWidth - 6);
    $securiaceModernUpiParams = array(
        'pa' => $securiaceModernUpiId,
        'pn' => $securiaceModernCompanyName,
        'am' => number_format($securiaceModernBalanceNumeric, 2, '.', ''),
        'cu' => 'INR',
        'tr' => 'Invoice-' . $securiaceModernInvoiceNumber,
        'tn' => 'Payment for invoice ' . $securiaceModernInvoiceNumber,
    );
    $securiaceModernUpiUri = 'upi://pay?' . http_build_query($securiaceModernUpiParams, '', '&', PHP_QUERY_RFC3986);
    $securiaceModernQrSize = min(25, $securiaceModernActionWidth - 8);
    $securiaceModernQrX = $securiaceModernActionX + ($securiaceModernActionWidth - $securiaceModernQrSize) / 2;
    $pdf->write2DBarcode(
        $securiaceModernUpiUri,
        'QRCODE,M',
        $securiaceModernQrX,
        $securiaceModernSupportY + 8,
        $securiaceModernQrSize,
        $securiaceModernQrSize,
        array('border' => false, 'padding' => 0, 'fgcolor' => array(32, 28, 36), 'bgcolor' => array(255, 255, 255)),
        'N'
    );
    $pdf->SetFont($securiaceModernFont, 'B', 5.8);
    $pdf->SetTextColor($securiaceModernStatusInk[0], $securiaceModernStatusInk[1], $securiaceModernStatusInk[2]);
    $pdf->SetXY($securiaceModernActionX + 2, $securiaceModernSupportY + 34);
    $pdf->Cell($securiaceModernActionWidth - 4, 3, $securiaceModernUpiId, 0, 1, 'C');
    $pdf->SetFont($securiaceModernFont, '', 5.5);
    $pdf->SetX($securiaceModernActionX + 2);
    $pdf->Cell($securiaceModernActionWidth - 4, 3, 'Ref · ' . $securiaceModernInvoiceNumber, 0, 1, 'C');
} elseif ($securiaceModernCanUseUpi) {
    $securiaceModernDrawLabel('UPI payment', $securiaceModernActionX + 3, $securiaceModernSupportY + 3, $securiaceModernActionWidth - 6);
    $pdf->SetFont($securiaceModernFont, 'B', 8);
    $pdf->SetTextColor($securiaceModernStatusInk[0], $securiaceModernStatusInk[1], $securiaceModernStatusInk[2]);
    $pdf->SetXY($securiaceModernActionX + 3, $securiaceModernSupportY + 10);
    $pdf->MultiCell($securiaceModernActionWidth - 6, 4, $securiaceModernUpiId, 0, 'L');
    $pdf->SetFont($securiaceModernFont, '', 6.5);
    $pdf->SetX($securiaceModernActionX + 3);
    $pdf->MultiCell(
        $securiaceModernActionWidth - 6,
        3.5,
        'Pay ' . $securiaceModernBalanceDisplay . ' using reference ' . $securiaceModernInvoiceNumber . '.',
        0,
        'L'
    );
} elseif ($securiaceModernIsPaid || $securiaceModernIsRefunded) {
    $securiaceModernDrawLabel('Authorization', $securiaceModernActionX + 3, $securiaceModernSupportY + 3, $securiaceModernActionWidth - 6);
    $securiaceModernStampPath = defined('ROOTDIR') ? ROOTDIR . '/assets/img/stamp.png' : '';
    $securiaceModernSignaturePath = defined('ROOTDIR') ? ROOTDIR . '/assets/img/sign.png' : '';
    $securiaceModernAuthY = $securiaceModernSupportY + 9;
    if ($securiaceModernIsUsableImage($securiaceModernStampPath)) {
        $pdf->Image($securiaceModernStampPath, $securiaceModernActionX + 3, $securiaceModernAuthY, 17, 17, '', '', '', false, 300);
    }
    if ($securiaceModernIsUsableImage($securiaceModernSignaturePath)) {
        $pdf->Image($securiaceModernSignaturePath, $securiaceModernActionX + 20, $securiaceModernAuthY, $securiaceModernActionWidth - 23, 14, '', '', '', false, 300);
    }
    $pdf->SetFont($securiaceModernFont, 'B', 6);
    $pdf->SetTextColor($securiaceModernInk[0], $securiaceModernInk[1], $securiaceModernInk[2]);
    $pdf->SetXY($securiaceModernActionX + 2, $securiaceModernSupportY + 29);
    $pdf->Cell($securiaceModernActionWidth - 4, 4, 'Authorized signature', 0, 1, 'C');
    $pdf->SetFont($securiaceModernFont, '', 5.8);
    $pdf->SetTextColor($securiaceModernMuted[0], $securiaceModernMuted[1], $securiaceModernMuted[2]);
    $pdf->SetX($securiaceModernActionX + 2);
    $pdf->MultiCell($securiaceModernActionWidth - 4, 3, 'No payment action required.', 0, 'C');
} else {
    $securiaceModernDrawLabel('Payment status', $securiaceModernActionX + 3, $securiaceModernSupportY + 3, $securiaceModernActionWidth - 6);
    $pdf->SetFont($securiaceModernFont, 'B', 8);
    $pdf->SetTextColor($securiaceModernStatusInk[0], $securiaceModernStatusInk[1], $securiaceModernStatusInk[2]);
    $pdf->SetXY($securiaceModernActionX + 3, $securiaceModernSupportY + 10);
    $pdf->MultiCell($securiaceModernActionWidth - 6, 4, 'No payment action required', 0, 'L');
}

$pdf->SetY($securiaceModernSupportY + $securiaceModernSupportHeight + 4);

// -------------------------------------------------------------------------
// Renewal and transaction records
// -------------------------------------------------------------------------

if ($securiaceModernIsPaid && !empty($securiaceModernRenewals)) {
    $securiaceModernEnsureSpace(16 + (count($securiaceModernRenewals) * 6));
    $securiaceModernDrawLabel('Upcoming renewals', $securiaceModernMargin, $pdf->GetY(), $securiaceModernUsableWidth);
    $pdf->SetY($pdf->GetY() + 4);
    foreach ($securiaceModernRenewals as $securiaceModernRenewal) {
        $pdf->SetFont($securiaceModernFont, 'B', 7);
        $pdf->SetTextColor($securiaceModernInk[0], $securiaceModernInk[1], $securiaceModernInk[2]);
        $pdf->SetX($securiaceModernMargin);
        $pdf->Cell($securiaceModernUsableWidth - 35, 5, $securiaceModernRenewal['description'], 'B', 0, 'L');
        $pdf->SetTextColor($securiaceModernBrand[0], $securiaceModernBrand[1], $securiaceModernBrand[2]);
        $pdf->Cell(35, 5, $securiaceModernRenewal['date'], 'B', 1, 'R');
    }
    $pdf->Ln(3);
}

$securiaceModernEnsureSpace(22 + (count($securiaceModernTransactions) * 7));
$securiaceModernDrawLabel('Payment transactions', $securiaceModernMargin, $pdf->GetY(), $securiaceModernUsableWidth);
$pdf->SetY($pdf->GetY() + 4);

$securiaceModernTransactionColumns = $securiaceModernHasTransactionStatus
    ? array(0.16, 0.20, 0.27, 0.22, 0.15)
    : array(0.18, 0.23, 0.31, 0.28);
$securiaceModernTransactionHeaders = $securiaceModernHasTransactionStatus
    ? array('Date', 'Method', 'Reference', 'Amount', 'Status')
    : array('Date', 'Method', 'Reference', 'Amount');

$pdf->SetFillColor($securiaceModernBrand[0], $securiaceModernBrand[1], $securiaceModernBrand[2]);
$pdf->SetTextColor(255, 255, 255);
$pdf->SetFont($securiaceModernFont, 'B', 6.5);
$securiaceModernDrawTransactionHeader = static function () use (
    $pdf,
    $securiaceModernFont,
    $securiaceModernBrand,
    $securiaceModernUsableWidth,
    $securiaceModernTransactionColumns,
    $securiaceModernTransactionHeaders
) {
    $pdf->SetFillColor($securiaceModernBrand[0], $securiaceModernBrand[1], $securiaceModernBrand[2]);
    $pdf->SetTextColor(255, 255, 255);
    $pdf->SetFont($securiaceModernFont, 'B', 6.5);
    foreach ($securiaceModernTransactionHeaders as $headerIndex => $transactionHeader) {
        $headerWidth = $securiaceModernUsableWidth * $securiaceModernTransactionColumns[$headerIndex];
        $pdf->Cell(
            $headerWidth,
            6,
            strtoupper($transactionHeader),
            0,
            $headerIndex === count($securiaceModernTransactionHeaders) - 1 ? 1 : 0,
            $transactionHeader === 'Amount' ? 'R' : 'L',
            true
        );
    }
};
$securiaceModernDrawTransactionHeader();

if (empty($securiaceModernTransactions)) {
    $pdf->SetFont($securiaceModernFont, '', 7);
    $pdf->SetTextColor($securiaceModernMuted[0], $securiaceModernMuted[1], $securiaceModernMuted[2]);
    $pdf->Cell($securiaceModernUsableWidth, 8, 'No payment transactions recorded.', 1, 1, 'C');
} else {
    foreach ($securiaceModernTransactions as $securiaceModernTransactionIndex => $securiaceModernTransaction) {
        if ($pdf->GetY() + 8 > $securiaceModernPageHeight - $securiaceModernBottomMargin) {
            $pdf->AddPage();
            $pdf->SetY($securiaceModernTopMargin);
            $securiaceModernDrawTransactionHeader();
        }
        $securiaceModernTransactionValues = array(
            isset($securiaceModernTransaction['date']) ? $securiaceModernTransaction['date'] : '—',
            isset($securiaceModernTransaction['gateway']) ? $securiaceModernTransaction['gateway'] : (isset($securiaceModernTransaction['paymentmethod']) ? $securiaceModernTransaction['paymentmethod'] : '—'),
            isset($securiaceModernTransaction['transid']) && trim((string) $securiaceModernTransaction['transid']) !== '' ? $securiaceModernTransaction['transid'] : '—',
            isset($securiaceModernTransaction['amount']) ? $securiaceModernTransaction['amount'] : $securiaceModernFormatMoney(0),
        );
        if ($securiaceModernHasTransactionStatus) {
            $securiaceModernTransactionValues[] = isset($securiaceModernTransaction['status']) ? $securiaceModernTransaction['status'] : '—';
        }
        $securiaceModernRowFill = $securiaceModernTransactionIndex % 2 === 0 ? $securiaceModernPaper : $securiaceModernSurface;
        $pdf->SetFillColor($securiaceModernRowFill[0], $securiaceModernRowFill[1], $securiaceModernRowFill[2]);
        $pdf->SetDrawColor($securiaceModernLine[0], $securiaceModernLine[1], $securiaceModernLine[2]);
        $pdf->SetFont($securiaceModernFont, '', 6.5);
        $pdf->SetTextColor($securiaceModernInk[0], $securiaceModernInk[1], $securiaceModernInk[2]);
        foreach ($securiaceModernTransactionValues as $securiaceModernValueIndex => $securiaceModernTransactionValue) {
            $securiaceModernValueWidth = $securiaceModernUsableWidth * $securiaceModernTransactionColumns[$securiaceModernValueIndex];
            $securiaceModernValueText = (string) $securiaceModernTransactionValue;
            $securiaceModernTransactionMaxLengths = array(18, 24, 30, 24, 16);
            $securiaceModernValueText = $securiaceModernTruncate(
                $securiaceModernValueText,
                $securiaceModernTransactionMaxLengths[$securiaceModernValueIndex]
            );
            $pdf->Cell(
                $securiaceModernValueWidth,
                7,
                $securiaceModernValueText,
                1,
                $securiaceModernValueIndex === count($securiaceModernTransactionValues) - 1 ? 1 : 0,
                $securiaceModernValueIndex === 3 ? 'R' : 'L',
                true
            );
        }
    }

    $pdf->SetFillColor($securiaceModernSurface[0], $securiaceModernSurface[1], $securiaceModernSurface[2]);
    $pdf->SetFont($securiaceModernFont, 'B', 7);
    $pdf->SetTextColor($securiaceModernInk[0], $securiaceModernInk[1], $securiaceModernInk[2]);
    $pdf->Cell($securiaceModernUsableWidth * 0.72, 7, 'Recorded transaction total', 1, 0, 'R', true);
    $pdf->Cell($securiaceModernUsableWidth * 0.28, 7, $securiaceModernFormatMoney($securiaceModernTransactionTotal), 1, 1, 'R', true);
}

if ($securiaceModernNotesText !== '' && !$securiaceModernNotesRenderedInTerms) {
    $securiaceModernEnsureSpace(18);
    $pdf->Ln(3);
    $securiaceModernDrawLabel('Invoice notes', $securiaceModernMargin, $pdf->GetY(), $securiaceModernUsableWidth);
    $pdf->SetY($pdf->GetY() + 4);
    $pdf->SetFont($securiaceModernFont, '', 7);
    $pdf->SetTextColor($securiaceModernMuted[0], $securiaceModernMuted[1], $securiaceModernMuted[2]);
    $pdf->MultiCell($securiaceModernUsableWidth, 4, $securiaceModernNotesText, 1, 'L', false, 1, '', '', true, 0, false, true);
}

// -------------------------------------------------------------------------
// Repeated page context and footer
// -------------------------------------------------------------------------

$securiaceModernGeneratedAt = function_exists('getTodaysDate')
    ? getTodaysDate(1)
    : date('j M Y');
$securiaceModernFinalPage = $pdf->getPage();
$securiaceModernPageCount = $pdf->getNumPages();
$securiaceModernPreviousAutoPageBreak = $pdf->getAutoPageBreak();
$securiaceModernPreviousBreakMargin = $pdf->getBreakMargin();
$pdf->SetAutoPageBreak(false, 0);

for ($securiaceModernPage = 1; $securiaceModernPage <= $securiaceModernPageCount; ++$securiaceModernPage) {
    $pdf->setPage($securiaceModernPage);
    // setPage() restores the page's original auto-break setting in TCPDF.
    // Disable it again so footer positioning cannot consume the next page or
    // append a blank page when drawing near the physical page edge.
    $pdf->SetAutoPageBreak(false, 0);
    if ($securiaceModernPage > 1) {
        $pdf->SetFont($securiaceModernFont, 'B', 7);
        $pdf->SetTextColor($securiaceModernBrand[0], $securiaceModernBrand[1], $securiaceModernBrand[2]);
        $pdf->SetXY($securiaceModernMargin, 8);
        $pdf->Cell($securiaceModernUsableWidth * 0.6, 4, $securiaceModernCompanyName, 0, 0, 'L');
        $pdf->SetTextColor($securiaceModernInk[0], $securiaceModernInk[1], $securiaceModernInk[2]);
        $pdf->Cell($securiaceModernUsableWidth * 0.4, 4, $securiaceModernDocumentTitle . ' · ' . $securiaceModernInvoiceNumber, 0, 1, 'R');
        $pdf->SetDrawColor($securiaceModernBrand[0], $securiaceModernBrand[1], $securiaceModernBrand[2]);
        $pdf->Line($securiaceModernMargin, 13, $securiaceModernPageWidth - $securiaceModernMargin, 13);
    }

    $pdf->SetFont($securiaceModernFont, '', 5.8);
    $pdf->SetTextColor($securiaceModernMuted[0], $securiaceModernMuted[1], $securiaceModernMuted[2]);
    $pdf->SetXY($securiaceModernMargin, $securiaceModernPageHeight - 10);
    $pdf->Cell($securiaceModernUsableWidth * 0.7, 4, 'Generated ' . $securiaceModernGeneratedAt . ' · ' . $securiaceModernCompanyName, 0, 0, 'L');
    $pdf->Cell($securiaceModernUsableWidth * 0.3, 4, 'Page ' . $securiaceModernPage . ' of ' . $securiaceModernPageCount, 0, 1, 'R');
}

$pdf->SetAutoPageBreak($securiaceModernPreviousAutoPageBreak, $securiaceModernPreviousBreakMargin);
$pdf->setPage($securiaceModernFinalPage);
