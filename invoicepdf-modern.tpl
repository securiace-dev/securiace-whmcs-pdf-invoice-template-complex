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

$securiaceModernModelCurrency = array();
if (isset($model) && is_object($model) && method_exists($model, 'getCurrency')) {
    try {
        $securiaceModernResolvedCurrency = $model->getCurrency();
        if (is_array($securiaceModernResolvedCurrency)) {
            $securiaceModernModelCurrency = $securiaceModernResolvedCurrency;
        }
    } catch (Throwable $securiaceModernCurrencyException) {
        // Payment actions fail closed below when currency cannot be confirmed.
        $securiaceModernModelCurrency = array();
    }
}

$securiaceModernCurrencyCode = '';
if (!empty($securiaceModernModelCurrency['code'])) {
    $securiaceModernCurrencyCode = strtoupper(trim((string) $securiaceModernModelCurrency['code']));
} elseif (isset($currencycode) && trim((string) $currencycode) !== '') {
    // Explicit variables are retained for third-party integrations and tests.
    $securiaceModernCurrencyCode = strtoupper(trim((string) $currencycode));
}

$securiaceModernCurrencyPrefix = !empty($securiaceModernModelCurrency['prefix'])
    ? trim((string) $securiaceModernModelCurrency['prefix'])
    : (isset($currencyprefix) ? trim((string) $currencyprefix) : '');
$securiaceModernCurrencySuffix = !empty($securiaceModernModelCurrency['suffix'])
    ? trim((string) $securiaceModernModelCurrency['suffix'])
    : (isset($currencysuffix) ? trim((string) $currencysuffix) : '');
$securiaceModernCurrencyFormat = isset($securiaceModernModelCurrency['format'])
    && is_numeric($securiaceModernModelCurrency['format'])
    ? (int) $securiaceModernModelCurrency['format']
    : ($securiaceModernInputCurrencyFormat > 0 ? $securiaceModernInputCurrencyFormat : 1);

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
    $text = (string) $value;
    $text = preg_replace('/<\s*br\s*\/?>/iu', "\n", $text);
    $text = preg_replace('/<\/(p|div|li|h[1-6])\s*>/iu', "\n", $text);
    $text = strip_tags($text);
    $text = html_entity_decode($text, ENT_QUOTES | ENT_HTML5, 'UTF-8');
    $text = preg_replace('/\s+/u', ' ', $text);
    return trim($text === null ? '' : $text);
};

$securiaceModernPlainMultiline = static function ($value) {
    $text = (string) $value;
    $text = preg_replace('/<\s*br\s*\/?>/iu', "\n", $text);
    $text = preg_replace('/<\/(p|div|li|h[1-6])\s*>/iu', "\n", $text);
    $text = strip_tags($text);
    $text = html_entity_decode($text, ENT_QUOTES | ENT_HTML5, 'UTF-8');
    $text = str_replace(array("\r\n", "\r"), "\n", $text);
    $lines = explode("\n", $text);
    $normalized = array();
    foreach ($lines as $line) {
        $line = preg_replace('/[\t ]+/u', ' ', $line);
        $line = trim($line === null ? '' : $line);
        if ($line !== '' || (!empty($normalized) && end($normalized) !== '')) {
            $normalized[] = $line;
        }
    }
    return trim(implode("\n", $normalized));
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
    $numericFormats = preg_match('/^\d{4}[\/-]/', $value)
        ? array('!Y-m-d', '!Y/m/d')
        : ($dateOrder === 'MDY'
            ? array('!m/d/Y', '!m-d-Y', '!d/m/Y', '!d-m-Y')
            : array('!d/m/Y', '!d-m-Y', '!m/d/Y', '!m-d-Y'));
    $formats = array_merge($numericFormats, array(
        '!j M Y',
        '!j M Y, H:i',
        '!d M Y',
        '!d M Y, H:i',
        '!j F Y',
        '!F j, Y',
        '!F jS, Y',
        '!l, F j, Y',
        '!l, F jS, Y',
        '!l, F j, Y H:i',
        '!l, F jS, Y H:i',
    ));

    foreach ($formats as $format) {
        $date = DateTimeImmutable::createFromFormat($format, $value);
        $errors = DateTimeImmutable::getLastErrors();
        if ($date !== false && ($errors === false || ($errors['warning_count'] === 0 && $errors['error_count'] === 0))) {
            return $date;
        }
    }

    return null;
};

$securiaceModernFormatDate = static function ($value) use ($securiaceModernParseDate) {
    $value = trim((string) $value);
    if ($value === '') {
        return '—';
    }

    $date = $securiaceModernParseDate($value);
    return $date instanceof DateTimeImmutable ? $date->format('j M Y') : $value;
};

// -------------------------------------------------------------------------
// WHMCS data normalization
// -------------------------------------------------------------------------

$securiaceModernFont = isset($pdfFont) && trim((string) $pdfFont) !== ''
    ? (string) $pdfFont
    : 'dejavusans';
$securiaceModernStatus = isset($status) ? trim((string) $status) : 'Draft';
$securiaceModernRawStatusKey = strtolower($securiaceModernStatus);
$securiaceModernStatusKey = $securiaceModernRawStatusKey;
$securiaceModernStatusDisplay = isset($statuslocale) && trim((string) $statuslocale) !== ''
    ? trim((string) $statuslocale)
    : $securiaceModernStatus;
$securiaceModernInvoiceId = isset($invoiceid) ? (string) $invoiceid : '';
$securiaceModernInvoiceNumber = isset($invoicenum) && trim((string) $invoicenum) !== ''
    ? trim((string) $invoicenum)
    : $securiaceModernInvoiceId;
if ($securiaceModernInvoiceNumber === '') {
    $securiaceModernInvoiceNumber = '—';
}

$securiaceModernPageTitle = isset($pagetitle) ? $securiaceModernPlainText($pagetitle) : '';
$securiaceModernIsProforma = stripos($securiaceModernPageTitle, 'proforma') !== false;
if (isset($model) && is_object($model) && method_exists($model, 'isProformaInvoice')) {
    try {
        $securiaceModernIsProforma = (bool) $model->isProformaInvoice();
    } catch (Throwable $securiaceModernProformaException) {
        // Keep the title-based fallback for integrations that expose a proxy model.
    }
} elseif (isset($isProformaInvoice)) {
    $securiaceModernIsProforma = (bool) $isProformaInvoice;
}
$securiaceModernProformaReference = $securiaceModernInvoiceId !== ''
    ? 'PI/' . $securiaceModernInvoiceId
    : $securiaceModernInvoiceNumber;
if ($securiaceModernIsProforma) {
    $securiaceModernInvoiceNumber = $securiaceModernProformaReference;
}
$securiaceModernDocumentTitle = $securiaceModernIsProforma ? 'Proforma Invoice' : 'Invoice';
$securiaceModernDocumentKicker = $securiaceModernIsProforma
    ? 'PROFORMA'
    : (isset($taxCode) && trim((string) $taxCode) !== '' ? 'TAX INVOICE' : 'INVOICE');

