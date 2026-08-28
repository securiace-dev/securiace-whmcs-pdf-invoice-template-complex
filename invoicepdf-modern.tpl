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

$securiaceModernInitialHttpStatus = function_exists('http_response_code') ? http_response_code() : false;
$securiaceModernRenderErrorObserved = false;
$securiaceModernIsTcpdfDeprecation = static function ($error) {
    if (!is_array($error) || !isset($error['type'], $error['file'])) {
        return false;
    }

    $deprecationTypes = array(E_DEPRECATED);
    if (defined('E_USER_DEPRECATED')) {
        $deprecationTypes[] = E_USER_DEPRECATED;
    }

    return in_array($error['type'], $deprecationTypes, true)
        && stripos(basename((string) $error['file']), 'tcpdf') === 0;
};
$securiaceModernPreviousErrorHandler = null;
$securiaceModernPreviousErrorHandler = set_error_handler(
    static function ($severity, $message, $file, $line) use (
        &$securiaceModernPreviousErrorHandler,
        &$securiaceModernRenderErrorObserved,
        $securiaceModernIsTcpdfDeprecation
    ) {
        if ($securiaceModernIsTcpdfDeprecation(array(
            'type' => $severity,
            'file' => $file,
        ))) {
            return true;
        }
        $securiaceModernRenderErrorObserved = true;
        if (is_callable($securiaceModernPreviousErrorHandler)) {
            return call_user_func(
                $securiaceModernPreviousErrorHandler,
                $severity,
                $message,
                $file,
                $line
            );
        }
        return false;
    }
);

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
        'branch' => '',
        'account_type' => '',
        'bank_name' => '',
    ),
    'bank_currencies' => array('INR'),
    'upi_id' => '',
    'date_order' => 'DMY',
    'jurisdiction' => '',
    'overdue_interest' => '',
    'late_fee_text' => '',
    'tds_note' => '',
    // Non-GST is the safe default. GST mode requires the explicit boolean,
    // a valid GSTIN, and an issue date on/after the effective date.
    'gst_registered' => false,
    'gst_effective_date' => '',
    'gst_final_title' => 'Tax Invoice',
    // Commercial Invoice is a controlled exception, not an international
    // default. Add only currencies reviewed for that document treatment.
    'commercial_invoice_currencies' => array(),
);

$securiaceModernConfig = $securiaceModernDefaults;
$securiaceModernConfigPath = defined('ROOTDIR')
    ? ROOTDIR . '/includes/securiace-invoice-config.php'
    : '';
$securiaceModernBootstrapWarnings = array();