$securiaceModernItems = isset($invoiceitems) && is_array($invoiceitems) ? $invoiceitems : array();
$securiaceModernRawTransactions = isset($transactions) && is_array($transactions) ? $transactions : array();
$securiaceModernTransactions = array();
foreach ($securiaceModernRawTransactions as $securiaceModernRawTransaction) {
    if (!is_array($securiaceModernRawTransaction)) {
        continue;
    }
    $securiaceModernTransactionMethod = isset($securiaceModernRawTransaction['gateway'])
        ? trim((string) $securiaceModernRawTransaction['gateway'])
        : (isset($securiaceModernRawTransaction['paymentmethod'])
            ? trim((string) $securiaceModernRawTransaction['paymentmethod'])
            : '');
    $securiaceModernTransactionType = isset($securiaceModernRawTransaction['typeLabel'])
        ? trim((string) $securiaceModernRawTransaction['typeLabel'])
        : '';
    if ($securiaceModernTransactionType !== '') {
        $securiaceModernTransactionMethod .= ($securiaceModernTransactionMethod !== '' ? ' · ' : '')
            . $securiaceModernTransactionType;
    }
    $securiaceModernTransactionReference = '';
    if (isset($securiaceModernRawTransaction['referenceId'])) {
        $securiaceModernTransactionReference = trim((string) $securiaceModernRawTransaction['referenceId']);
    } elseif (isset($securiaceModernRawTransaction['transid'])) {
        $securiaceModernTransactionReference = trim((string) $securiaceModernRawTransaction['transid']);
    }
    if (!empty($securiaceModernRawTransaction['isCreditNote'])) {
        $securiaceModernTransactionReference = 'Credit note'
            . ($securiaceModernTransactionReference !== '' ? ' · ' . $securiaceModernTransactionReference : '');
    } elseif (!empty($securiaceModernRawTransaction['isDebitNote'])) {
        $securiaceModernTransactionReference = 'Debit note'
            . ($securiaceModernTransactionReference !== '' ? ' · ' . $securiaceModernTransactionReference : '');
    }
    $securiaceModernTransactions[] = array(
        'date' => isset($securiaceModernRawTransaction['date']) ? $securiaceModernRawTransaction['date'] : '',
        'gateway' => $securiaceModernTransactionMethod,
        'reference' => $securiaceModernTransactionReference,
        'amount' => isset($securiaceModernRawTransaction['amount']) ? $securiaceModernRawTransaction['amount'] : null,
        'status' => isset($securiaceModernRawTransaction['status']) ? $securiaceModernRawTransaction['status'] : '',
    );
}
$securiaceModernCoreQrHtml = isset($invoiceQrHtml) && is_string($invoiceQrHtml)
    ? trim($invoiceQrHtml)
    : '';
$securiaceModernCustomFields = isset($customfields) && is_array($customfields) ? $customfields : array();
if (!isset($clientsdetails) || !is_array($clientsdetails)) {
    $clientsdetails = array();
}

$securiaceModernSubtotalNumeric = isset($subtotal) ? $securiaceModernMoneyToFloat($subtotal) : 0.0;
$securiaceModernTaxNumeric = isset($tax) ? $securiaceModernMoneyToFloat($tax) : 0.0;
$securiaceModernTax2Numeric = isset($tax2) ? $securiaceModernMoneyToFloat($tax2) : 0.0;
$securiaceModernCreditNumeric = isset($credit) ? $securiaceModernMoneyToFloat($credit) : 0.0;
$securiaceModernDiscountNumeric = isset($discount) ? $securiaceModernMoneyToFloat($discount) : 0.0;
$securiaceModernTotalSource = isset($invoiceamount) && trim((string) $invoiceamount) !== ''
    ? $invoiceamount
    : (isset($total) ? $total : null);
$securiaceModernTotalNumeric = $securiaceModernMoneyToFloat($securiaceModernTotalSource);
$securiaceModernBalanceNumeric = isset($balance) ? $securiaceModernMoneyToFloat($balance) : 0.0;
$securiaceModernAmountPaidNumeric = isset($amountpaid)
    ? $securiaceModernMoneyToFloat($amountpaid)
    : max(0.0, $securiaceModernTotalNumeric - $securiaceModernBalanceNumeric);

$securiaceModernSubtotalDisplay = $securiaceModernDisplay(isset($subtotal) ? $subtotal : null, $securiaceModernSubtotalNumeric);
$securiaceModernTaxDisplay = $securiaceModernDisplay(isset($tax) ? $tax : null, $securiaceModernTaxNumeric);
$securiaceModernTax2Display = $securiaceModernDisplay(isset($tax2) ? $tax2 : null, $securiaceModernTax2Numeric);
$securiaceModernCreditDisplay = $securiaceModernDisplay(isset($credit) ? $credit : null, $securiaceModernCreditNumeric);
$securiaceModernDiscountDisplay = $securiaceModernDisplay(isset($discount) ? $discount : null, $securiaceModernDiscountNumeric);
$securiaceModernTotalDisplay = $securiaceModernDisplay($securiaceModernTotalSource, $securiaceModernTotalNumeric);
$securiaceModernBalanceDisplay = $securiaceModernDisplay(isset($balance) ? $balance : null, $securiaceModernBalanceNumeric);
$securiaceModernAmountPaidDisplay = $securiaceModernDisplay(
    isset($amountpaid) ? $amountpaid : null,
    $securiaceModernAmountPaidNumeric
);
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
$securiaceModernDueDate = isset($duedate) ? $securiaceModernParseDate($duedate) : null;
$securiaceModernIssueDateDisplay = isset($datecreated) ? $securiaceModernFormatDate($datecreated) : '—';
$securiaceModernDueDateDisplay = isset($duedate) ? $securiaceModernFormatDate($duedate) : '—';
$securiaceModernPaidDateDisplay = isset($datepaid) && trim((string) $datepaid) !== ''
    ? $securiaceModernFormatDate($datepaid)
    : '—';
$securiaceModernTodaySource = isset($securiaceInvoiceToday)
    ? (string) $securiaceInvoiceToday
    : date('Y-m-d');
$securiaceModernToday = $securiaceModernParseDate($securiaceModernTodaySource);
if (!$securiaceModernToday instanceof DateTimeImmutable) {
    $securiaceModernToday = new DateTimeImmutable('today');
}
$securiaceModernDaysOverdue = 0;
$securiaceModernIsOverdue = false;
if (in_array($securiaceModernRawStatusKey, array('unpaid', 'overdue'), true)
    && $securiaceModernIsPayable
    && $securiaceModernDueDate instanceof DateTimeImmutable
    && $securiaceModernDueDate < $securiaceModernToday
) {
    $securiaceModernIsOverdue = true;
    $securiaceModernDaysOverdue = (int) $securiaceModernDueDate->diff($securiaceModernToday)->format('%a');
    $securiaceModernStatusKey = 'overdue';
    $securiaceModernStatusDisplay = 'Overdue';
} elseif ($securiaceModernRawStatusKey === 'overdue') {
    $securiaceModernIsOverdue = true;
    $securiaceModernStatusKey = 'overdue';
    $securiaceModernStatusDisplay = 'Overdue';
}

// Standard WHMCS admin batch export runs through admin/csvdownload.php with
// type=pdfbatch but does not pass a template flag. Detect that exact request;
// tests/integrations may inject the same explicit profile without spoofing HTTP.
$securiaceModernRequestedProfile = isset($securiaceInvoiceRenderProfile)
    ? strtolower(trim((string) $securiaceInvoiceRenderProfile))
    : '';
$securiaceModernBatchRequestType = isset($GLOBALS['type'])
    ? strtolower(trim((string) $GLOBALS['type']))
    : (isset($_REQUEST['type']) ? strtolower(trim((string) $_REQUEST['type'])) : '');
$securiaceModernBatchScript = isset($_SERVER['SCRIPT_NAME'])
    ? strtolower(basename((string) $_SERVER['SCRIPT_NAME']))
    : '';
$securiaceModernIsBatch = $securiaceModernRequestedProfile === 'batch'
    || (defined('ADMINAREA')
        && ADMINAREA
        && $securiaceModernBatchRequestType === 'pdfbatch'
        && $securiaceModernBatchScript === 'csvdownload.php');