if ($securiaceModernConfigPath !== '' && is_readable($securiaceModernConfigPath)) {
    try {
        $securiaceModernLoadedConfig = include $securiaceModernConfigPath;
    } catch (Throwable $securiaceModernConfigException) {
        $securiaceModernLoadedConfig = null;
        $securiaceModernBootstrapWarnings[] = 'protected-config-include-failed';
    }
    if (is_array($securiaceModernLoadedConfig)) {
        $securiaceModernConfig = array_replace_recursive(
            $securiaceModernConfig,
            $securiaceModernLoadedConfig
        );
    } elseif ($securiaceModernLoadedConfig !== null) {
        $securiaceModernBootstrapWarnings[] = 'protected-config-invalid-result';
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
    'date_order', 'jurisdiction', 'overdue_interest',
    'late_fee_text', 'tds_note', 'gst_effective_date', 'gst_final_title'
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
$securiaceModernGstRegisteredValue = isset($securiaceModernConfig['gst_registered'])
    ? $securiaceModernConfig['gst_registered']
    : false;
if (is_bool($securiaceModernGstRegisteredValue)) {
    $securiaceModernConfig['gst_registered'] = $securiaceModernGstRegisteredValue;
} else {
    $securiaceModernGstRegisteredValue = is_scalar($securiaceModernGstRegisteredValue)
        ? filter_var($securiaceModernGstRegisteredValue, FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE)
        : null;
    $securiaceModernConfig['gst_registered'] = $securiaceModernGstRegisteredValue === true;
}
if (!in_array(
    $securiaceModernConfig['gst_final_title'],
    array('Tax Invoice', 'Tax Invoice — Export of Services'),
    true
)) {
    $securiaceModernConfig['gst_final_title'] = $securiaceModernDefaults['gst_final_title'];
}
foreach ($securiaceModernConfig['bank'] as $securiaceModernBankConfigKey => $securiaceModernBankConfigValue) {
    if (!is_scalar($securiaceModernBankConfigValue)
        && !(is_object($securiaceModernBankConfigValue) && method_exists($securiaceModernBankConfigValue, '__toString'))
    ) {
        $securiaceModernBankConfigValue = '';
    }
    $securiaceModernConfig['bank'][$securiaceModernBankConfigKey] = (string) $securiaceModernBankConfigValue;
}

$securiaceModernBankCurrencies = isset($securiaceModernConfig['bank_currencies'])
    && is_array($securiaceModernConfig['bank_currencies'])
    ? $securiaceModernConfig['bank_currencies']
    : $securiaceModernDefaults['bank_currencies'];
$securiaceModernConfig['bank_currencies'] = array();
foreach ($securiaceModernBankCurrencies as $securiaceModernBankCurrency) {
    if (!is_scalar($securiaceModernBankCurrency)
        && !(is_object($securiaceModernBankCurrency) && method_exists($securiaceModernBankCurrency, '__toString'))
    ) {
        continue;
    }
    $securiaceModernBankCurrency = strtoupper(trim((string) $securiaceModernBankCurrency));
    if (preg_match('/^[A-Z]{3}$/', $securiaceModernBankCurrency)
        && !in_array($securiaceModernBankCurrency, $securiaceModernConfig['bank_currencies'], true)
    ) {
        $securiaceModernConfig['bank_currencies'][] = $securiaceModernBankCurrency;
    }
}

$securiaceModernCommercialCurrencies = isset($securiaceModernConfig['commercial_invoice_currencies'])
    && is_array($securiaceModernConfig['commercial_invoice_currencies'])
    ? $securiaceModernConfig['commercial_invoice_currencies']
    : array();
$securiaceModernConfig['commercial_invoice_currencies'] = array();
foreach ($securiaceModernCommercialCurrencies as $securiaceModernCommercialCurrency) {
    if (!is_scalar($securiaceModernCommercialCurrency)
        && !(is_object($securiaceModernCommercialCurrency)
            && method_exists($securiaceModernCommercialCurrency, '__toString'))
    ) {
        continue;
    }
    $securiaceModernCommercialCurrency = strtoupper(trim((string) $securiaceModernCommercialCurrency));
    if (preg_match('/^[A-Z]{3}$/', $securiaceModernCommercialCurrency)
        && !in_array(
            $securiaceModernCommercialCurrency,
            $securiaceModernConfig['commercial_invoice_currencies'],
            true
        )
    ) {
        $securiaceModernConfig['commercial_invoice_currencies'][] = $securiaceModernCommercialCurrency;
    }
}

// WHMCS passes Company Name, Domain, Pay To, and tax values to the template,
// but not every General/Invoice setting needed for robust fallbacks. Resolve
// those through the supported setting model when available. Fixtures and other
// integrations can inject the same non-secret map without a database.
$securiaceModernWhmcsSettings = isset($securiacePdfSettings) && is_array($securiacePdfSettings)
    ? $securiacePdfSettings
    : array();
$securiaceModernSettingNames = array(
    'company_email' => 'Email',
    'company_url' => 'Domain',
    'tax_code' => 'TaxCode',
    'late_fee_type' => 'LateFeeType',
    'late_fee_amount' => 'InvoiceLateFeeAmount',
    'late_fee_minimum' => 'LateFeeMinimum',
);
if (class_exists('\\WHMCS\\Config\\Setting')) {
    foreach ($securiaceModernSettingNames as $securiaceModernSettingKey => $securiaceModernSettingName) {
        if (array_key_exists($securiaceModernSettingKey, $securiaceModernWhmcsSettings)) {
            continue;
        }
        try {
            $securiaceModernWhmcsSettings[$securiaceModernSettingKey] =
                \WHMCS\Config\Setting::getValue($securiaceModernSettingName);
        } catch (Throwable $securiaceModernSettingException) {
            $securiaceModernWhmcsSettings[$securiaceModernSettingKey] = '';
        }
    }
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
$securiaceModernStoredInvoiceNumber = $securiaceModernInvoiceNumber;

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

$securiaceModernGstinCandidate = isset($taxCode) && trim((string) $taxCode) !== ''
    ? strtoupper(trim((string) $taxCode))
    : (isset($securiaceModernWhmcsSettings['tax_code'])
        ? strtoupper(trim((string) $securiaceModernWhmcsSettings['tax_code']))
        : '');
$securiaceModernGstinValid = preg_match(
    '/^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][A-Z0-9]Z[A-Z0-9]$/',
    $securiaceModernGstinCandidate
) === 1;
$securiaceModernIssueDateForPolicy = isset($datecreated)
    ? $securiaceModernParseDate($datecreated)
    : null;
$securiaceModernGstEffectiveDate = trim((string) $securiaceModernConfig['gst_effective_date']) !== ''
    ? $securiaceModernParseDate($securiaceModernConfig['gst_effective_date'])
    : null;
$securiaceModernGstGateWarnings = array();
if ($securiaceModernConfig['gst_registered'] && !$securiaceModernGstinValid) {
    $securiaceModernGstGateWarnings[] = 'gst-gate-invalid-gstin';
}
if ($securiaceModernConfig['gst_registered']
    && !($securiaceModernGstEffectiveDate instanceof DateTimeImmutable)
) {
    $securiaceModernGstGateWarnings[] = 'gst-gate-effective-date-unavailable';
}
if ($securiaceModernConfig['gst_registered']
    && !($securiaceModernIssueDateForPolicy instanceof DateTimeImmutable)
) {
    $securiaceModernGstGateWarnings[] = 'gst-gate-issue-date-unavailable';
}
$securiaceModernGstActive = $securiaceModernConfig['gst_registered']
    && $securiaceModernGstinValid
    && $securiaceModernGstEffectiveDate instanceof DateTimeImmutable
    && $securiaceModernIssueDateForPolicy instanceof DateTimeImmutable
    && $securiaceModernIssueDateForPolicy >= $securiaceModernGstEffectiveDate;
$securiaceModernCommercialInvoiceActive = !$securiaceModernGstActive
    && in_array(
        $securiaceModernCurrencyCode,
        $securiaceModernConfig['commercial_invoice_currencies'],
        true
    );

if ($securiaceModernIsProforma) {
    $securiaceModernDocumentTitle = 'Proforma Invoice';
} elseif ($securiaceModernGstActive) {
    $securiaceModernDocumentTitle = $securiaceModernConfig['gst_final_title'];
} elseif ($securiaceModernCommercialInvoiceActive) {
    $securiaceModernDocumentTitle = 'Commercial Invoice';
} else {
    $securiaceModernDocumentTitle = 'Invoice';
}
$securiaceModernDocumentKicker = strtoupper($securiaceModernDocumentTitle);

// WHMCS owns assignment and sequence uniqueness. The template only preflights
// final display numbers against the future GST Rule 46(b) shape and never
// rewrites a number, which would break reconciliation with the database.
$securiaceModernFinalNumberMaxLength = 16;
$securiaceModernFinalNumberLength = function_exists('mb_strlen')
    ? mb_strlen($securiaceModernStoredInvoiceNumber, 'UTF-8')
    : strlen($securiaceModernStoredInvoiceNumber);
$securiaceModernFinalNumberAllowed = preg_match(
    '/^[A-Za-z0-9\/-]+$/',
    $securiaceModernStoredInvoiceNumber
) === 1;
$securiaceModernFinalNumberWithinLimit = $securiaceModernFinalNumberLength > 0
    && $securiaceModernFinalNumberLength <= $securiaceModernFinalNumberMaxLength;
$securiaceModernNumberingDiagnostics = array(
    'applicable' => !$securiaceModernIsProforma,
    'number' => $securiaceModernStoredInvoiceNumber,
    'length' => $securiaceModernFinalNumberLength,
    'max_length' => $securiaceModernFinalNumberMaxLength,
    'allowed_characters' => $securiaceModernFinalNumberAllowed,
    'within_limit' => $securiaceModernFinalNumberWithinLimit,
    'valid' => $securiaceModernIsProforma
        || ($securiaceModernFinalNumberAllowed && $securiaceModernFinalNumberWithinLimit),
);

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
$securiaceModernRenderedBank = false;
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

$securiaceModernProfilePath = '';
foreach (array(
    defined('ROOTDIR') ? ROOTDIR . '/includes/securiace-pdf-profile.php' : '',
    __DIR__ . '/securiace-pdf-profile.php',
) as $securiaceModernProfileCandidate) {
    if ($securiaceModernProfileCandidate !== '' && is_readable($securiaceModernProfileCandidate)) {
        $securiaceModernProfilePath = $securiaceModernProfileCandidate;
        break;
    }
}
$securiaceModernProfileWarnings = $securiaceModernBootstrapWarnings;
$securiaceModernScalarText = static function ($value, $fallback = '') {
    if (is_scalar($value)
        || (is_object($value) && method_exists($value, '__toString'))
    ) {
        return trim((string) $value);
    }
    return (string) $fallback;
};
$securiaceModernNormalizeIssuerProfile = static function (
    $rawProfile,
    array $baseWarnings = array()
) use ($securiaceModernScalarText) {
        $warnings = array();
        foreach ($baseWarnings as $warning) {
            $warningText = $securiaceModernScalarText($warning);
            if ($warningText !== '') {
                $warnings[] = $warningText;
            }
        }

        if (!is_array($rawProfile)) {
            $rawProfile = array();
            $warnings[] = 'profile-shape-invalid';
        }

        $identity = isset($rawProfile['identity']) && is_array($rawProfile['identity']) ? $rawProfile['identity'] : array();
        if (!isset($rawProfile['identity']) || !is_array($rawProfile['identity'])) {
            $warnings[] = 'profile-identity-invalid';
        }

        $normalizedIdentity = array(
            'business_name' => $securiaceModernScalarText(
                isset($identity['business_name']) ? $identity['business_name'] : '',
                'Issuer'
            ),
            'address_lines' => array(),
            'support_email' => $securiaceModernScalarText(isset($identity['support_email']) ? $identity['support_email'] : ''),
            'mobile' => $securiaceModernScalarText(isset($identity['mobile']) ? $identity['mobile'] : ''),
            'website' => $securiaceModernScalarText(isset($identity['website']) ? $identity['website'] : ''),
        );
        if ($normalizedIdentity['business_name'] === '') {
            $normalizedIdentity['business_name'] = 'Issuer';
        }
        $normalizedIdentity['support_email_valid'] = $normalizedIdentity['support_email'] === ''
            || filter_var($normalizedIdentity['support_email'], FILTER_VALIDATE_EMAIL) !== false;
        $normalizedIdentity['website_valid'] = $normalizedIdentity['website'] === ''
            || filter_var($normalizedIdentity['website'], FILTER_VALIDATE_URL) !== false;
        $rawAddressLines = isset($identity['address_lines']) && is_array($identity['address_lines'])
            ? $identity['address_lines']
            : array();
        if (!empty($identity) && !isset($identity['address_lines'])) {
            $warnings[] = 'profile-address-lines-missing';
        }
        foreach (array_slice($rawAddressLines, 0, 8) as $identityAddressLine) {
            if (!is_scalar($identityAddressLine)
                && !(is_object($identityAddressLine) && method_exists($identityAddressLine, '__toString'))
            ) {
                continue;
            }
            $normalizedAddressLine = trim((string) $identityAddressLine);
            if ($normalizedAddressLine !== '') {
                $normalizedIdentity['address_lines'][] = $normalizedAddressLine;
            }
        }

        $rawRegistrations = isset($rawProfile['registrations']) && is_array($rawProfile['registrations'])
            ? $rawProfile['registrations']
            : array();
        if (array_key_exists('registrations', $rawProfile) && !is_array($rawProfile['registrations'])) {
            $warnings[] = 'profile-registrations-invalid';
        }
        $registrations = array();
        foreach ($rawRegistrations as $registrationType => $registration) {
            if (!is_array($registration)) {
                continue;
            }
            $registrations[(string) $registrationType] = array(
                'label' => $securiaceModernScalarText(isset($registration['label']) ? $registration['label'] : ''),
                'value' => $securiaceModernScalarText(isset($registration['value']) ? $registration['value'] : ''),
                'valid' => !empty($registration['valid']),
                'source' => $securiaceModernScalarText(isset($registration['source']) ? $registration['source'] : ''),
            );
        }

        $payment = isset($rawProfile['payment']) && is_array($rawProfile['payment']) ? $rawProfile['payment'] : array();
        if (array_key_exists('payment', $rawProfile) && !is_array($rawProfile['payment'])) {
            $warnings[] = 'profile-payment-invalid';
        }
        $rawBankAccounts = isset($payment['bank_accounts']) && is_array($payment['bank_accounts'])
            ? $payment['bank_accounts']
            : array();
        if (array_key_exists('bank_accounts', $payment) && !is_array($payment['bank_accounts'])) {
            $warnings[] = 'profile-bank-accounts-invalid';
        }
        $bankAccounts = array();
        foreach ($rawBankAccounts as $bankAccount) {
            if (!is_array($bankAccount)) {
                continue;
            }
            $bankAccounts[] = array(
                'account_name' => $securiaceModernScalarText(isset($bankAccount['account_name']) ? $bankAccount['account_name'] : ''),
                'account_number' => $securiaceModernScalarText(isset($bankAccount['account_number']) ? $bankAccount['account_number'] : ''),
                'routing_code' => $securiaceModernScalarText(isset($bankAccount['routing_code']) ? $bankAccount['routing_code'] : ''),
                'branch' => $securiaceModernScalarText(isset($bankAccount['branch']) ? $bankAccount['branch'] : ''),
                'account_type' => $securiaceModernScalarText(isset($bankAccount['account_type']) ? $bankAccount['account_type'] : ''),
                'bank_name' => $securiaceModernScalarText(isset($bankAccount['bank_name']) ? $bankAccount['bank_name'] : ''),
                'currencies' => is_array(isset($bankAccount['currencies']) ? $bankAccount['currencies'] : array())
                    ? array_values(array_unique(array_map(
                        'strtoupper',
                        array_filter(
                            array_map(
                                static function ($value) use ($securiaceModernScalarText) {
                                    return $securiaceModernScalarText($value);
                                },
                                array_values(isset($bankAccount['currencies']) ? $bankAccount['currencies'] : array())
                            ),
                            static function ($value) { return $value !== ''; }
                        )
                    )))
                    : array(),
                'source' => $securiaceModernScalarText(isset($bankAccount['source']) ? $bankAccount['source'] : ''),
                'conflicted' => !empty($bankAccount['conflicted']),
                'used_default_currencies' => !empty($bankAccount['used_default_currencies']),
                'valid' => !empty($bankAccount['valid']),
                'complete' => !empty($bankAccount['complete']),
            );
        }
        $upi = isset($payment['upi']) && is_array($payment['upi']) ? $payment['upi'] : array();
        if (array_key_exists('upi', $payment) && !is_array($payment['upi'])) {
            $warnings[] = 'profile-upi-invalid';
        }
        $rawUpiCurrencies = isset($upi['currencies']) && is_array($upi['currencies'])
            ? $upi['currencies']
            : array();
        if (array_key_exists('currencies', $upi) && !is_array($upi['currencies'])) {
            $warnings[] = 'profile-upi-currencies-invalid';
        }
        $upiCurrencies = array();
        foreach ($rawUpiCurrencies as $currency) {
            if (!is_scalar($currency) && !(is_object($currency) && method_exists($currency, '__toString'))) {
                continue;
            }
            $currency = strtoupper(trim((string) $currency));
            if ($currency !== '' && !in_array($currency, $upiCurrencies, true)) {
                $upiCurrencies[] = $currency;
            }
        }

        $policy = isset($rawProfile['policy']) && is_array($rawProfile['policy']) ? $rawProfile['policy'] : array();
        if (array_key_exists('policy', $rawProfile) && !is_array($rawProfile['policy'])) {
            $warnings[] = 'profile-policy-invalid';
        }
        $diagnostics = isset($rawProfile['diagnostics']) && is_array($rawProfile['diagnostics']) ? $rawProfile['diagnostics'] : array();

        $diagnosticWarnings = array();
        $rawDiagnosticWarnings = isset($diagnostics['warnings']) && is_array($diagnostics['warnings'])
            ? $diagnostics['warnings']
            : array();
        foreach (array_merge($rawDiagnosticWarnings, $warnings) as $diagnosticWarning) {
            $diagnosticWarning = $securiaceModernScalarText($diagnosticWarning);
            if ($diagnosticWarning !== '') {
                $diagnosticWarnings[] = $diagnosticWarning;
            }
        }
        $diagnosticWarnings = array_values(array_unique($diagnosticWarnings));

        return array(
            'schema_version' => 1,
            'identity' => $normalizedIdentity,
            'registrations' => $registrations,
            'payment' => array(
                'upi' => array(
                    'id' => $securiaceModernScalarText(isset($upi['id']) ? $upi['id'] : ''),
                    'payee_name' => $securiaceModernScalarText(isset($upi['payee_name']) ? $upi['payee_name'] : ''),
                    'currencies' => $upiCurrencies,
                    'valid' => !empty($upi['valid']),
                    'source' => $securiaceModernScalarText(isset($upi['source']) ? $upi['source'] : ''),
                ),
                'bank_accounts' => $bankAccounts,
            ),
            'policy' => array(
                'jurisdiction' => $securiaceModernScalarText(isset($policy['jurisdiction']) ? $policy['jurisdiction'] : ''),
                'tds_note' => $securiaceModernScalarText(isset($policy['tds_note']) ? $policy['tds_note'] : ''),
                'late_fee_text' => $securiaceModernScalarText(isset($policy['late_fee_text']) ? $policy['late_fee_text'] : ''),
            ),
            'diagnostics' => array(
                'sources' => isset($diagnostics['sources']) && is_array($diagnostics['sources']) ? $diagnostics['sources'] : array(),
                'conflicts' => isset($diagnostics['conflicts']) && is_array($diagnostics['conflicts']) ? $diagnostics['conflicts'] : array(),
                'warnings' => $diagnosticWarnings,
                'unknown_labels' => isset($diagnostics['unknown_labels']) && is_array($diagnostics['unknown_labels']) ? $diagnostics['unknown_labels'] : array(),
            ),
        );
    };

$securiaceModernProfileResolver = null;
$securiaceModernProfileResolved = false;
if ($securiaceModernProfilePath !== '') {
    try {
        $securiaceModernProfileResolver = include $securiaceModernProfilePath;
    } catch (Throwable $securiaceModernProfileException) {
        $securiaceModernProfileWarnings[] = 'profile-helper-include-failed';
    }
}
$securiaceModernCompanyNameInput = isset($companyname) ? $companyname : '';
$securiaceModernCompanyUrlInput = isset($companyurl) && trim((string) $companyurl) !== ''
    ? $companyurl
    : (isset($securiaceModernWhmcsSettings['company_url']) ? $securiaceModernWhmcsSettings['company_url'] : '');
$securiaceModernCompanyEmailInput = isset($securiaceModernWhmcsSettings['company_email'])
    ? $securiaceModernWhmcsSettings['company_email']
    : '';
$securiaceModernTaxCodeInput = isset($taxCode) && trim((string) $taxCode) !== ''
    ? $taxCode
    : (isset($securiaceModernWhmcsSettings['tax_code']) ? $securiaceModernWhmcsSettings['tax_code'] : '');

if ($securiaceModernProfileResolver instanceof Closure) {
    $securiaceModernProfileResolved = false;
    try {
        $securiaceModernIssuerProfile = $securiaceModernProfileResolver(array(
            'company_name' => $securiaceModernCompanyNameInput,
            'company_email' => $securiaceModernCompanyEmailInput,
            'company_url' => $securiaceModernCompanyUrlInput,
            'tax_code' => $securiaceModernTaxCodeInput,
            'tax_label' => isset($taxIdLabel) ? $taxIdLabel : 'GSTIN',
            'pay_to' => isset($companyaddress) ? $companyaddress : array(),
            'default_bank_currencies' => $securiaceModernConfig['bank_currencies'],
            'fallback' => $securiaceModernConfig,
        ));
        if (is_array($securiaceModernIssuerProfile)) {
            $securiaceModernProfileResolved = true;
        } else {
            $securiaceModernProfileWarnings[] = 'profile-helper-invalid-result';
        }
    } catch (Throwable $securiaceModernProfileException) {
        $securiaceModernProfileWarnings[] = 'profile-helper-runtime-failed';
    }
}
if (empty($securiaceModernProfileWarnings) && empty($securiaceModernProfileResolved)) {
    $securiaceModernProfileWarnings[] = $securiaceModernProfilePath === ''
        ? 'profile-helper-unavailable'
        : 'profile-helper-invalid';
}
if (!$securiaceModernProfileResolved) {
    // A partial deployment must not leak raw Pay To payment lines into the
    // issuer card. Degrade to safe identity fallbacks and disable payment data.
    $securiaceModernFallbackCompanyName = trim((string) $securiaceModernCompanyNameInput);
    if ($securiaceModernFallbackCompanyName === '') {
        $securiaceModernFallbackCompanyName = 'Issuer';
    }
    $securiaceModernIssuerProfile = array(
        'identity' => array(
            'business_name' => $securiaceModernFallbackCompanyName,
            'address_lines' => array(),
            'support_email' => trim((string) $securiaceModernCompanyEmailInput),
            'support_email_valid' => true,
            'mobile' => trim((string) $securiaceModernConfig['company_phone']),
            'website' => trim((string) $securiaceModernCompanyUrlInput),
            'website_valid' => true,
        ),
        'registrations' => array(),
        'payment' => array(
            'upi' => array('id' => '', 'payee_name' => $securiaceModernFallbackCompanyName, 'valid' => false),
            'bank_accounts' => array(),
        ),
        'policy' => array(
            'jurisdiction' => trim((string) $securiaceModernConfig['jurisdiction']),
            'tds_note' => trim((string) $securiaceModernConfig['tds_note']),
            'late_fee_text' => trim((string) $securiaceModernConfig['late_fee_text']),
        ),
        'diagnostics' => array(
            'sources' => array(),
            'conflicts' => array(),
            'warnings' => array_values(array_unique($securiaceModernProfileWarnings)),
            'unknown_labels' => array(),
        ),
    );
}
$securiaceModernIssuerProfile = $securiaceModernNormalizeIssuerProfile(
    $securiaceModernIssuerProfile,
    $securiaceModernProfileWarnings
);

$securiaceModernSnapshotApplied = false;
$securiaceModernSnapshotWarning = '';
$securiaceModernSnapshotRow = isset($securiacePdfSnapshotRow) && is_array($securiacePdfSnapshotRow)
    ? $securiacePdfSnapshotRow
    : array();
if (empty($securiaceModernSnapshotRow)
    && !$securiaceModernIsProforma
    && $securiaceModernInvoiceId !== ''
    && class_exists('\\WHMCS\\Database\\Capsule')
) {
    try {
        if (\WHMCS\Database\Capsule::schema()->hasTable('mod_securiace_pdf_issuer_snapshots')) {
            $securiaceModernSnapshotRecord = \WHMCS\Database\Capsule::table(
                'mod_securiace_pdf_issuer_snapshots'
            )->where('invoice_id', (int) $securiaceModernInvoiceId)->first();
            if ($securiaceModernSnapshotRecord) {
                $securiaceModernSnapshotRow = (array) $securiaceModernSnapshotRecord;
            }
        }
    } catch (Throwable $securiaceModernSnapshotReadException) {
        $securiaceModernSnapshotWarning = 'snapshot-read-failed';
    }
}

if (!$securiaceModernIsProforma && !empty($securiaceModernSnapshotRow)) {
    $securiaceModernSnapshotValidatorPath = '';
    foreach (array(
        defined('ROOTDIR') ? ROOTDIR . '/includes/securiace-pdf-snapshot.php' : '',
        __DIR__ . '/securiace-pdf-snapshot.php',
    ) as $securiaceModernSnapshotValidatorCandidate) {
        if ($securiaceModernSnapshotValidatorCandidate !== ''
            && is_readable($securiaceModernSnapshotValidatorCandidate)
        ) {
            $securiaceModernSnapshotValidatorPath = $securiaceModernSnapshotValidatorCandidate;
            break;
        }
    }
    $securiaceModernSnapshotValidator = null;
    if ($securiaceModernSnapshotValidatorPath !== '') {
        try {
            $securiaceModernSnapshotValidator = include $securiaceModernSnapshotValidatorPath;
        } catch (Throwable $securiaceModernSnapshotValidationException) {
            $securiaceModernSnapshotWarning = 'snapshot-validator-include-failed';
        }
    }
    if ($securiaceModernSnapshotWarning === '' && $securiaceModernSnapshotValidator instanceof Closure) {
        try {
            $securiaceModernSnapshotResult = $securiaceModernSnapshotValidator($securiaceModernSnapshotRow);
            if (!is_array($securiaceModernSnapshotResult)) {
                $securiaceModernSnapshotWarning = 'snapshot-validator-invalid-result';
            } elseif (!empty($securiaceModernSnapshotResult['valid'])) {
                $securiaceModernSnapshot = isset($securiaceModernSnapshotResult['snapshot'])
                    && is_array($securiaceModernSnapshotResult['snapshot'])
                    ? $securiaceModernSnapshotResult['snapshot']
                    : array();
                $securiaceModernSnapshotIssuer = isset($securiaceModernSnapshot['issuer'])
                    && is_array($securiaceModernSnapshot['issuer'])
                    ? $securiaceModernSnapshot['issuer']
                    : array();
                $securiaceModernSnapshotDocument = isset($securiaceModernSnapshot['document'])
                    && is_array($securiaceModernSnapshot['document'])
                    ? $securiaceModernSnapshot['document']
                    : array();
                $securiaceModernSnapshotIdentity = isset($securiaceModernSnapshotIssuer['identity'])
                    && is_array($securiaceModernSnapshotIssuer['identity'])
                    ? $securiaceModernSnapshotIssuer['identity']
                    : array();
                $securiaceModernSnapshotRegistrations = isset($securiaceModernSnapshotIssuer['registrations'])
                    && is_array($securiaceModernSnapshotIssuer['registrations'])
                    ? $securiaceModernSnapshotIssuer['registrations']
                    : array();
                if (!$securiaceModernSnapshotIdentity || empty($securiaceModernSnapshotDocument)) {
                    $securiaceModernSnapshotWarning = 'snapshot-structure-invalid';
                } else {
                    $securiaceModernIssuerProfile['identity'] = $securiaceModernSnapshotIdentity;
                    $securiaceModernIssuerProfile['registrations'] = $securiaceModernSnapshotRegistrations;
                    $securiaceModernDocumentTitle = trim(
                        isset($securiaceModernSnapshotDocument['title'])
                            ? (string) $securiaceModernSnapshotDocument['title']
                            : ''
                    );
                    if ($securiaceModernDocumentTitle === '') {
                        $securiaceModernSnapshotWarning = 'snapshot-document-title-invalid';
                    } else {
                        $securiaceModernDocumentKicker = strtoupper($securiaceModernDocumentTitle);
                        $securiaceModernGstActive = !empty($securiaceModernSnapshotDocument['gst_active']);
                        $securiaceModernCommercialInvoiceActive =
                            $securiaceModernDocumentTitle === 'Commercial Invoice';
                        $securiaceModernSnapshotApplied = true;
                        $securiaceModernSnapshotFinalNumber = isset(
                            $securiaceModernSnapshotDocument['final_invoice_number']
                        ) ? trim((string) $securiaceModernSnapshotDocument['final_invoice_number']) : '';
                        if ($securiaceModernSnapshotFinalNumber !== ''
                            && $securiaceModernSnapshotFinalNumber !== $securiaceModernStoredInvoiceNumber
                        ) {
                            $securiaceModernSnapshotWarning = 'snapshot-final-number-mismatch';
                        }
                    }
                }
            } else {
                $securiaceModernSnapshotWarning = isset($securiaceModernSnapshotResult['warning'])
                    ? (string) $securiaceModernSnapshotResult['warning']
                    : 'snapshot-invalid';
            }
        } catch (Throwable $securiaceModernSnapshotValidationException) {
            $securiaceModernSnapshotWarning = 'snapshot-validator-runtime-failed';
        }
    } elseif ($securiaceModernSnapshotWarning === '') {
        $securiaceModernSnapshotWarning = $securiaceModernSnapshotValidatorPath === ''
            ? 'snapshot-validator-unavailable'
            : 'snapshot-validator-invalid';
    }
}

$securiaceModernIssuerProfile = $securiaceModernNormalizeIssuerProfile($securiaceModernIssuerProfile);

$securiaceModernCompanyName = $securiaceModernIssuerProfile['identity']['business_name'];
$securiaceModernCompanyAddress = $securiaceModernIssuerProfile['identity']['address_lines'];
$securiaceModernIssuerDiagnostics = $securiaceModernIssuerProfile['diagnostics'];
$securiaceModernLifecycleDiagnostics = array(
    'gst_registered' => $securiaceModernConfig['gst_registered'],
    'gstin_valid' => $securiaceModernGstinValid,
    'gst_effective_date_valid' => $securiaceModernGstEffectiveDate instanceof DateTimeImmutable,
    'issue_date_valid' => $securiaceModernIssueDateForPolicy instanceof DateTimeImmutable,
    'gst_active' => $securiaceModernGstActive,
    'commercial_invoice_active' => $securiaceModernCommercialInvoiceActive,
);
$securiaceModernIssuerDiagnostics['warnings'] = isset($securiaceModernIssuerDiagnostics['warnings'])
    && is_array($securiaceModernIssuerDiagnostics['warnings'])
    ? $securiaceModernIssuerDiagnostics['warnings']
    : array();
$securiaceModernIssuerDiagnostics['warnings'] = array_merge(
    $securiaceModernIssuerDiagnostics['warnings'],
    $securiaceModernGstGateWarnings
);
if (!$securiaceModernNumberingDiagnostics['valid']) {
    $securiaceModernIssuerDiagnostics['warnings'][] = 'final-invoice-number-invalid';
}
if ($securiaceModernSnapshotWarning !== '') {
    $securiaceModernIssuerDiagnostics['warnings'][] = $securiaceModernSnapshotWarning;
}
if ($securiaceModernSnapshotApplied) {
    $securiaceModernIssuerDiagnostics['sources']['issuer.snapshot'] = 'immutable.invoice';
}
$securiaceModernIssuerDiagnostics['warnings'] = array_values(array_unique(
    $securiaceModernIssuerDiagnostics['warnings']
));
$securiaceModernBankAccounts = $securiaceModernIssuerProfile['payment']['bank_accounts'];
$securiaceModernUpiProfile = $securiaceModernIssuerProfile['payment']['upi'];

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
if ($securiaceModernIssuerProfile['identity']['support_email'] !== ''
    && $securiaceModernIssuerProfile['identity']['support_email_valid']
) {
    $securiaceModernSellerLines[] = 'Helpdesk · ' . $securiaceModernIssuerProfile['identity']['support_email'];
}
if ($securiaceModernIssuerProfile['identity']['mobile'] !== '') {
    $securiaceModernSellerLines[] = 'Mobile · ' . $securiaceModernIssuerProfile['identity']['mobile'];
}
$securiaceModernSellerRegistrations = array();
foreach ($securiaceModernIssuerProfile['registrations'] as $securiaceModernRegistrationKey => $securiaceModernRegistration) {
    if ($securiaceModernRegistrationKey === 'gstin' && !$securiaceModernGstActive) {
        continue;
    }
    if (!empty($securiaceModernRegistration['valid'])
        && !empty($securiaceModernRegistration['label'])
        && !empty($securiaceModernRegistration['value'])
    ) {
        $securiaceModernSellerRegistrations[] = trim((string) $securiaceModernRegistration['label'])
            . ' · ' . trim((string) $securiaceModernRegistration['value']);
    }
}

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

$securiaceModernLogoRendered = false;
if ($securiaceModernLogoPath !== '') {
    try {
        $pdf->Image($securiaceModernLogoPath, $securiaceModernMargin, $securiaceModernHeaderY, 42, 0, '', '', '', false, 300);
        $securiaceModernLogoRendered = true;
    } catch (Throwable $securiaceModernLogoException) {
        $securiaceModernIssuerDiagnostics['warnings'][] = 'logo-render-failed';
    }
}
if (!$securiaceModernLogoRendered) {
    $pdf->SetFont($securiaceModernFont, 'B', 17);
    $pdf->SetTextColor($securiaceModernInk[0], $securiaceModernInk[1], $securiaceModernInk[2]);
    $pdf->SetXY($securiaceModernMargin, $securiaceModernHeaderY + 1);
    $pdf->Cell(90, 7, $securiaceModernCompanyName, 0, 1, 'L');
}

$pdf->SetFont($securiaceModernFont, 'B', 6.5);
$pdf->SetTextColor($securiaceModernBrand[0], $securiaceModernBrand[1], $securiaceModernBrand[2]);
$pdf->SetXY($securiaceModernPageWidth - $securiaceModernMargin - 66, $securiaceModernHeaderY);
$pdf->Cell(66, 4, $securiaceModernDocumentKicker, 0, 1, 'R');
$securiaceModernDocumentTitleLength = function_exists('mb_strlen')
    ? mb_strlen($securiaceModernDocumentTitle, 'UTF-8')
    : strlen($securiaceModernDocumentTitle);
$securiaceModernDocumentTitleFontSize = $securiaceModernDocumentTitleLength > 28
    ? 14
    : ($securiaceModernDocumentTitleLength > 20 ? 17 : 22);
$pdf->SetFont($securiaceModernFont, 'B', $securiaceModernDocumentTitleFontSize);
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
    $pdf->Cell(60, 4, 'Payment status', 0, 1, 'L');
    $pdf->SetFont($securiaceModernFont, 'B', 9);
    $pdf->SetX($securiaceModernStatePanelX + 4);
    $pdf->Cell(60, 4.5, 'Paid in full', 0, 1, 'L');
    $pdf->SetFont($securiaceModernFont, '', 6);
    $pdf->SetX($securiaceModernStatePanelX + 4);
    $pdf->Cell(60, 3.5, 'No balance due · Invoice ' . $securiaceModernInvoiceNumber, 0, 1, 'L', false, '', 1);
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
            try {
                $pdf->Image($securiaceModernStampPath, $securiaceModernAuthorizationX, $securiaceModernAuthorizationY, 16, 16, '', '', '', false, 300);
            } catch (Throwable $securiaceModernStampException) {
                $securiaceModernIssuerDiagnostics['warnings'][] = 'stamp-render-failed';
            }
        }
        if ($securiaceModernIsUsableImage($securiaceModernSignaturePath)) {
            try {
                $pdf->Image($securiaceModernSignaturePath, $securiaceModernAuthorizationX + 16, $securiaceModernAuthorizationY + 2, 22, 10, '', '', '', false, 300);
            } catch (Throwable $securiaceModernSignatureException) {
                $securiaceModernIssuerDiagnostics['warnings'][] = 'signature-render-failed';
            }
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
$securiaceModernSelectedBankAccount = array();
foreach ($securiaceModernBankAccounts as $securiaceModernBankAccount) {
    if (empty($securiaceModernBankAccount['valid'])
        || empty($securiaceModernBankAccount['currencies'])
        || !in_array($securiaceModernCurrencyCode, $securiaceModernBankAccount['currencies'], true)
    ) {
        continue;
    }
    $securiaceModernSelectedBankAccount = $securiaceModernBankAccount;
    break;
}
$securiaceModernHasBankDetails = !empty($securiaceModernSelectedBankAccount);
$securiaceModernUpiId = !empty($securiaceModernUpiProfile['valid'])
    ? trim((string) $securiaceModernUpiProfile['id'])
    : '';
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
$securiaceModernTermsWidth = $securiaceModernUsableWidth * ($securiaceModernHasBankDetails ? 0.42 : 0.55);
$securiaceModernBankWidth = $securiaceModernHasBankDetails ? $securiaceModernUsableWidth * 0.31 : 0;
$securiaceModernSupportGaps = $securiaceModernHasBankDetails ? 6 : 3;
$securiaceModernActionWidth = $securiaceModernUsableWidth
    - $securiaceModernTermsWidth
    - $securiaceModernBankWidth
    - $securiaceModernSupportGaps;
$securiaceModernBankX = $securiaceModernMargin + $securiaceModernTermsWidth + 3;
$securiaceModernActionX = $securiaceModernHasBankDetails
    ? $securiaceModernBankX + $securiaceModernBankWidth + 3
    : $securiaceModernBankX;

$securiaceModernDrawCard($securiaceModernMargin, $securiaceModernSupportY, $securiaceModernTermsWidth, $securiaceModernSupportHeight, $securiaceModernSurface, $securiaceModernLine);
if ($securiaceModernHasBankDetails) {
    $securiaceModernDrawCard($securiaceModernBankX, $securiaceModernSupportY, $securiaceModernBankWidth, $securiaceModernSupportHeight, $securiaceModernSurface, $securiaceModernLine);
}
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
$securiaceModernLateFeeText = trim((string) $securiaceModernIssuerProfile['policy']['late_fee_text']);
if ($securiaceModernLateFeeText === '') {
    $securiaceModernLateFeeType = isset($securiaceModernWhmcsSettings['late_fee_type'])
        ? strtolower(trim((string) $securiaceModernWhmcsSettings['late_fee_type']))
        : '';
    $securiaceModernLateFeeAmount = isset($securiaceModernWhmcsSettings['late_fee_amount'])
        && is_numeric($securiaceModernWhmcsSettings['late_fee_amount'])
        ? (float) $securiaceModernWhmcsSettings['late_fee_amount']
        : 0.0;
    if ($securiaceModernLateFeeAmount > 0 && strpos($securiaceModernLateFeeType, 'percent') !== false) {
        $securiaceModernLateFeeRate = rtrim(rtrim(number_format($securiaceModernLateFeeAmount, 2, '.', ''), '0'), '.');
        $securiaceModernLateFeeText = 'Late fees may apply at ' . $securiaceModernLateFeeRate
            . '% after the due date; the configured minimum applies.';
    } elseif ($securiaceModernLateFeeAmount > 0) {
        $securiaceModernLateFeeText = 'A configured fixed late fee may apply after the due date.';
    }
}
if ($securiaceModernLateFeeText !== '') {
    $securiaceModernTerms[] = $securiaceModernLateFeeText;
}
if (trim((string) $securiaceModernIssuerProfile['policy']['tds_note']) !== '') {
    $securiaceModernTerms[] = trim((string) $securiaceModernIssuerProfile['policy']['tds_note']);
}
if (trim((string) $securiaceModernIssuerProfile['policy']['jurisdiction']) !== '') {
    $securiaceModernTerms[] = 'Jurisdiction: '
        . trim((string) $securiaceModernIssuerProfile['policy']['jurisdiction']) . '.';
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

if ($securiaceModernHasBankDetails) {
    $securiaceModernRenderedBank = true;
    $securiaceModernDrawLabel('Bank details', $securiaceModernBankX + 3, $securiaceModernSupportY + 3, $securiaceModernBankWidth - 6);
    $securiaceModernBankRows = array(
        'Account' => $securiaceModernSelectedBankAccount['account_name'],
        'Number' => $securiaceModernSelectedBankAccount['account_number'],
        'IFSC' => $securiaceModernSelectedBankAccount['routing_code'],
        'Branch' => $securiaceModernSelectedBankAccount['branch'],
        'Type' => $securiaceModernSelectedBankAccount['account_type'],
        'Bank' => $securiaceModernSelectedBankAccount['bank_name'],
    );
    $securiaceModernBankY = $securiaceModernSupportY + 8;
    foreach ($securiaceModernBankRows as $securiaceModernBankLabel => $securiaceModernBankValue) {
        if (trim((string) $securiaceModernBankValue) === '') {
            continue;
        }
        $pdf->SetFont($securiaceModernFont, '', 6);
        $pdf->SetTextColor($securiaceModernMuted[0], $securiaceModernMuted[1], $securiaceModernMuted[2]);
        $pdf->SetXY($securiaceModernBankX + 3, $securiaceModernBankY);
        $pdf->Cell($securiaceModernBankWidth * 0.32, 4, $securiaceModernBankLabel, 0, 0, 'L');
        $pdf->SetFont($securiaceModernFont, 'B', 6);
        $pdf->SetTextColor($securiaceModernInk[0], $securiaceModernInk[1], $securiaceModernInk[2]);
        $pdf->Cell($securiaceModernBankWidth * 0.58, 4, (string) $securiaceModernBankValue, 0, 1, 'R');
        $securiaceModernBankY += 5;
    }
}

$securiaceModernCanRenderUpiBarcode = $securiaceModernCanUseUpi && method_exists($pdf, 'write2DBarcode');
if ($securiaceModernCanRenderUpiBarcode) {
    $securiaceModernRenderedUpi = true;
    $securiaceModernDrawLabel('UPI payment', $securiaceModernActionX + 3, $securiaceModernSupportY + 3, $securiaceModernActionWidth - 6);
    $securiaceModernUpiParams = array(
        'pa' => $securiaceModernUpiId,
        'pn' => trim((string) $securiaceModernUpiProfile['payee_name']),
        'am' => number_format($securiaceModernBalanceNumeric, 2, '.', ''),
        'cu' => 'INR',
        'tr' => $securiaceModernInvoiceNumber,
        'tn' => 'Payment for ' . ($securiaceModernIsProforma ? 'proforma ' : 'invoice ') . $securiaceModernInvoiceNumber,
    );
    $securiaceModernUpiUri = 'upi://pay?' . http_build_query($securiaceModernUpiParams, '', '&', PHP_QUERY_RFC3986);
    $securiaceModernQrSize = min(25, $securiaceModernActionWidth - 8);
    $securiaceModernQrX = $securiaceModernActionX + ($securiaceModernActionWidth - $securiaceModernQrSize) / 2;
    try {
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
    } catch (Throwable $securiaceModernUpiBarcodeException) {
        $securiaceModernCanRenderUpiBarcode = false;
        $securiaceModernRenderedUpi = false;
        $securiaceModernIssuerDiagnostics['warnings'][] = 'upi-qr-render-failed';
        $securiaceModernIssuerDiagnostics['warnings'] = array_values(array_unique(
            $securiaceModernIssuerDiagnostics['warnings']
        ));
    }
}
if (!$securiaceModernCanRenderUpiBarcode && $securiaceModernCanUseUpi) {
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
} elseif (!$securiaceModernCanUseUpi) {
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
            : 'Contact '
                . ($securiaceModernIssuerProfile['identity']['support_email'] !== ''
                    && $securiaceModernIssuerProfile['identity']['support_email_valid']
                    ? $securiaceModernIssuerProfile['identity']['support_email']
                    : 'billing support')
                . ' and quote reference ' . $securiaceModernInvoiceNumber . '.',
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
    // Let's Seal line-safe footer reserve: the provider draws its signed proof
    // line near the physical bottom edge after TCPDF has finished the document.
    $pdf->SetXY($securiaceModernMargin, $securiaceModernPageHeight - 12);
    $pdf->Cell($securiaceModernUsableWidth * 0.7, 4, 'Generated ' . $securiaceModernGeneratedAt . ' · ' . $securiaceModernCompanyName, 0, 0, 'L');
    $securiaceModernRelativePage = $securiaceModernPage - $securiaceModernStartPage + 1;
    $pdf->Cell($securiaceModernUsableWidth * 0.3, 4, 'Page ' . $securiaceModernRelativePage . ' of ' . $securiaceModernPageCount, 0, 1, 'R');
}

$pdf->SetAutoPageBreak($securiaceModernPreviousAutoPageBreak, $securiaceModernPreviousBreakMargin);
$pdf->setPage($securiaceModernFinalPage);

restore_error_handler();
// Whoops may already have set HTTP 500 during init for unrelated warnings
// (for example duplicate hook constants). TCPDF may also leave E_DEPRECATED
// noise after this include returns. A completed invoice page must not inherit
// that poison, but may clear only a 5xx present before rendering; a new
// rendering error must remain visible.
$securiaceModernHttpStatus = function_exists('http_response_code') ? http_response_code() : false;
if (is_int($securiaceModernInitialHttpStatus)
    && $securiaceModernInitialHttpStatus >= 500
    && is_int($securiaceModernHttpStatus)
    && $securiaceModernHttpStatus >= 500
    && $securiaceModernRenderErrorObserved === false
) {
    http_response_code(200);
}