$securiaceModernRenderedCoreQr = false;
$securiaceModernRenderedSupport = false;
$securiaceModernRenderedRenewals = false;
$securiaceModernRenderedNotes = false;
$securiaceModernRenderedAuthorization = false;
$securiaceModernRenderedUpi = false;
$securiaceModernRenderedSettlement = false;

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
$securiaceModernBrandSoft = array(247, 239, 250);
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
$securiaceModernSellerRegistrations = array();
if (trim((string) $securiaceModernConfig['company_pan']) !== '') {
    $securiaceModernSellerRegistrations[] = 'PAN · ' . trim((string) $securiaceModernConfig['company_pan']);
}
if (trim((string) $securiaceModernConfig['company_msme']) !== '') {
    $securiaceModernSellerRegistrations[] = 'MSME · ' . trim((string) $securiaceModernConfig['company_msme']);
}
if (isset($taxCode) && trim((string) $taxCode) !== '') {
    $securiaceModernSellerRegistrations[] = (isset($taxIdLabel) && trim((string) $taxIdLabel) !== ''
        ? trim((string) $taxIdLabel)
        : 'Tax ID') . ' · ' . trim((string) $taxCode);
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
    && abs(($securiaceModernAmountPaidNumeric + $securiaceModernCreditNumeric) - $securiaceModernTotalNumeric) > 0.01;

$securiaceModernRenewals = array();
foreach ($securiaceModernItems as $securiaceModernItem) {
    $securiaceModernDescription = isset($securiaceModernItem['description'])
        ? $securiaceModernPlainMultiline($securiaceModernItem['description'])
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

$securiaceModernStartPage = $pdf->getPage();
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

$securiaceModernPaintPage = static function () use (
    $pdf,
    $securiaceModernPageWidth,
    $securiaceModernPageHeight,
    $securiaceModernPaper
) {
    $pdf->SetFillColor($securiaceModernPaper[0], $securiaceModernPaper[1], $securiaceModernPaper[2]);
    $pdf->Rect(0, 0, $securiaceModernPageWidth, $securiaceModernPageHeight, 'F');
};
$securiaceModernPaintPage();

$securiaceModernEnsureSpace = static function ($height) use (
    $pdf,
    $securiaceModernPageHeight,
    $securiaceModernBottomMargin,
    $securiaceModernTopMargin,
    $securiaceModernPaintPage
) {
    if ($pdf->GetY() + $height > $securiaceModernPageHeight - $securiaceModernBottomMargin) {
        $pdf->AddPage();
        $securiaceModernPaintPage();
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

$securiaceModernDrawCard = static function (
    $x,
    $y,
    $width,
    $height,
    $fill,
    $line,
    $radius = 2.65,
    $corners = '1111'
) use ($pdf) {
    $pdf->SetFillColor($fill[0], $fill[1], $fill[2]);
    $pdf->SetDrawColor($line[0], $line[1], $line[2]);
    $pdf->SetLineWidth(0.25);
    if (method_exists($pdf, 'RoundedRect')) {
        $pdf->RoundedRect($x, $y, $width, $height, min($radius, $height / 2), $corners, 'DF');
    } else {
        $pdf->Rect($x, $y, $width, $height, 'DF');
    }
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

$securiaceModernStatusLength = function_exists('mb_strlen')
    ? mb_strlen($securiaceModernStatusDisplay, 'UTF-8')
    : strlen($securiaceModernStatusDisplay);
$securiaceModernStatusWidth = max(28, min(52, $securiaceModernStatusLength * 2.2 + 12));
$securiaceModernStatusX = $securiaceModernPageWidth - $securiaceModernMargin - $securiaceModernStatusWidth;
$pdf->SetFillColor($securiaceModernStatusSoft[0], $securiaceModernStatusSoft[1], $securiaceModernStatusSoft[2]);
$pdf->SetDrawColor($securiaceModernStatusLine[0], $securiaceModernStatusLine[1], $securiaceModernStatusLine[2]);
if (method_exists($pdf, 'RoundedRect')) {
    $pdf->RoundedRect($securiaceModernStatusX, $securiaceModernHeaderY + 14, $securiaceModernStatusWidth, 7, 3.5, '1111', 'DF');
} else {
    $pdf->Rect($securiaceModernStatusX, $securiaceModernHeaderY + 14, $securiaceModernStatusWidth, 7, 'DF');
}
$pdf->SetFont($securiaceModernFont, 'B', 7);
$pdf->SetTextColor($securiaceModernStatusInk[0], $securiaceModernStatusInk[1], $securiaceModernStatusInk[2]);
$pdf->SetXY($securiaceModernStatusX, $securiaceModernHeaderY + 15.3);
$pdf->Cell($securiaceModernStatusWidth, 4, strtoupper($securiaceModernStatusDisplay), 0, 1, 'C');

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
$securiaceModernStatePanelX = $securiaceModernPageWidth - $securiaceModernMargin - 68;
$securiaceModernMetaAreaWidth = $securiaceModernStatePanelX - $securiaceModernMargin - 4;
$securiaceModernMetaColumnWidth = ($securiaceModernMetaAreaWidth - 4) / 2;
$securiaceModernMeta = array(
    array($securiaceModernIsProforma ? 'Proforma reference' : 'Invoice number', $securiaceModernInvoiceNumber),
    array('Issue date', $securiaceModernIssueDateDisplay),
);
if ($securiaceModernIsPaid && $securiaceModernInvoiceId !== '' && $securiaceModernInvoiceId !== $securiaceModernInvoiceNumber) {
    $securiaceModernMeta[] = array('Original proforma reference', $securiaceModernProformaReference);
} else {
    $securiaceModernMeta[] = array('Due date', $securiaceModernDueDateDisplay);
}

foreach ($securiaceModernMeta as $securiaceModernMetaIndex => $securiaceModernMetaItem) {
    $securiaceModernMetaIsSecondary = $securiaceModernMetaIndex === 2;
    $securiaceModernMetaX = $securiaceModernMetaIsSecondary
        ? $securiaceModernMargin
        : $securiaceModernMargin + ($securiaceModernMetaIndex * ($securiaceModernMetaColumnWidth + 4));
    $securiaceModernMetaItemWidth = $securiaceModernMetaIsSecondary
        ? $securiaceModernMetaAreaWidth
        : $securiaceModernMetaColumnWidth;
    $securiaceModernMetaItemY = $securiaceModernMetaY + ($securiaceModernMetaIsSecondary ? 9 : 0);
    $pdf->SetFont($securiaceModernFont, '', 6.2);
    $pdf->SetTextColor($securiaceModernMuted[0], $securiaceModernMuted[1], $securiaceModernMuted[2]);
    $pdf->SetXY($securiaceModernMetaX, $securiaceModernMetaItemY);
    $pdf->Cell($securiaceModernMetaItemWidth, 3, $securiaceModernMetaItem[0], 0, 1, 'L');
    $pdf->SetFont($securiaceModernFont, 'B', $securiaceModernMetaIsSecondary ? 7.2 : 8);
    $pdf->SetTextColor($securiaceModernInk[0], $securiaceModernInk[1], $securiaceModernInk[2]);
    $pdf->SetXY($securiaceModernMetaX, $securiaceModernMetaItemY + 3.2);
    $pdf->Cell($securiaceModernMetaItemWidth, 4, (string) $securiaceModernMetaItem[1], 0, 1, 'L', false, '', 1);
}

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

if ($securiaceModernIsBatch) {
    $pdf->Cell(60, 4, 'Batch accounting copy', 0, 1, 'L');
    $pdf->SetFont($securiaceModernFont, 'B', 8.5);
    $pdf->SetX($securiaceModernStatePanelX + 4);
    $pdf->Cell(60, 4.5, $securiaceModernStatusDisplay, 0, 1, 'L');
    $pdf->SetFont($securiaceModernFont, '', 6);
    $pdf->SetX($securiaceModernStatePanelX + 4);
    $pdf->Cell(60, 3.5, 'Invoice ' . $securiaceModernInvoiceNumber, 0, 1, 'L');
} elseif ($securiaceModernIsPaid) {
    $pdf->Cell(60, 4, $securiaceModernHasAuthenticatedVerification ? 'Authenticated invoice record' : 'Invoice checksum', 0, 1, 'L');
    $pdf->SetFont($securiaceModernFont, '', 6);
    $pdf->SetX($securiaceModernStatePanelX + 4);
    $pdf->Cell(60, 3.5, 'ID ' . $securiaceModernVerificationId, 0, 1, 'L');
    if ($securiaceModernHasAuthenticatedVerification && !empty($securiaceModernConfig['show_it_act_label'])) {
        $pdf->SetX($securiaceModernStatePanelX + 4);
        $pdf->Cell(60, 3.5, 'Electronic record · IT Act 2000', 0, 1, 'L');
    }
} elseif ($securiaceModernIsPayable) {
    $pdf->Cell(60, 4, $securiaceModernIsOverdue ? 'Overdue balance' : 'Balance due', 0, 1, 'L');
    $pdf->SetFont($securiaceModernFont, 'B', 10);
    $pdf->SetX($securiaceModernStatePanelX + 4);
    $pdf->Cell(60, 5, $securiaceModernBalanceDisplay, 0, 1, 'L');
    $pdf->SetFont($securiaceModernFont, '', 6);
    $pdf->SetX($securiaceModernStatePanelX + 4);
    $securiaceModernStateDeadline = $securiaceModernIsOverdue
        ? ($securiaceModernDaysOverdue > 0
            ? $securiaceModernDaysOverdue . ' day' . ($securiaceModernDaysOverdue === 1 ? '' : 's') . ' overdue · pay now'
            : 'Past due · pay now')
        : 'Pay by ' . $securiaceModernDueDateDisplay;
    $pdf->Cell(60, 3.5, $securiaceModernStateDeadline, 0, 1, 'L', false, '', 1);
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
$securiaceModernRegistrationRows = 0;
if (!empty($securiaceModernSellerRegistrations)) {
    $pdf->SetFont($securiaceModernFont, 'B', 5.8);
    $securiaceModernRegistrationRows = 1;
    $securiaceModernRegistrationLineWidth = 0.0;
    $securiaceModernRegistrationAvailableWidth = $securiaceModernPartyWidth - 8;
    foreach ($securiaceModernSellerRegistrations as $securiaceModernSellerRegistration) {
        $securiaceModernRegistrationWidth = min(
            $securiaceModernRegistrationAvailableWidth,
            $pdf->GetStringWidth($securiaceModernSellerRegistration) + 7
        );
        if ($securiaceModernRegistrationLineWidth > 0
            && $securiaceModernRegistrationLineWidth + 2 + $securiaceModernRegistrationWidth > $securiaceModernRegistrationAvailableWidth
        ) {
            ++$securiaceModernRegistrationRows;
            $securiaceModernRegistrationLineWidth = 0.0;
        }
        $securiaceModernRegistrationLineWidth += ($securiaceModernRegistrationLineWidth > 0 ? 2 : 0)
            + $securiaceModernRegistrationWidth;
    }
}
$securiaceModernRegistrationHeight = $securiaceModernRegistrationRows > 0
    ? 1 + ($securiaceModernRegistrationRows * 6)
    : 0;
$securiaceModernPartyHeight = max(
    35,
    16 + max($securiaceModernClientHeight, $securiaceModernSellerHeight + $securiaceModernRegistrationHeight)
);

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
$pdf->RoundedRect($securiaceModernMargin + 2.65, $securiaceModernPartyY, $securiaceModernPartyWidth - 5.3, 0.8, 0.4, '1111', 'F');

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
if (!empty($securiaceModernSellerRegistrations)) {
    $securiaceModernRegistrationCardX = $securiaceModernMargin
        + $securiaceModernPartyWidth
        + $securiaceModernPartyGap;
    $securiaceModernRegistrationX = $securiaceModernRegistrationCardX + 4;
    $securiaceModernRegistrationMaxX = $securiaceModernRegistrationCardX + $securiaceModernPartyWidth - 4;
    $securiaceModernRegistrationY = $securiaceModernPartyY
        + $securiaceModernPartyHeight
        - $securiaceModernRegistrationHeight;
    $pdf->SetFont($securiaceModernFont, 'B', 5.8);
    foreach ($securiaceModernSellerRegistrations as $securiaceModernSellerRegistration) {
        $securiaceModernRegistrationWidth = min(
            $securiaceModernPartyWidth - 8,
            $pdf->GetStringWidth($securiaceModernSellerRegistration) + 7
        );
        if ($securiaceModernRegistrationX > $securiaceModernRegistrationCardX + 4
            && $securiaceModernRegistrationX + $securiaceModernRegistrationWidth > $securiaceModernRegistrationMaxX
        ) {
            $securiaceModernRegistrationX = $securiaceModernRegistrationCardX + 4;
            $securiaceModernRegistrationY += 6;
        }
        $pdf->SetFillColor($securiaceModernBrandSoft[0], $securiaceModernBrandSoft[1], $securiaceModernBrandSoft[2]);
        if (method_exists($pdf, 'RoundedRect')) {
            $pdf->RoundedRect(
                $securiaceModernRegistrationX,
                $securiaceModernRegistrationY,
                $securiaceModernRegistrationWidth,
                5,
                1.4,
                '1111',
                'F'
            );
        } else {
            $pdf->Rect(
                $securiaceModernRegistrationX,
                $securiaceModernRegistrationY,
                $securiaceModernRegistrationWidth,
                5,
                'F'
            );
        }
        $pdf->SetTextColor($securiaceModernBrandDark[0], $securiaceModernBrandDark[1], $securiaceModernBrandDark[2]);
        $pdf->SetXY($securiaceModernRegistrationX + 2, $securiaceModernRegistrationY + 0.8);
        $pdf->Cell($securiaceModernRegistrationWidth - 4, 3.4, $securiaceModernSellerRegistration, 0, 0, 'L');
        $securiaceModernRegistrationX += $securiaceModernRegistrationWidth + 2;
    }
}
$pdf->SetY($securiaceModernPartyY + $securiaceModernPartyHeight + 5);

// WHMCS 9 may supply a core QR block, but its payload is outside this template's
// payment controls. It is intentionally suppressed. The only rendered QR is the
// amount-bound UPI payload below, for a payable INR invoice or proforma. A
// derived Overdue presentation remains an unpaid payment state.

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
$pdf->Cell(40, 4.5, 'Currency · ' . ($securiaceModernCurrencyCode !== '' ? $securiaceModernCurrencyCode : '—'), 0, 1, 'R');
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

$securiaceModernDrawItemsHeader = static function () use (
    $pdf,
    $securiaceModernFont,
    $securiaceModernMargin,
    $securiaceModernUsableWidth,
    $securiaceModernDescriptionWidth,
    $securiaceModernQtyWidth,
    $securiaceModernRateWidth,
    $securiaceModernAmountWidth,
    $securiaceModernHasExplicitQuantity,
    $securiaceModernBrand,
    $securiaceModernDrawCard
) {
    $headerY = $pdf->GetY();
    $securiaceModernDrawCard(
        $securiaceModernMargin,
        $headerY,
        $securiaceModernUsableWidth,
        7,
        $securiaceModernBrand,
        $securiaceModernBrand,
        2.65,
        '1001'
    );
    $pdf->SetFont($securiaceModernFont, 'B', 6.5);
    $pdf->SetTextColor(255, 255, 255);
    $pdf->SetXY($securiaceModernMargin + 3, $headerY + 1.4);
    $pdf->Cell($securiaceModernDescriptionWidth - 3, 4, 'DESCRIPTION', 0, 0, 'L');
    if ($securiaceModernHasExplicitQuantity) {
        $pdf->Cell($securiaceModernQtyWidth, 4, 'QTY', 0, 0, 'R');
        $pdf->Cell($securiaceModernRateWidth, 4, 'RATE', 0, 0, 'R');
    }
    $pdf->Cell($securiaceModernAmountWidth - 3, 4, 'AMOUNT', 0, 1, 'R');
    $pdf->SetY($headerY + 7);
};

$securiaceModernAddItemsContinuationPage = static function () use (
    $pdf,
    $securiaceModernPaintPage,
    $securiaceModernTopMargin,
    $securiaceModernMargin,
    $securiaceModernUsableWidth,
    $securiaceModernDrawLabel,
    $securiaceModernFont,
    $securiaceModernInk,
    $securiaceModernMuted,
    $securiaceModernCurrencyCode,
    $securiaceModernDrawItemsHeader
) {
    $pdf->AddPage();
    $securiaceModernPaintPage();
    $pdf->SetY($securiaceModernTopMargin);
    $securiaceModernDrawLabel('Charges · continued', $securiaceModernMargin, $pdf->GetY(), $securiaceModernUsableWidth);
    $pdf->SetFont($securiaceModernFont, 'B', 9);
    $pdf->SetTextColor($securiaceModernInk[0], $securiaceModernInk[1], $securiaceModernInk[2]);
    $pdf->SetXY($securiaceModernMargin, $pdf->GetY() + 3.5);
    $pdf->Cell($securiaceModernUsableWidth - 40, 4.5, 'Services and billing period', 0, 0, 'L');
    $pdf->SetFont($securiaceModernFont, 'B', 6);
    $pdf->SetTextColor($securiaceModernMuted[0], $securiaceModernMuted[1], $securiaceModernMuted[2]);
    $pdf->Cell(40, 4.5, 'Currency · ' . ($securiaceModernCurrencyCode !== '' ? $securiaceModernCurrencyCode : '—'), 0, 1, 'R');
    $pdf->Ln(1.5);
    $securiaceModernDrawItemsHeader();
};

$securiaceModernSplitTextForHeight = static function ($text, $width, $height) use ($pdf) {
    $text = trim((string) $text);
    if ($text === '' || $pdf->getStringHeight($width, $text) <= $height) {
        return array($text, '');
    }
    $length = function_exists('mb_strlen') ? mb_strlen($text, 'UTF-8') : strlen($text);
    $slice = static function ($value, $start, $size = null) {
        if (function_exists('mb_substr')) {
            return $size === null
                ? mb_substr($value, $start, null, 'UTF-8')
                : mb_substr($value, $start, $size, 'UTF-8');
        }
        return $size === null ? substr($value, $start) : substr($value, $start, $size);
    };
    $low = 1;
    $high = $length;
    $best = 1;
    while ($low <= $high) {
        $middle = (int) floor(($low + $high) / 2);
        $candidate = $slice($text, 0, $middle);
        if ($pdf->getStringHeight($width, $candidate) <= $height) {
            $best = $middle;
            $low = $middle + 1;
        } else {
            $high = $middle - 1;
        }
    }
    $candidate = $slice($text, 0, $best);
    if ($best < $length && preg_match('/^(.{1,' . max(1, $best) . '})[\s\n]/us', $text, $match)) {
        $breakLength = function_exists('mb_strlen') ? mb_strlen($match[1], 'UTF-8') : strlen($match[1]);
        if ($breakLength >= (int) floor($best * 0.55)) {
            $best = $breakLength;
            $candidate = $slice($text, 0, $best);
        }
    }
    return array(trim($candidate), ltrim($slice($text, $best)));
};

$securiaceModernRenderedItemDescriptions = array();
$securiaceModernPreparedItems = array();
foreach ($securiaceModernItems as $securiaceModernItem) {
    $itemDescription = isset($securiaceModernItem['description'])
        ? $securiaceModernPlainMultiline($securiaceModernItem['description'])
        : 'Invoice item';
    $securiaceModernRenderedItemDescriptions[] = $itemDescription;
    $descriptionParts = explode("\n", $itemDescription, 2);
    $itemAmountRaw = isset($securiaceModernItem['amount']) ? $securiaceModernItem['amount'] : 0;
    $itemAmountNumeric = $securiaceModernMoneyToFloat($itemAmountRaw);
    $itemHasQuantity = isset($securiaceModernItem['qty'])
        && is_numeric($securiaceModernItem['qty'])
        && (float) $securiaceModernItem['qty'] > 0;
    $quantity = $itemHasQuantity ? (float) $securiaceModernItem['qty'] : 0;
    $securiaceModernPreparedItems[] = array(
        'title' => $descriptionParts[0] !== '' ? $descriptionParts[0] : 'Invoice item',
        'detail' => isset($descriptionParts[1]) ? $descriptionParts[1] : '',
        'amount' => $securiaceModernDisplay($itemAmountRaw, $itemAmountNumeric),
        'quantity' => $itemHasQuantity
            ? (floor($quantity) == $quantity
                ? (string) (int) $quantity
                : rtrim(rtrim(number_format($quantity, 3, '.', ''), '0'), '.'))
            : '—',
        'rate' => $itemHasQuantity ? $securiaceModernFormatMoney($itemAmountNumeric / $quantity) : '—',
    );
}

$securiaceModernDrawItemsHeader();
if (empty($securiaceModernPreparedItems)) {
    $emptyY = $pdf->GetY();
    $securiaceModernDrawCard(
        $securiaceModernMargin,
        $emptyY,
        $securiaceModernUsableWidth,
        10,
        $securiaceModernPaper,
        $securiaceModernLine,
        2.65,
        '0110'
    );
    $pdf->SetFont($securiaceModernFont, '', 7);
    $pdf->SetTextColor($securiaceModernMuted[0], $securiaceModernMuted[1], $securiaceModernMuted[2]);
    $pdf->SetXY($securiaceModernMargin, $emptyY + 2.3);
    $pdf->Cell($securiaceModernUsableWidth, 4, 'No line items found.', 0, 1, 'C');
    $pdf->SetY($emptyY + 10);
} else {
    foreach ($securiaceModernPreparedItems as $itemIndex => $preparedItem) {
        $remainingDetail = $preparedItem['detail'];
        $firstSegment = true;
        do {
            if ($pdf->GetY() + 11 > $securiaceModernPageHeight - $securiaceModernBottomMargin) {
                $securiaceModernAddItemsContinuationPage();
            }
            $rowY = $pdf->GetY();
            $availableTextHeight = $securiaceModernPageHeight - $securiaceModernBottomMargin - $rowY - 4;
            $title = $firstSegment ? $preparedItem['title'] : $preparedItem['title'] . ' · continued';
            $pdf->SetFont($securiaceModernFont, 'B', 7.2);
            $titleHeight = max(3.5, $pdf->getStringHeight($securiaceModernDescriptionWidth - 6, $title));
            $detailHeightLimit = max(3.5, $availableTextHeight - $titleHeight);
            $pdf->SetFont($securiaceModernFont, '', 6.5);
            list($detailSegment, $remainingDetail) = $securiaceModernSplitTextForHeight(
                $remainingDetail,
                $securiaceModernDescriptionWidth - 6,
                $detailHeightLimit
            );
            $detailHeight = $detailSegment !== ''
                ? $pdf->getStringHeight($securiaceModernDescriptionWidth - 6, $detailSegment)
                : 0;
            $rowHeight = max(10, $titleHeight + $detailHeight + 4);
            $isFinalSegment = $remainingDetail === '';
            $isFinalRow = $isFinalSegment && $itemIndex === count($securiaceModernPreparedItems) - 1;
            $rowFill = $itemIndex % 2 === 0 ? $securiaceModernPaper : $securiaceModernSurface;
            $securiaceModernDrawCard(
                $securiaceModernMargin,
                $rowY,
                $securiaceModernUsableWidth,
                $rowHeight,
                $rowFill,
                $securiaceModernLine,
                2.65,
                $isFinalRow ? '0110' : '0000'
            );
            $pdf->SetFont($securiaceModernFont, 'B', 7.2);
            $pdf->SetTextColor($securiaceModernInk[0], $securiaceModernInk[1], $securiaceModernInk[2]);
            $pdf->SetXY($securiaceModernMargin + 3, $rowY + 2);
            $pdf->MultiCell($securiaceModernDescriptionWidth - 6, 3.5, $title, 0, 'L');
            if ($detailSegment !== '') {
                $pdf->SetFont($securiaceModernFont, '', 6.5);
                $pdf->SetTextColor($securiaceModernMuted[0], $securiaceModernMuted[1], $securiaceModernMuted[2]);
                $pdf->SetXY($securiaceModernMargin + 3, $rowY + 2 + $titleHeight);
                $pdf->MultiCell($securiaceModernDescriptionWidth - 6, 3.3, $detailSegment, 0, 'L');
            }
            $valueX = $securiaceModernMargin + $securiaceModernDescriptionWidth;
            $pdf->SetFont($securiaceModernFont, '', 6.8);
            $pdf->SetTextColor($securiaceModernInk[0], $securiaceModernInk[1], $securiaceModernInk[2]);
            $pdf->SetXY($valueX, $rowY + 2.3);
            if ($securiaceModernHasExplicitQuantity) {
                $pdf->Cell($securiaceModernQtyWidth, 4, $isFinalSegment ? $preparedItem['quantity'] : '—', 0, 0, 'R');
                $pdf->Cell($securiaceModernRateWidth, 4, $isFinalSegment ? $preparedItem['rate'] : '—', 0, 0, 'R');
            }
            $pdf->SetFont($securiaceModernFont, 'B', 7);
            $pdf->Cell($securiaceModernAmountWidth - 3, 4, $isFinalSegment ? $preparedItem['amount'] : '—', 0, 1, 'R');
            $pdf->SetY($rowY + $rowHeight);
            $firstSegment = false;
            if (!$isFinalSegment) {
                $securiaceModernAddItemsContinuationPage();
            }
        } while (!$isFinalSegment);
    }
}
$pdf->Ln(3);

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
    $securiaceModernStateTotalLabel = 'Amount paid';
    $securiaceModernStateTotalDisplay = $securiaceModernAmountPaidDisplay;
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

if (!$securiaceModernIsBatch) {
$securiaceModernRenderedSettlement = true;
$securiaceModernDrawCard(
    $securiaceModernMargin,
    $securiaceModernTotalsY,
    $securiaceModernSettlementWidth,
    $securiaceModernTotalsHeight,
    $securiaceModernStatusSoft,
    $securiaceModernStatusLine
);
$securiaceModernDrawLabel(
    $securiaceModernIsPaid
        ? 'Payment receipt'
        : ($securiaceModernIsOverdue ? 'Overdue payment' : ($securiaceModernIsPayable ? 'Payment required' : 'Invoice state')),
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
        . ($securiaceModernPaidDateDisplay !== '—' ? ' on ' . $securiaceModernPaidDateDisplay : '')
        . '. See transaction history for the payment method.';
    if ($securiaceModernSettlementMismatch) {
        $securiaceModernSettlementBody .= "\nIncludes account credit or an administrative adjustment.";
    }
} elseif ($securiaceModernIsPayable) {
    $securiaceModernSettlementHeading = $securiaceModernBalanceDisplay
        . ($securiaceModernIsOverdue ? ' is overdue' : ' is due');
    $securiaceModernSettlementBody = ($securiaceModernIsOverdue ? 'Pay immediately. ' : '')
        . 'Use ' . ($securiaceModernIsProforma ? 'proforma ' : 'invoice ')
        . $securiaceModernInvoiceNumber . ' as the payment reference.';
} elseif ($securiaceModernIsRefunded) {
    $securiaceModernSettlementHeading = 'Refund recorded';
    $securiaceModernSettlementBody = 'No payment action is required.';
} else {
    $securiaceModernSettlementHeading = ucfirst($securiaceModernStatusKey) . ' invoice';
    $securiaceModernSettlementBody = 'No payment action is available for this document state.';
}

$securiaceModernReceiptCopyWidth = $securiaceModernIsPaid && !$securiaceModernIsBatch
    ? max(48, $securiaceModernSettlementWidth - 48)
    : $securiaceModernSettlementWidth - 8;
$pdf->MultiCell($securiaceModernReceiptCopyWidth, 5, $securiaceModernSettlementHeading, 0, 'L');
$pdf->SetFont($securiaceModernFont, '', 7);
$pdf->SetTextColor($securiaceModernMuted[0], $securiaceModernMuted[1], $securiaceModernMuted[2]);
$pdf->SetX($securiaceModernMargin + 4);
$pdf->MultiCell($securiaceModernReceiptCopyWidth, 4, $securiaceModernSettlementBody, 0, 'L');
if ($securiaceModernIsPaid) {
    $securiaceModernReceiptReference = !empty($securiaceModernTransactions[0]['reference'])
        ? $securiaceModernTransactions[0]['reference']
        : '—';
    $securiaceModernReceiptMetaY = min(
        $securiaceModernTotalsY + $securiaceModernTotalsHeight - 8,
        max($pdf->GetY() + 1, $securiaceModernTotalsY + 20)
    );
    $pdf->SetFont($securiaceModernFont, '', 5.8);
    $pdf->SetTextColor($securiaceModernMuted[0], $securiaceModernMuted[1], $securiaceModernMuted[2]);
    $pdf->SetXY($securiaceModernMargin + 4, $securiaceModernReceiptMetaY);
    $securiaceModernReceiptReferenceWidth = ($securiaceModernReceiptCopyWidth * 0.62) - 2;
    $securiaceModernReceiptBalanceWidth = ($securiaceModernReceiptCopyWidth * 0.38);
    $pdf->Cell($securiaceModernReceiptReferenceWidth, 3, 'REFERENCE', 0, 0, 'L');
    $pdf->Cell(2, 3, '', 0, 0, 'L');
    $pdf->Cell($securiaceModernReceiptBalanceWidth, 3, 'BALANCE', 0, 1, 'L');
    $pdf->SetFont($securiaceModernFont, 'B', 5.8);
    $pdf->SetTextColor($securiaceModernInk[0], $securiaceModernInk[1], $securiaceModernInk[2]);
    $pdf->SetX($securiaceModernMargin + 4);
    $pdf->Cell(
        $securiaceModernReceiptReferenceWidth,
        3.5,
        $securiaceModernTruncate($securiaceModernReceiptReference, 17),
        0,
        0,
        'L'
    );
    $pdf->Cell(2, 3.5, '', 0, 0, 'L');
    $pdf->Cell($securiaceModernReceiptBalanceWidth, 3.5, $securiaceModernBalanceDisplay, 0, 1, 'L');

    if (!$securiaceModernIsBatch) {
        $securiaceModernRenderedAuthorization = true;
        $securiaceModernStampPath = defined('ROOTDIR') ? ROOTDIR . '/assets/img/stamp.png' : '';
        $securiaceModernSignaturePath = defined('ROOTDIR') ? ROOTDIR . '/assets/img/sign.png' : '';
        $securiaceModernAuthorizationX = $securiaceModernMargin + $securiaceModernSettlementWidth - 42;
        $securiaceModernAuthorizationY = $securiaceModernTotalsY + 9;
        if ($securiaceModernIsUsableImage($securiaceModernStampPath)) {
            $pdf->Image($securiaceModernStampPath, $securiaceModernAuthorizationX, $securiaceModernAuthorizationY, 16, 16, '', '', '', false, 300);
        }
        if ($securiaceModernIsUsableImage($securiaceModernSignaturePath)) {
            $pdf->Image($securiaceModernSignaturePath, $securiaceModernAuthorizationX + 16, $securiaceModernAuthorizationY + 2, 22, 10, '', '', '', false, 300);
        }
        $pdf->SetFont($securiaceModernFont, '', 5.5);
        $pdf->SetTextColor($securiaceModernMuted[0], $securiaceModernMuted[1], $securiaceModernMuted[2]);
        $pdf->SetXY($securiaceModernAuthorizationX + 14, $securiaceModernAuthorizationY + 14);
        $pdf->Cell(25, 3, 'Authorized signature', 0, 1, 'R');
    }
}
}
$securiaceModernTotalsX = $securiaceModernIsBatch
    ? $securiaceModernPageWidth - $securiaceModernMargin - $securiaceModernTotalsWidth
    : $securiaceModernMargin + $securiaceModernSettlementWidth + 4;
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
if (method_exists($pdf, 'RoundedRect')) {
    $pdf->RoundedRect($securiaceModernTotalsX, $securiaceModernStateBarY, $securiaceModernTotalsWidth, 7, 2.65, '0110', 'F');
} else {
    $pdf->Rect($securiaceModernTotalsX, $securiaceModernStateBarY, $securiaceModernTotalsWidth, 7, 'F');
}
$pdf->SetFont($securiaceModernFont, 'B', 7);
$pdf->SetTextColor(255, 255, 255);
$pdf->SetXY($securiaceModernTotalsX + 3, $securiaceModernStateBarY + 1.3);
$pdf->Cell($securiaceModernTotalsWidth * 0.48, 4, $securiaceModernStateTotalLabel, 0, 0, 'L');
$pdf->Cell($securiaceModernTotalsWidth * 0.46, 4, $securiaceModernStateTotalDisplay, 0, 1, 'R');
$pdf->SetY($securiaceModernTotalsY + $securiaceModernTotalsHeight + 4);

// -------------------------------------------------------------------------
// Terms, bank details, and status-aware payment/authorization panel
// -------------------------------------------------------------------------

$securiaceModernNotesText = isset($notes) ? trim((string) $notes) : '';
$securiaceModernNotesRenderedInTerms = $securiaceModernIsBatch
    || ($securiaceModernNotesText !== ''
        && strlen($securiaceModernNotesText) <= 220
        && substr_count($securiaceModernNotesText, "\n") <= 2);
$securiaceModernUpiId = trim((string) $securiaceModernConfig['upi_id']);
$securiaceModernCanUseUpi = !$securiaceModernIsBatch
    && in_array($securiaceModernStatusKey, array('unpaid', 'overdue'), true)
    && $securiaceModernIsPayable
    && $securiaceModernCurrencyCode === 'INR'
    && $securiaceModernUpiId !== '';

if (!$securiaceModernIsBatch && $securiaceModernIsPayable) {
$securiaceModernRenderedSupport = true;
if ($securiaceModernNotesRenderedInTerms && $securiaceModernNotesText !== '') {
    $securiaceModernRenderedNotes = true;
}
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

$securiaceModernDrawLabel(
    $securiaceModernNotesRenderedInTerms ? 'Payment terms & notes' : 'Payment terms',
    $securiaceModernMargin + 3,
    $securiaceModernSupportY + 3,
    $securiaceModernTermsWidth - 6
);
$securiaceModernTerms = array();
if ($securiaceModernIsOverdue) {
    $securiaceModernTerms[] = 'Payment was due on ' . $securiaceModernDueDateDisplay . ' and is now overdue.';
} elseif ($securiaceModernIsPayable && $securiaceModernDueDateDisplay !== '—') {
    $securiaceModernTerms[] = 'Payment is due by ' . $securiaceModernDueDateDisplay . '.';
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

if ($securiaceModernCanUseUpi && method_exists($pdf, 'write2DBarcode')) {
    $securiaceModernRenderedUpi = true;
    $securiaceModernDrawLabel('UPI payment', $securiaceModernActionX + 3, $securiaceModernSupportY + 3, $securiaceModernActionWidth - 6);
    $securiaceModernUpiParams = array(
        'pa' => $securiaceModernUpiId,
        'pn' => $securiaceModernCompanyName,
        'am' => number_format($securiaceModernBalanceNumeric, 2, '.', ''),
        'cu' => 'INR',
        'tr' => $securiaceModernInvoiceNumber,
        'tn' => 'Payment for ' . ($securiaceModernIsProforma ? 'proforma ' : 'invoice ') . $securiaceModernInvoiceNumber,
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
    $securiaceModernRenderedUpi = true;
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
} else {
    $securiaceModernDrawLabel('Payment options', $securiaceModernActionX + 3, $securiaceModernSupportY + 3, $securiaceModernActionWidth - 6);
    $pdf->SetFont($securiaceModernFont, 'B', 7.5);
    $pdf->SetTextColor($securiaceModernStatusInk[0], $securiaceModernStatusInk[1], $securiaceModernStatusInk[2]);
    $pdf->SetXY($securiaceModernActionX + 3, $securiaceModernSupportY + 9);
    $pdf->MultiCell(
        $securiaceModernActionWidth - 6,
        4,
        $securiaceModernHasBankDetails ? 'Pay by bank transfer' : 'Payment instructions',
        0,
        'L'
    );
    $pdf->SetFont($securiaceModernFont, '', 6.2);
    $pdf->SetTextColor($securiaceModernMuted[0], $securiaceModernMuted[1], $securiaceModernMuted[2]);
    $pdf->SetX($securiaceModernActionX + 3);
    $pdf->MultiCell(
        $securiaceModernActionWidth - 6,
        3.4,
        $securiaceModernHasBankDetails
            ? 'Use the bank details and reference ' . $securiaceModernInvoiceNumber . '.'
            : 'Contact billing for payment instructions and quote reference ' . $securiaceModernInvoiceNumber . '.',
        0,
        'L'
    );
}

$pdf->SetY($securiaceModernSupportY + $securiaceModernSupportHeight + 4);
}

// -------------------------------------------------------------------------
// Renewal and transaction records
// -------------------------------------------------------------------------

if (!$securiaceModernIsBatch && $securiaceModernIsPaid && !empty($securiaceModernRenewals)) {
    $securiaceModernRenderedRenewals = true;
    $securiaceModernEnsureSpace(16 + (count($securiaceModernRenewals) * 13));
    $securiaceModernDrawLabel('Upcoming renewals', $securiaceModernMargin, $pdf->GetY(), $securiaceModernUsableWidth);
    $pdf->SetY($pdf->GetY() + 4);
    foreach ($securiaceModernRenewals as $securiaceModernRenewalIndex => $securiaceModernRenewal) {
        $renewalY = $pdf->GetY();
        $renewalFill = $securiaceModernRenewalIndex % 2 === 0 ? $securiaceModernPaper : $securiaceModernSurface;
        $securiaceModernDrawCard(
            $securiaceModernMargin,
            $renewalY,
            $securiaceModernUsableWidth,
            10,
            $renewalFill,
            $securiaceModernLine,
            2.2
        );
        $pdf->SetFont($securiaceModernFont, 'B', 6.8);
        $pdf->SetTextColor($securiaceModernInk[0], $securiaceModernInk[1], $securiaceModernInk[2]);
        $pdf->SetXY($securiaceModernMargin + 3, $renewalY + 1.8);
        $pdf->Cell(
            $securiaceModernUsableWidth - 50,
            3.5,
            $securiaceModernTruncate($securiaceModernRenewal['description'], 82),
            0,
            0,
            'L'
        );
        $pdf->SetTextColor($securiaceModernBrand[0], $securiaceModernBrand[1], $securiaceModernBrand[2]);
        $pdf->Cell(44, 3.5, $securiaceModernRenewal['date'], 0, 1, 'R');
        $pdf->SetFont($securiaceModernFont, '', 5.8);
        $pdf->SetTextColor($securiaceModernMuted[0], $securiaceModernMuted[1], $securiaceModernMuted[2]);
        $pdf->SetXY($securiaceModernMargin + 3, $renewalY + 5.3);
        $pdf->Cell($securiaceModernUsableWidth - 50, 3, 'Service renewal schedule', 0, 0, 'L');
        $pdf->Cell(44, 3, 'Scheduled', 0, 1, 'R');
        $pdf->SetY($renewalY + 12);
    }
}

$securiaceModernEnsureSpace(22 + (min(2, count($securiaceModernTransactions)) * 14));
$securiaceModernTransactionColumns = $securiaceModernHasTransactionStatus
    ? array(0.15, 0.24, 0.25, 0.21, 0.15)
    : array(0.16, 0.29, 0.28, 0.27);
$securiaceModernTransactionHeaders = $securiaceModernHasTransactionStatus
    ? array('Date', 'Method', 'Reference', 'Amount', 'Status')
    : array('Date', 'Method', 'Reference', 'Amount');

$securiaceModernDrawTransactionHeading = static function ($continued = false) use (
    $pdf,
    $securiaceModernDrawLabel,
    $securiaceModernMargin,
    $securiaceModernUsableWidth,
    $securiaceModernFont,
    $securiaceModernInk,
    $securiaceModernMuted,
    $securiaceModernTransactionHeaders,
    $securiaceModernTransactionColumns,
    $securiaceModernTransactions
) {
    $headingY = $pdf->GetY();
    $securiaceModernDrawLabel(
        $continued ? 'Payment transactions · continued' : 'Payment transactions',
        $securiaceModernMargin,
        $headingY,
        $securiaceModernUsableWidth
    );
    $pdf->SetFont($securiaceModernFont, 'B', 9);
    $pdf->SetTextColor($securiaceModernInk[0], $securiaceModernInk[1], $securiaceModernInk[2]);
    $pdf->SetXY($securiaceModernMargin, $headingY + 3.5);
    $pdf->Cell($securiaceModernUsableWidth * 0.7, 4.5, 'Transaction history', 0, 0, 'L');
    $pdf->SetFont($securiaceModernFont, 'B', 6);
    $pdf->SetTextColor($securiaceModernMuted[0], $securiaceModernMuted[1], $securiaceModernMuted[2]);
    $recordLabel = count($securiaceModernTransactions) . (count($securiaceModernTransactions) === 1 ? ' record' : ' records');
    $pdf->Cell($securiaceModernUsableWidth * 0.3, 4.5, $recordLabel, 0, 1, 'R');
    $pdf->SetY($headingY + 9);
    $pdf->SetFont($securiaceModernFont, 'B', 5.7);
    $pdf->SetTextColor($securiaceModernMuted[0], $securiaceModernMuted[1], $securiaceModernMuted[2]);
    foreach ($securiaceModernTransactionHeaders as $headerIndex => $transactionHeader) {
        $headerWidth = $securiaceModernUsableWidth * $securiaceModernTransactionColumns[$headerIndex];
        $pdf->Cell(
            $headerWidth,
            4,
            strtoupper($transactionHeader),
            0,
            $headerIndex === count($securiaceModernTransactionHeaders) - 1 ? 1 : 0,
            $transactionHeader === 'Amount' ? 'R' : 'L'
        );
    }
};
$securiaceModernDrawTransactionHeading();

if (empty($securiaceModernTransactions)) {
    $emptyTransactionY = $pdf->GetY();
    $securiaceModernDrawCard(
        $securiaceModernMargin,
        $emptyTransactionY,
        $securiaceModernUsableWidth,
        10,
        $securiaceModernSurface,
        $securiaceModernLine
    );
    $pdf->SetFont($securiaceModernFont, '', 7);
    $pdf->SetTextColor($securiaceModernMuted[0], $securiaceModernMuted[1], $securiaceModernMuted[2]);
    $pdf->SetXY($securiaceModernMargin + 3, $emptyTransactionY + 2.4);
    $pdf->Cell($securiaceModernUsableWidth - 6, 4, 'No payment transactions recorded yet.', 0, 1, 'L');
    $pdf->SetY($emptyTransactionY + 10);
} else {
    foreach ($securiaceModernTransactions as $securiaceModernTransactionIndex => $securiaceModernTransaction) {
        $transactionValues = array(
            isset($securiaceModernTransaction['date'])
                ? $securiaceModernFormatDate($securiaceModernTransaction['date'])
                : '—',
            isset($securiaceModernTransaction['gateway']) && trim((string) $securiaceModernTransaction['gateway']) !== '' ? $securiaceModernTransaction['gateway'] : '—',
            isset($securiaceModernTransaction['reference']) && trim((string) $securiaceModernTransaction['reference']) !== '' ? $securiaceModernTransaction['reference'] : '—',
            isset($securiaceModernTransaction['amount']) ? $securiaceModernTransaction['amount'] : $securiaceModernFormatMoney(0),
        );
        if ($securiaceModernHasTransactionStatus) {
            $transactionValues[] = isset($securiaceModernTransaction['status']) && trim((string) $securiaceModernTransaction['status']) !== ''
                ? $securiaceModernTransaction['status']
                : '—';
        }

        $pdf->SetFont($securiaceModernFont, '', 6.3);
        $securiaceModernTransactionRowHeight = 10.0;
        foreach ($transactionValues as $valueIndex => $transactionValue) {
            $valueWidth = ($securiaceModernUsableWidth * $securiaceModernTransactionColumns[$valueIndex]) - 5;
            $valueText = $securiaceModernTruncate((string) $transactionValue, 72);
            $securiaceModernTransactionRowHeight = max(
                $securiaceModernTransactionRowHeight,
                min(18, $pdf->getStringHeight($valueWidth, $valueText) + 5)
            );
        }
        if ($pdf->GetY() + $securiaceModernTransactionRowHeight + 2 > $securiaceModernPageHeight - $securiaceModernBottomMargin) {
            $pdf->AddPage();
            $securiaceModernPaintPage();
            $pdf->SetY($securiaceModernTopMargin);
            $securiaceModernDrawTransactionHeading(true);
        }
        $transactionY = $pdf->GetY();
        $transactionFill = $securiaceModernTransactionIndex % 2 === 0 ? $securiaceModernPaper : $securiaceModernSurface;
        $securiaceModernDrawCard(
            $securiaceModernMargin,
            $transactionY,
            $securiaceModernUsableWidth,
            $securiaceModernTransactionRowHeight,
            $transactionFill,
            $securiaceModernLine,
            2.2
        );
        $pdf->SetFont($securiaceModernFont, '', 6.3);
        $pdf->SetTextColor($securiaceModernInk[0], $securiaceModernInk[1], $securiaceModernInk[2]);
        $securiaceModernTransactionCellX = $securiaceModernMargin + 2.5;
        foreach ($transactionValues as $valueIndex => $transactionValue) {
            $valueWidth = $securiaceModernUsableWidth * $securiaceModernTransactionColumns[$valueIndex];
            $valueText = $securiaceModernTruncate((string) $transactionValue, 72);
            $pdf->SetXY($securiaceModernTransactionCellX, $transactionY + 2.3);
            $pdf->MultiCell(
                $valueWidth - 5,
                3.2,
                $valueText,
                0,
                $valueIndex === 3 ? 'R' : 'L',
                false,
                0,
                '',
                '',
                true,
                0,
                false,
                true,
                $securiaceModernTransactionRowHeight - 4.5,
                'T'
            );
            $securiaceModernTransactionCellX += $valueWidth;
        }
        $pdf->SetY($transactionY + $securiaceModernTransactionRowHeight + 2);
    }

    $pdf->SetFont($securiaceModernFont, 'B', 6.6);
    $pdf->SetTextColor($securiaceModernMuted[0], $securiaceModernMuted[1], $securiaceModernMuted[2]);
    $pdf->Cell($securiaceModernUsableWidth * 0.72, 5, 'Recorded transaction total', 0, 0, 'R');
    $pdf->SetTextColor($securiaceModernInk[0], $securiaceModernInk[1], $securiaceModernInk[2]);
    $pdf->Cell($securiaceModernUsableWidth * 0.28, 5, $securiaceModernFormatMoney($securiaceModernTransactionTotal), 0, 1, 'R');
}

if (!$securiaceModernIsBatch && $securiaceModernNotesText !== '' && !$securiaceModernNotesRenderedInTerms) {
    $securiaceModernRenderedNotes = true;
    $pdf->SetFont($securiaceModernFont, '', 7);
    $securiaceModernNotesHeight = max(
        14,
        $pdf->getStringHeight($securiaceModernUsableWidth - 8, $securiaceModernNotesText) + 10
    );
    $securiaceModernEnsureSpace($securiaceModernNotesHeight + 4);
    $pdf->Ln(3);
    $securiaceModernNotesY = $pdf->GetY();
    $securiaceModernDrawCard(
        $securiaceModernMargin,
        $securiaceModernNotesY,
        $securiaceModernUsableWidth,
        $securiaceModernNotesHeight,
        $securiaceModernSurface,
        $securiaceModernLine
    );
    $securiaceModernDrawLabel('Invoice notes', $securiaceModernMargin + 4, $securiaceModernNotesY + 3, $securiaceModernUsableWidth - 8);
    $pdf->SetFont($securiaceModernFont, '', 7);
    $pdf->SetTextColor($securiaceModernMuted[0], $securiaceModernMuted[1], $securiaceModernMuted[2]);
    $pdf->SetXY($securiaceModernMargin + 4, $securiaceModernNotesY + 8);
    $pdf->MultiCell($securiaceModernUsableWidth - 8, 4, $securiaceModernNotesText, 0, 'L', false, 1, '', '', true, 0, false, true);
    $pdf->SetY($securiaceModernNotesY + $securiaceModernNotesHeight);
}

// -------------------------------------------------------------------------
// Repeated page context and footer
// -------------------------------------------------------------------------

$securiaceModernGeneratedAt = function_exists('getTodaysDate')
    ? getTodaysDate(1)
    : date('j M Y');
$securiaceModernFinalPage = $pdf->getPage();
$securiaceModernPageCount = $securiaceModernFinalPage - $securiaceModernStartPage + 1;
$securiaceModernPreviousAutoPageBreak = $pdf->getAutoPageBreak();
$securiaceModernPreviousBreakMargin = $pdf->getBreakMargin();
$pdf->SetAutoPageBreak(false, 0);
$securiaceModernStampedPages = array();

for ($securiaceModernPage = $securiaceModernStartPage; $securiaceModernPage <= $securiaceModernFinalPage; ++$securiaceModernPage) {
    $securiaceModernStampedPages[] = $securiaceModernPage;
    $pdf->setPage($securiaceModernPage);
    // setPage() restores the page's original auto-break setting in TCPDF.
    // Disable it again so footer positioning cannot consume the next page or
    // append a blank page when drawing near the physical page edge.
    $pdf->SetAutoPageBreak(false, 0);
    if ($securiaceModernPage > $securiaceModernStartPage) {
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
    $securiaceModernRelativePage = $securiaceModernPage - $securiaceModernStartPage + 1;
    $pdf->Cell($securiaceModernUsableWidth * 0.3, 4, 'Page ' . $securiaceModernRelativePage . ' of ' . $securiaceModernPageCount, 0, 1, 'R');
}

$pdf->SetAutoPageBreak($securiaceModernPreviousAutoPageBreak, $securiaceModernPreviousBreakMargin);
$pdf->setPage($securiaceModernFinalPage);
