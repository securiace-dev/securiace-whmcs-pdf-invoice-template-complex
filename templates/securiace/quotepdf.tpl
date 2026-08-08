<?php

/**
 * Securiace Modern WHMCS PDF Quote Template
 *
 * Target: WHMCS 8.x and 9.x, PHP 7.4 through 8.3, TCPDF.
 * Install as quotepdf.tpl in the active WHMCS system theme.
 *
 * The template intentionally presents the validity date instead of the WHMCS
 * stage. On first email delivery WHMCS 8.x generates the attachment before it
 * updates the quote to Delivered, so a stage badge can be factually stale.
 */

$securiaceQuoteIsTcpdfDeprecation = static function ($error) {
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
$securiaceQuotePreviousErrorHandler = null;
$securiaceQuotePreviousErrorHandler = set_error_handler(
    static function ($severity, $message, $file, $line) use (
        &$securiaceQuotePreviousErrorHandler,
        $securiaceQuoteIsTcpdfDeprecation
    ) {
        if ($securiaceQuoteIsTcpdfDeprecation(array(
            'type' => $severity,
            'file' => $file,
        ))) {
            return true;
        }
        if (is_callable($securiaceQuotePreviousErrorHandler)) {
            return call_user_func(
                $securiaceQuotePreviousErrorHandler,
                $severity,
                $message,
                $file,
                $line
            );
        }
        return false;
    }
);

$securiaceQuoteDefaults = array(
    'company_email' => '',
    'company_phone' => '',
    'company_pan' => '',
    'company_msme' => '',
    'jurisdiction' => '',
    'date_order' => 'DMY',
    'acceptance_note' => 'Accept through the WHMCS client area or by written confirmation from an authorised contact. Acceptance confirms the scope and commercial terms shown in this quote.',
);
$securiaceQuoteConfig = $securiaceQuoteDefaults;
$securiaceQuoteConfigPath = defined('ROOTDIR')
    ? ROOTDIR . '/includes/securiace-invoice-config.php'
    : '';
$securiaceQuoteBootstrapWarnings = array();
if ($securiaceQuoteConfigPath !== '' && is_readable($securiaceQuoteConfigPath)) {
    try {
        $securiaceQuoteLoadedConfig = include $securiaceQuoteConfigPath;
    } catch (Throwable $securiaceQuoteConfigException) {
        $securiaceQuoteLoadedConfig = null;
        $securiaceQuoteBootstrapWarnings[] = 'protected-config-include-failed';
    }
    if (is_array($securiaceQuoteLoadedConfig)) {
        $securiaceQuoteConfig = array_replace($securiaceQuoteConfig, $securiaceQuoteLoadedConfig);
    } elseif ($securiaceQuoteLoadedConfig !== null) {
        $securiaceQuoteBootstrapWarnings[] = 'protected-config-invalid-result';
    }
}
if (isset($securiaceQuoteTemplateConfig) && is_array($securiaceQuoteTemplateConfig)) {
    $securiaceQuoteConfig = array_replace($securiaceQuoteConfig, $securiaceQuoteTemplateConfig);
}
foreach (array_keys($securiaceQuoteDefaults) as $securiaceQuoteConfigKey) {
    $securiaceQuoteConfigValue = isset($securiaceQuoteConfig[$securiaceQuoteConfigKey])
        ? $securiaceQuoteConfig[$securiaceQuoteConfigKey]
        : '';
    if (!is_scalar($securiaceQuoteConfigValue)
        && !(is_object($securiaceQuoteConfigValue) && method_exists($securiaceQuoteConfigValue, '__toString'))
    ) {
        $securiaceQuoteConfigValue = '';
    }
    $securiaceQuoteConfig[$securiaceQuoteConfigKey] = trim((string) $securiaceQuoteConfigValue);
}

// WHMCS passes the company name, domain, and Pay To block into quote PDFs,
// while email and tax settings may need to be read through the supported
// settings model. Tests and integrations can inject the same non-secret map.
$securiaceQuoteWhmcsSettings = isset($securiacePdfSettings) && is_array($securiacePdfSettings)
    ? $securiacePdfSettings
    : array();
$securiaceQuoteSettingNames = array(
    'company_email' => 'Email',
    'company_url' => 'Domain',
    'tax_code' => 'TaxCode',
);
if (class_exists('\\WHMCS\\Config\\Setting')) {
    foreach ($securiaceQuoteSettingNames as $securiaceQuoteSettingKey => $securiaceQuoteSettingName) {
        if (array_key_exists($securiaceQuoteSettingKey, $securiaceQuoteWhmcsSettings)) {
            continue;
        }
        try {
            $securiaceQuoteWhmcsSettings[$securiaceQuoteSettingKey] =
                \WHMCS\Config\Setting::getValue($securiaceQuoteSettingName);
        } catch (Throwable $securiaceQuoteSettingException) {
            $securiaceQuoteWhmcsSettings[$securiaceQuoteSettingKey] = '';
        }
    }
}

$securiaceQuotePlainMultiline = static function ($value) {
    $text = (string) $value;
    $text = preg_replace('/<\s*br\s*\/?>/iu', "\n", $text);
    $text = preg_replace('/<\/?(p|div|li|h[1-6])\b[^>]*>/iu', "\n", $text);
    $text = strip_tags($text);
    $text = html_entity_decode($text, ENT_QUOTES | ENT_HTML5, 'UTF-8');
    $text = str_replace(array("\r\n", "\r"), "\n", $text);
    $lines = array();
    foreach (explode("\n", $text) as $line) {
        $line = preg_replace('/[\t ]+/u', ' ', $line);
        $line = trim($line === null ? '' : $line);
        if ($line !== '' || (!empty($lines) && end($lines) !== '')) {
            $lines[] = $line;
        }
    }
    return trim(implode("\n", $lines));
};
$securiaceQuotePlainText = static function ($value) use ($securiaceQuotePlainMultiline) {
    $text = $securiaceQuotePlainMultiline($value);
    $text = preg_replace('/\s+/u', ' ', $text);
    return trim($text === null ? '' : $text);
};
$securiaceQuoteEscape = static function ($value) {
    return htmlspecialchars((string) $value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
};
$securiaceQuoteRichHtml = static function ($value) {
    $html = (string) $value;
    $html = preg_replace('/<!--.*?-->/su', '', $html);
    do {
        $previous = $html;
        $html = preg_replace(
            '#<\s*(script|style|iframe|object|embed|svg|math|form|button|textarea|select|video|audio)\b[^>]*>.*?<\s*/\s*\1\s*>#isu',
            '',
            $html
        );
    } while ($html !== $previous);
    $html = preg_replace(
        '#<\s*(script|style|iframe|object|embed|svg|math|form|input|button|textarea|select|video|audio)\b[^>]*/?\s*>#isu',
        '',
        $html
    );
    $html = strip_tags($html, '<p><br><strong><b><em><i><u><ul><ol><li><h1><h2><h3>');
    $html = preg_replace_callback(
        '/<\s*(\/?)\s*(p|br|strong|b|em|i|u|ul|ol|li|h1|h2|h3)\b[^>]*>/iu',
        static function ($match) {
            $slash = $match[1] === '/' ? '/' : '';
            $tag = strtolower($match[2]);
            if ($tag === 'br') {
                return '<br />';
            }
            return '<' . $slash . $tag . '>';
        },
        $html
    );
    return trim($html === null ? '' : $html);
};
$securiaceQuoteTruncate = static function ($value, $maxLength) {
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
$securiaceQuoteIsUsableImage = static function ($path) {
    return is_string($path) && $path !== '' && is_readable($path) && @getimagesize($path) !== false;
};

$securiaceQuoteParseDate = static function ($value) use (&$securiaceQuoteConfig) {
    $value = trim((string) $value);
    if ($value === '' || preg_match('/^[0\s.\/:\-]+$/', $value)) {
        return null;
    }

    $dateOrder = strtoupper(trim((string) $securiaceQuoteConfig['date_order']));
    $dateOrder = in_array($dateOrder, array('DMY', 'MDY'), true) ? $dateOrder : 'DMY';
    $numericFormats = preg_match('/^\d{4}[\/.-]/', $value)
        ? array('!Y-m-d', '!Y/m/d', '!Y.m.d')
        : ($dateOrder === 'MDY'
            ? array('!m/d/Y', '!m-d-Y', '!m.d.Y', '!d/m/Y', '!d-m-Y', '!d.m.Y')
            : array('!d/m/Y', '!d-m-Y', '!d.m.Y', '!m/d/Y', '!m-d-Y', '!m.d.Y'));
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
$securiaceQuoteFormatDate = static function ($value, $fallback) use (
    $securiaceQuoteParseDate,
    $securiaceQuotePlainText
) {
    $value = $securiaceQuotePlainText($value);
    if ($value === '' || preg_match('/^[0\s.\/:\-]+$/', $value)) {
        return $fallback;
    }

    $date = $securiaceQuoteParseDate($value);
    if ($date instanceof DateTimeImmutable) {
        return $date->format('j M Y');
    }

    // Preserve localized WHMCS output, but fail closed for malformed numeric
    // dates instead of exporting zero dates or impossible calendar values.
    return preg_match('/^\d{1,4}\D+\d{1,2}\D+\d{1,4}$/', $value)
        ? $fallback
        : $value;
};

$securiaceQuoteCurrency = isset($GLOBALS['currency']) && is_array($GLOBALS['currency'])
    ? $GLOBALS['currency']
    : array();
$securiaceQuoteCurrencyCode = !empty($securiaceQuoteCurrency['code'])
    ? strtoupper(trim((string) $securiaceQuoteCurrency['code']))
    : '';
$securiaceQuoteFormatMoney = static function ($value) use ($securiaceQuoteCurrency) {
    if (is_object($value) && method_exists($value, '__toString')) {
        $value = (string) $value;
    }
    if (is_string($value) && preg_match('/[^0-9\s.,()\-]/u', $value)) {
        return trim($value);
    }
    $numeric = is_numeric($value) ? (float) $value : 0.0;
    if (function_exists('formatCurrency')) {
        try {
            return (string) formatCurrency($numeric);
        } catch (Throwable $exception) {
            // Fall through to a deterministic local formatter for fixtures.
        }
    }
    $prefix = isset($securiaceQuoteCurrency['prefix']) ? trim((string) $securiaceQuoteCurrency['prefix']) : '';
    $suffix = isset($securiaceQuoteCurrency['suffix']) ? trim((string) $securiaceQuoteCurrency['suffix']) : '';
    return ($prefix !== '' ? $prefix . ' ' : '')
        . number_format($numeric, 2, '.', ',')
        . ($suffix !== '' ? ' ' . $suffix : '');
};

$securiaceQuoteFont = isset($pdfFont) && trim((string) $pdfFont) !== ''
    ? trim((string) $pdfFont)
    : 'dejavusans';
$securiaceQuoteNumber = isset($quotenumber) && trim((string) $quotenumber) !== ''
    ? trim((string) $quotenumber)
    : '—';
$securiaceQuoteSubject = isset($subject) && trim((string) $subject) !== ''
    ? $securiaceQuotePlainText($subject)
    : 'Commercial proposal';
$securiaceQuoteDateWarnings = array();
$securiaceQuoteIssuedDate = $securiaceQuoteParseDate(isset($datecreated) ? $datecreated : '');
$securiaceQuoteValidUntilDate = $securiaceQuoteParseDate(isset($validuntil) ? $validuntil : '');
$securiaceQuoteIssuedDisplay = $securiaceQuoteFormatDate(
    isset($datecreated) ? $datecreated : '',
    'Not provided'
);
$securiaceQuoteValidUntilDisplay = $securiaceQuoteFormatDate(
    isset($validuntil) ? $validuntil : '',
    'No expiry stated'
);
$securiaceQuoteIssuedLabel = 'Issued';
$securiaceQuoteEffectiveIssueDate = $securiaceQuoteIssuedDate;
if ($securiaceQuoteIssuedDisplay === 'Not provided') {
    $securiaceQuoteDateWarnings[] = 'issue-date-invalid-or-missing';
    $securiaceQuoteGeneratedDateSource = function_exists('getTodaysDate')
        ? getTodaysDate()
        : date('j M Y');
    $securiaceQuoteIssuedDisplay = $securiaceQuoteFormatDate(
        $securiaceQuoteGeneratedDateSource,
        date('j M Y')
    );
    $securiaceQuoteIssuedLabel = 'Generated';
    $securiaceQuoteEffectiveIssueDate = $securiaceQuoteParseDate($securiaceQuoteIssuedDisplay);
}
if ($securiaceQuoteValidUntilDisplay === 'No expiry stated') {
    $securiaceQuoteDateWarnings[] = 'valid-until-invalid-or-missing';
}
if ($securiaceQuoteEffectiveIssueDate instanceof DateTimeImmutable
    && $securiaceQuoteValidUntilDate instanceof DateTimeImmutable
    && $securiaceQuoteValidUntilDate < $securiaceQuoteEffectiveIssueDate
) {
    $securiaceQuoteValidUntilDisplay = 'Review required';
    $securiaceQuoteDateWarnings[] = 'valid-until-precedes-issue-date';
}
$securiaceQuoteHasValidUntil = !in_array(
    $securiaceQuoteValidUntilDisplay,
    array('No expiry stated', 'Review required'),
    true
);
$securiaceQuoteNeedsDateReview = $securiaceQuoteValidUntilDisplay === 'Review required';
$securiaceQuoteProposalHtml = isset($proposal) ? $securiaceQuoteRichHtml($proposal) : '';
$securiaceQuoteProposalPlain = isset($proposal) ? $securiaceQuotePlainMultiline($proposal) : '';
$securiaceQuoteItems = isset($lineitems) && is_array($lineitems) ? $lineitems : array();
if (!isset($clientsdetails) || !is_array($clientsdetails)) {
    $clientsdetails = array();
}

$securiaceQuoteProfilePath = '';
foreach (array(
    defined('ROOTDIR') ? ROOTDIR . '/includes/securiace-pdf-profile.php' : '',
    __DIR__ . '/securiace-pdf-profile.php',
) as $securiaceQuoteProfileCandidate) {
    if ($securiaceQuoteProfileCandidate !== '' && is_readable($securiaceQuoteProfileCandidate)) {
        $securiaceQuoteProfilePath = $securiaceQuoteProfileCandidate;
        break;
    }
}
$securiaceQuoteProfileWarnings = $securiaceQuoteBootstrapWarnings;
$securiaceQuoteScalarText = static function ($value, $fallback = '') {
    if (is_scalar($value)
        || (is_object($value) && method_exists($value, '__toString'))
    ) {
        return trim((string) $value);
    }
    return (string) $fallback;
};
$securiaceQuoteNormalizeIssuerProfile = static function (
    $rawProfile,
    array $baseWarnings = array()
) use ($securiaceQuoteScalarText) {
    $warnings = array();
    foreach ($baseWarnings as $warning) {
        $warningText = $securiaceQuoteScalarText($warning);
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
        'business_name' => $securiaceQuoteScalarText(
            isset($identity['business_name']) ? $identity['business_name'] : '',
            'Issuer'
        ),
        'address_lines' => array(),
        'support_email' => $securiaceQuoteScalarText(isset($identity['support_email']) ? $identity['support_email'] : ''),
        'mobile' => $securiaceQuoteScalarText(isset($identity['mobile']) ? $identity['mobile'] : ''),
        'website' => $securiaceQuoteScalarText(isset($identity['website']) ? $identity['website'] : ''),
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
            'label' => $securiaceQuoteScalarText(isset($registration['label']) ? $registration['label'] : ''),
            'value' => $securiaceQuoteScalarText(isset($registration['value']) ? $registration['value'] : ''),
            'valid' => !empty($registration['valid']),
            'source' => $securiaceQuoteScalarText(isset($registration['source']) ? $registration['source'] : ''),
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
            'account_name' => $securiaceQuoteScalarText(isset($bankAccount['account_name']) ? $bankAccount['account_name'] : ''),
            'account_number' => $securiaceQuoteScalarText(isset($bankAccount['account_number']) ? $bankAccount['account_number'] : ''),
            'routing_code' => $securiaceQuoteScalarText(isset($bankAccount['routing_code']) ? $bankAccount['routing_code'] : ''),
            'branch' => $securiaceQuoteScalarText(isset($bankAccount['branch']) ? $bankAccount['branch'] : ''),
            'account_type' => $securiaceQuoteScalarText(isset($bankAccount['account_type']) ? $bankAccount['account_type'] : ''),
            'bank_name' => $securiaceQuoteScalarText(isset($bankAccount['bank_name']) ? $bankAccount['bank_name'] : ''),
            'currencies' => is_array(isset($bankAccount['currencies']) ? $bankAccount['currencies'] : array())
                ? array_values(array_unique(array_map(
                    'strtoupper',
                    array_filter(
                        array_map(
                            static function ($value) use ($securiaceQuoteScalarText) {
                                return $securiaceQuoteScalarText($value);
                            },
                            array_values(isset($bankAccount['currencies']) ? $bankAccount['currencies'] : array())
                        ),
                        static function ($value) { return $value !== ''; }
                    )
                )))
                : array(),
            'source' => $securiaceQuoteScalarText(isset($bankAccount['source']) ? $bankAccount['source'] : ''),
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
        $diagnosticWarning = $securiaceQuoteScalarText($diagnosticWarning);
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
                'id' => $securiaceQuoteScalarText(isset($upi['id']) ? $upi['id'] : ''),
                'payee_name' => $securiaceQuoteScalarText(isset($upi['payee_name']) ? $upi['payee_name'] : ''),
                'currencies' => $upiCurrencies,
                'valid' => !empty($upi['valid']),
                'source' => $securiaceQuoteScalarText(isset($upi['source']) ? $upi['source'] : ''),
            ),
            'bank_accounts' => $bankAccounts,
        ),
        'policy' => array(
            'jurisdiction' => $securiaceQuoteScalarText(isset($policy['jurisdiction']) ? $policy['jurisdiction'] : ''),
            'tds_note' => $securiaceQuoteScalarText(isset($policy['tds_note']) ? $policy['tds_note'] : ''),
            'late_fee_text' => $securiaceQuoteScalarText(isset($policy['late_fee_text']) ? $policy['late_fee_text'] : ''),
        ),
        'diagnostics' => array(
            'sources' => isset($diagnostics['sources']) && is_array($diagnostics['sources']) ? $diagnostics['sources'] : array(),
            'conflicts' => isset($diagnostics['conflicts']) && is_array($diagnostics['conflicts']) ? $diagnostics['conflicts'] : array(),
            'warnings' => $diagnosticWarnings,
            'unknown_labels' => isset($diagnostics['unknown_labels']) && is_array($diagnostics['unknown_labels']) ? $diagnostics['unknown_labels'] : array(),
        ),
    );
};

$securiaceQuoteProfileResolver = null;
$securiaceQuoteProfileResolved = false;
if ($securiaceQuoteProfilePath !== '') {
    try {
        $securiaceQuoteProfileResolver = include $securiaceQuoteProfilePath;
    } catch (Throwable $securiaceQuoteProfileException) {
        $securiaceQuoteProfileWarnings[] = 'profile-helper-include-failed';
    }
}
$securiaceQuoteCompanyNameInput = isset($companyname) ? $companyname : '';
$securiaceQuoteCompanyUrlInput = isset($companyurl) && trim((string) $companyurl) !== ''
    ? $companyurl
    : (isset($securiaceQuoteWhmcsSettings['company_url']) ? $securiaceQuoteWhmcsSettings['company_url'] : '');
$securiaceQuoteCompanyEmailInput = isset($securiaceQuoteWhmcsSettings['company_email'])
    ? $securiaceQuoteWhmcsSettings['company_email']
    : '';
$securiaceQuoteTaxCodeInput = isset($taxCode) && trim((string) $taxCode) !== ''
    ? $taxCode
    : (isset($securiaceQuoteWhmcsSettings['tax_code']) ? $securiaceQuoteWhmcsSettings['tax_code'] : '');

if ($securiaceQuoteProfileResolver instanceof Closure) {
    $securiaceQuoteProfileResolved = false;
    try {
        $securiaceQuoteIssuerProfile = $securiaceQuoteProfileResolver(array(
            'company_name' => $securiaceQuoteCompanyNameInput,
            'company_email' => $securiaceQuoteCompanyEmailInput,
            'company_url' => $securiaceQuoteCompanyUrlInput,
            'tax_code' => $securiaceQuoteTaxCodeInput,
            'tax_label' => isset($taxIdLabel) ? $taxIdLabel : 'GSTIN',
            'pay_to' => isset($companyaddress) ? $companyaddress : array(),
            'default_bank_currencies' => array('INR'),
            'fallback' => $securiaceQuoteConfig,
        ));
        if (is_array($securiaceQuoteIssuerProfile)) {
            $securiaceQuoteProfileResolved = true;
        } else {
            $securiaceQuoteProfileWarnings[] = 'profile-helper-invalid-result';
        }
    } catch (Throwable $securiaceQuoteProfileException) {
        $securiaceQuoteProfileWarnings[] = 'profile-helper-runtime-failed';
    }
}
if (empty($securiaceQuoteProfileWarnings) && empty($securiaceQuoteProfileResolved)) {
    $securiaceQuoteProfileWarnings[] = $securiaceQuoteProfilePath === ''
        ? 'profile-helper-unavailable'
        : 'profile-helper-invalid';
}
if (!$securiaceQuoteProfileResolved) {
    // Never render the raw Pay To block when the shared parser is unavailable;
    // it can contain bank and UPI credentials that do not belong on a quote.
    $securiaceQuoteFallbackCompanyName = trim((string) $securiaceQuoteCompanyNameInput);
    if ($securiaceQuoteFallbackCompanyName === '') {
        $securiaceQuoteFallbackCompanyName = 'Issuer';
    }
    $securiaceQuoteIssuerProfile = array(
        'identity' => array(
            'business_name' => $securiaceQuoteFallbackCompanyName,
            'address_lines' => array(),
            'support_email' => trim((string) $securiaceQuoteCompanyEmailInput),
            'support_email_valid' => true,
            'mobile' => trim((string) $securiaceQuoteConfig['company_phone']),
        ),
        'registrations' => array(),
        'payment' => array(
            'upi' => array(
                'id' => '',
                'payee_name' => $securiaceQuoteFallbackCompanyName,
                'valid' => false,
            ),
            'bank_accounts' => array(),
        ),
        'policy' => array(
            'jurisdiction' => trim((string) $securiaceQuoteConfig['jurisdiction']),
            'tds_note' => trim((string) (isset($securiaceQuoteConfig['tds_note']) ? $securiaceQuoteConfig['tds_note'] : '')),
            'late_fee_text' => trim((string) (isset($securiaceQuoteConfig['late_fee_text']) ? $securiaceQuoteConfig['late_fee_text'] : '')),
        ),
        'diagnostics' => array(
            'sources' => array(),
            'warnings' => array_values(array_unique($securiaceQuoteProfileWarnings)),
            'conflicts' => array(),
            'unknown_labels' => array(),
        ),
    );
}
$securiaceQuoteIssuerProfile = $securiaceQuoteNormalizeIssuerProfile(
    $securiaceQuoteIssuerProfile,
    $securiaceQuoteProfileWarnings
);

$securiaceQuoteCompanyName = trim((string) $securiaceQuoteIssuerProfile['identity']['business_name']);
$securiaceQuoteCompanyLines = array();
foreach ($securiaceQuoteIssuerProfile['identity']['address_lines'] as $securiaceQuoteAddressLine) {
    $securiaceQuoteAddressLine = trim((string) $securiaceQuoteAddressLine);
    if ($securiaceQuoteAddressLine !== '') {
        $securiaceQuoteCompanyLines[] = $securiaceQuoteAddressLine;
    }
}
if ($securiaceQuoteIssuerProfile['identity']['support_email'] !== ''
    && $securiaceQuoteIssuerProfile['identity']['support_email_valid']
) {
    $securiaceQuoteCompanyLines[] = 'Helpdesk · '
        . $securiaceQuoteIssuerProfile['identity']['support_email'];
}
if ($securiaceQuoteIssuerProfile['identity']['mobile'] !== '') {
    $securiaceQuoteCompanyLines[] = 'Mobile · ' . $securiaceQuoteIssuerProfile['identity']['mobile'];
}
$securiaceQuoteSellerRegistrations = array();
foreach ($securiaceQuoteIssuerProfile['registrations'] as $securiaceQuoteRegistration) {
    if (!empty($securiaceQuoteRegistration['valid'])) {
        $securiaceQuoteSellerRegistrations[] = $securiaceQuoteRegistration['label']
            . ' · ' . $securiaceQuoteRegistration['value'];
    }
}
$securiaceQuoteIssuerDiagnostics = $securiaceQuoteIssuerProfile['diagnostics'];
$securiaceQuotePaymentDetailsRendered = false;

$securiaceQuoteClientName = !empty($clientsdetails['companyname'])
    ? trim((string) $clientsdetails['companyname'])
    : trim(
        (isset($clientsdetails['firstname']) ? $clientsdetails['firstname'] : '')
        . ' '
        . (isset($clientsdetails['lastname']) ? $clientsdetails['lastname'] : '')
    );
if ($securiaceQuoteClientName === '') {
    $securiaceQuoteClientName = 'Prospective client';
}
$securiaceQuoteClientLines = array();
if (!empty($clientsdetails['companyname'])) {
    $contactName = trim(
        (isset($clientsdetails['firstname']) ? $clientsdetails['firstname'] : '')
        . ' '
        . (isset($clientsdetails['lastname']) ? $clientsdetails['lastname'] : '')
    );
    if ($contactName !== '') {
        $securiaceQuoteClientLines[] = 'Attn: ' . $contactName;
    }
}
foreach (array('address1', 'address2') as $addressKey) {
    if (!empty($clientsdetails[$addressKey])) {
        $securiaceQuoteClientLines[] = trim((string) $clientsdetails[$addressKey]);
    }
}
$clientCity = array();
foreach (array('city', 'state', 'postcode') as $cityKey) {
    if (!empty($clientsdetails[$cityKey])) {
        $clientCity[] = trim((string) $clientsdetails[$cityKey]);
    }
}
if (!empty($clientCity)) {
    $securiaceQuoteClientLines[] = implode(', ', $clientCity);
}
if (!empty($clientsdetails['country'])) {
    $securiaceQuoteClientLines[] = trim((string) $clientsdetails['country']);
}
if (!empty($clientsdetails['email'])) {
    $securiaceQuoteClientLines[] = 'Email · ' . trim((string) $clientsdetails['email']);
}
if (!empty($clientsdetails['phonenumber'])) {
    $securiaceQuoteClientLines[] = 'Phone · ' . trim((string) $clientsdetails['phonenumber']);
}

$securiaceQuoteBrand = array(79, 11, 112);
$securiaceQuoteBrandDark = array(50, 16, 68);
$securiaceQuoteBrandSoft = array(245, 240, 247);
$securiaceQuoteInk = array(32, 28, 36);
$securiaceQuoteMuted = array(109, 102, 114);
$securiaceQuoteLine = array(221, 215, 225);
$securiaceQuoteSurface = array(248, 246, 248);
$securiaceQuotePaper = array(255, 254, 253);
$securiaceQuoteWarning = array(166, 56, 47);
$securiaceQuoteWarningSoft = array(252, 237, 236);
$securiaceQuoteWarningLine = array(232, 185, 181);

$securiaceQuoteStartPage = $pdf->getPage();
$securiaceQuoteMargin = 14.0;
$securiaceQuoteTopMargin = 20.0;
$securiaceQuoteBottomMargin = 15.0;
$pdf->SetMargins($securiaceQuoteMargin, $securiaceQuoteTopMargin, $securiaceQuoteMargin);
$pdf->SetAutoPageBreak(true, $securiaceQuoteBottomMargin);
$pdf->SetFont($securiaceQuoteFont, '', 8);
$securiaceQuotePageWidth = $pdf->getPageWidth();
$securiaceQuotePageHeight = $pdf->getPageHeight();
$securiaceQuoteUsableWidth = $securiaceQuotePageWidth - ($securiaceQuoteMargin * 2);

$securiaceQuotePaintPage = static function () use (
    $pdf,
    $securiaceQuotePaper,
    $securiaceQuotePageWidth,
    $securiaceQuotePageHeight
) {
    $pdf->SetFillColor($securiaceQuotePaper[0], $securiaceQuotePaper[1], $securiaceQuotePaper[2]);
    $pdf->Rect(0, 0, $securiaceQuotePageWidth, $securiaceQuotePageHeight, 'F');
};
$securiaceQuotePaintPage();
$securiaceQuoteDrawCard = static function ($x, $y, $width, $height, $fill, $line, $radius = 2.65, $corners = '1111') use ($pdf) {
    $pdf->SetFillColor($fill[0], $fill[1], $fill[2]);
    $pdf->SetDrawColor($line[0], $line[1], $line[2]);
    $pdf->SetLineWidth(0.25);
    if (method_exists($pdf, 'RoundedRect')) {
        $pdf->RoundedRect($x, $y, $width, $height, min($radius, $height / 2), $corners, 'DF');
    } else {
        $pdf->Rect($x, $y, $width, $height, 'DF');
    }
};
$securiaceQuoteDrawLabel = static function ($label, $x, $y, $width) use ($pdf, $securiaceQuoteFont, $securiaceQuoteBrand) {
    $pdf->SetFont($securiaceQuoteFont, 'B', 6.5);
    $pdf->SetTextColor($securiaceQuoteBrand[0], $securiaceQuoteBrand[1], $securiaceQuoteBrand[2]);
    $pdf->SetXY($x, $y);
    $pdf->Cell($width, 3.5, strtoupper((string) $label), 0, 0, 'L');
};
$securiaceQuoteEnsureSpace = static function ($height) use (
    $pdf,
    $securiaceQuotePageHeight,
    $securiaceQuoteBottomMargin,
    $securiaceQuoteTopMargin,
    $securiaceQuotePaintPage
) {
    if ($pdf->GetY() + $height > $securiaceQuotePageHeight - $securiaceQuoteBottomMargin) {
        $pdf->AddPage();
        $securiaceQuotePaintPage();
        $pdf->SetY($securiaceQuoteTopMargin);
        return true;
    }
    return false;
};

// Header and quote identity.
$securiaceQuoteHeaderY = $securiaceQuoteTopMargin;
$securiaceQuoteLogoPath = '';
if (defined('ROOTDIR')) {
    foreach (array('logo.png', 'logo.jpg', 'logo.jpeg') as $logoFile) {
        $candidateLogo = ROOTDIR . '/assets/img/' . $logoFile;
        if ($securiaceQuoteIsUsableImage($candidateLogo)) {
            $securiaceQuoteLogoPath = $candidateLogo;
            break;
        }
    }
}
$securiaceQuoteLogoRendered = false;
if ($securiaceQuoteLogoPath !== '') {
    try {
        $pdf->Image($securiaceQuoteLogoPath, $securiaceQuoteMargin, $securiaceQuoteHeaderY, 42, 0, '', '', '', false, 300);
        $securiaceQuoteLogoRendered = true;
    } catch (Throwable $securiaceQuoteLogoException) {
        $securiaceQuoteIssuerDiagnostics['warnings'][] = 'logo-render-failed';
    }
}
if (!$securiaceQuoteLogoRendered) {
    $pdf->SetFont($securiaceQuoteFont, 'B', 17);
    $pdf->SetTextColor($securiaceQuoteInk[0], $securiaceQuoteInk[1], $securiaceQuoteInk[2]);
    $pdf->SetXY($securiaceQuoteMargin, $securiaceQuoteHeaderY + 1);
    $pdf->Cell(100, 7, $securiaceQuoteCompanyName, 0, 1, 'L');
}
$pdf->SetFont($securiaceQuoteFont, 'B', 6.5);
$pdf->SetTextColor($securiaceQuoteBrand[0], $securiaceQuoteBrand[1], $securiaceQuoteBrand[2]);
$pdf->SetXY($securiaceQuotePageWidth - $securiaceQuoteMargin - 68, $securiaceQuoteHeaderY);
$pdf->Cell(68, 4, 'COMMERCIAL PROPOSAL', 0, 1, 'R');
$pdf->SetFont($securiaceQuoteFont, 'B', 22);
$pdf->SetTextColor($securiaceQuoteInk[0], $securiaceQuoteInk[1], $securiaceQuoteInk[2]);
$pdf->SetX($securiaceQuotePageWidth - $securiaceQuoteMargin - 68);
$pdf->Cell(68, 8, 'Quote', 0, 1, 'R');
$validityLabel = $securiaceQuoteHasValidUntil
    ? 'VALID UNTIL ' . $securiaceQuoteValidUntilDisplay
    : strtoupper($securiaceQuoteValidUntilDisplay);
$pdf->SetFont($securiaceQuoteFont, 'B', 6.5);
$validityWidth = max(38, min(68, $pdf->GetStringWidth($validityLabel) + 12));
$validityX = $securiaceQuotePageWidth - $securiaceQuoteMargin - $validityWidth;
$validityFill = $securiaceQuoteNeedsDateReview ? $securiaceQuoteWarningSoft : $securiaceQuoteBrandSoft;
$validityLine = $securiaceQuoteNeedsDateReview ? $securiaceQuoteWarningLine : $securiaceQuoteLine;
$validityText = $securiaceQuoteNeedsDateReview ? $securiaceQuoteWarning : $securiaceQuoteBrand;
$securiaceQuoteDrawCard($validityX, $securiaceQuoteHeaderY + 14, $validityWidth, 7, $validityFill, $validityLine, 3.5);
$pdf->SetFont($securiaceQuoteFont, 'B', 6.5);
$pdf->SetTextColor($validityText[0], $validityText[1], $validityText[2]);
$pdf->SetXY($validityX, $securiaceQuoteHeaderY + 15.3);
$pdf->Cell($validityWidth, 4, $validityLabel, 0, 1, 'C');
$ruleY = $securiaceQuoteHeaderY + 26;
$pdf->SetDrawColor($securiaceQuoteBrand[0], $securiaceQuoteBrand[1], $securiaceQuoteBrand[2]);
$pdf->SetLineWidth(0.35);
$pdf->Line($securiaceQuoteMargin, $ruleY, $securiaceQuotePageWidth - $securiaceQuoteMargin, $ruleY);

$metaY = $ruleY + 5;
$metaWidth = ($securiaceQuoteUsableWidth - 72) / 2;
$quoteMeta = array(
    array('Quote number', $securiaceQuoteNumber),
    array($securiaceQuoteIssuedLabel, $securiaceQuoteIssuedDisplay),
);
foreach ($quoteMeta as $metaIndex => $metaItem) {
    $metaX = $securiaceQuoteMargin + ($metaIndex * $metaWidth);
    $pdf->SetFont($securiaceQuoteFont, '', 6.5);
    $pdf->SetTextColor($securiaceQuoteMuted[0], $securiaceQuoteMuted[1], $securiaceQuoteMuted[2]);
    $pdf->SetXY($metaX, $metaY);
    $pdf->Cell($metaWidth - 3, 3.5, $metaItem[0], 0, 1, 'L');
    $pdf->SetFont($securiaceQuoteFont, 'B', 8);
    $pdf->SetTextColor($securiaceQuoteInk[0], $securiaceQuoteInk[1], $securiaceQuoteInk[2]);
    $pdf->SetX($metaX);
    $pdf->Cell($metaWidth - 3, 4.5, (string) $metaItem[1], 0, 1, 'L');
}
$summaryX = $securiaceQuotePageWidth - $securiaceQuoteMargin - 68;
$pdf->SetFont($securiaceQuoteFont, 'B', 7.3);
$summaryTextHeight = $pdf->getStringHeight(60, $securiaceQuoteSubject);
$summaryHeight = max(16, $summaryTextHeight + 9);
$summaryUsesFullWidth = $summaryHeight > 30;
if ($summaryUsesFullWidth) {
    $summaryX = $securiaceQuoteMargin;
    $summaryY = $metaY + 12;
    $summaryWidth = $securiaceQuoteUsableWidth;
    $summaryInnerWidth = $summaryWidth - 8;
    $summaryTextHeight = $pdf->getStringHeight($summaryInnerWidth, $securiaceQuoteSubject);
    $summaryHeight = max(16, $summaryTextHeight + 9);
} else {
    $summaryY = $metaY - 1;
    $summaryWidth = 68;
    $summaryInnerWidth = 60;
}
$securiaceQuoteDrawCard(
    $summaryX,
    $summaryY,
    $summaryWidth,
    $summaryHeight,
    $securiaceQuoteBrandSoft,
    $securiaceQuoteLine
);
$securiaceQuoteDrawLabel('Proposal summary', $summaryX + 4, $summaryY + 2.5, $summaryInnerWidth);
$pdf->SetFont($securiaceQuoteFont, 'B', 7.3);
$pdf->SetTextColor($securiaceQuoteBrandDark[0], $securiaceQuoteBrandDark[1], $securiaceQuoteBrandDark[2]);
$pdf->SetXY($summaryX + 4, $summaryY + 7);
$pdf->MultiCell($summaryInnerWidth, 3.6, $securiaceQuoteSubject, 0, 'L');
$pdf->SetY($summaryY + $summaryHeight + 4);

// Recipient and issuer cards.
$partyGap = 4;
$partyWidth = ($securiaceQuoteUsableWidth - $partyGap) / 2;
$partyY = $pdf->GetY();
$clientText = implode("\n", $securiaceQuoteClientLines);
$companyText = implode("\n", $securiaceQuoteCompanyLines);
$registrationText = implode("\n", $securiaceQuoteSellerRegistrations);
$pdf->SetFont($securiaceQuoteFont, '', 7);
$clientTextHeight = $pdf->getStringHeight($partyWidth - 8, $clientText);
$companyTextHeight = $pdf->getStringHeight($partyWidth - 8, $companyText);
$registrationHeight = 0;
if ($registrationText !== '') {
    $pdf->SetFont($securiaceQuoteFont, 'B', 6.3);
    $registrationHeight = max(7, $pdf->getStringHeight($partyWidth - 12, $registrationText) + 3);
}
$partyHeight = max(
    35,
    16 + max(
        $clientTextHeight,
        $companyTextHeight + $registrationHeight + ($registrationHeight > 0 ? 2 : 0)
    )
);
$securiaceQuoteDrawCard($securiaceQuoteMargin, $partyY, $partyWidth, $partyHeight, $securiaceQuotePaper, $securiaceQuoteLine);
$issuerX = $securiaceQuoteMargin + $partyWidth + $partyGap;
$securiaceQuoteDrawCard($issuerX, $partyY, $partyWidth, $partyHeight, $securiaceQuotePaper, $securiaceQuoteLine);
$pdf->SetDrawColor($securiaceQuoteBrand[0], $securiaceQuoteBrand[1], $securiaceQuoteBrand[2]);
$pdf->SetLineWidth(0.8);
$pdf->Line($securiaceQuoteMargin + 2.65, $partyY, $securiaceQuoteMargin + $partyWidth - 2.65, $partyY);
$partyColumns = array(
    array('Prepared for', $securiaceQuoteClientName, $clientText, $securiaceQuoteMargin, ''),
    array('Prepared by', $securiaceQuoteCompanyName, $companyText, $issuerX, $registrationText),
);
foreach ($partyColumns as $partyColumn) {
    $partyX = $partyColumn[3];
    $securiaceQuoteDrawLabel($partyColumn[0], $partyX + 4, $partyY + 4, $partyWidth - 8);
    $pdf->SetFont($securiaceQuoteFont, 'B', 9);
    $pdf->SetTextColor($securiaceQuoteInk[0], $securiaceQuoteInk[1], $securiaceQuoteInk[2]);
    $pdf->SetXY($partyX + 4, $partyY + 8);
    $pdf->MultiCell($partyWidth - 8, 4, $partyColumn[1], 0, 'L');
    $pdf->SetFont($securiaceQuoteFont, '', 7);
    $pdf->SetTextColor($securiaceQuoteMuted[0], $securiaceQuoteMuted[1], $securiaceQuoteMuted[2]);
    $pdf->SetXY($partyX + 4, $pdf->GetY() + 1);
    $pdf->MultiCell($partyWidth - 8, 3.5, $partyColumn[2], 0, 'L');
    if ($partyColumn[4] !== '') {
        $registrationY = $pdf->GetY() + 1.5;
        $securiaceQuoteDrawCard(
            $partyX + 4,
            $registrationY,
            $partyWidth - 8,
            $registrationHeight,
            $securiaceQuoteBrandSoft,
            $securiaceQuoteLine,
            2.4
        );
        $pdf->SetFont($securiaceQuoteFont, 'B', 6.3);
        $pdf->SetTextColor($securiaceQuoteBrand[0], $securiaceQuoteBrand[1], $securiaceQuoteBrand[2]);
        $pdf->SetXY($partyX + 6, $registrationY + 1.2);
        $pdf->MultiCell($partyWidth - 12, 3.2, $partyColumn[4], 0, 'L');
    }
}
$pdf->SetY($partyY + $partyHeight + 5);

// Rich proposal content. Only a conservative TCPDF-compatible tag set survives.
if ($securiaceQuoteProposalHtml !== '') {
    $securiaceQuoteDrawLabel('Proposal', $securiaceQuoteMargin, $pdf->GetY(), $securiaceQuoteUsableWidth);
    $pdf->SetFont($securiaceQuoteFont, 'B', 11);
    $pdf->SetTextColor($securiaceQuoteInk[0], $securiaceQuoteInk[1], $securiaceQuoteInk[2]);
    $pdf->SetXY($securiaceQuoteMargin, $pdf->GetY() + 3.5);
    $pdf->MultiCell($securiaceQuoteUsableWidth, 5, $securiaceQuoteSubject, 0, 'L');
    $proposalMarkup = '<div style="color:#403943;font-size:8px;line-height:1.45;">'
        . $securiaceQuoteProposalHtml
        . '</div>';
    $pdf->SetFont($securiaceQuoteFont, '', 8);
    $pdf->SetTextColor($securiaceQuoteMuted[0], $securiaceQuoteMuted[1], $securiaceQuoteMuted[2]);
    $pdf->writeHTML($proposalMarkup, true, false, true, false, '');
    $pdf->Ln(2);
}

// Quote items use their real qty, unit price, discount, and line total fields.
$securiaceQuoteEnsureSpace(24);
$securiaceQuoteDrawLabel('Commercials', $securiaceQuoteMargin, $pdf->GetY(), $securiaceQuoteUsableWidth);
$pdf->SetFont($securiaceQuoteFont, 'B', 9.5);
$pdf->SetTextColor($securiaceQuoteInk[0], $securiaceQuoteInk[1], $securiaceQuoteInk[2]);
$pdf->SetXY($securiaceQuoteMargin, $pdf->GetY() + 3.5);
$pdf->Cell($securiaceQuoteUsableWidth - 40, 4.5, 'Scope and pricing', 0, 0, 'L');
$pdf->SetFont($securiaceQuoteFont, 'B', 6);
$pdf->SetTextColor($securiaceQuoteMuted[0], $securiaceQuoteMuted[1], $securiaceQuoteMuted[2]);
$pdf->Cell(40, 4.5, 'Currency · ' . ($securiaceQuoteCurrencyCode !== '' ? $securiaceQuoteCurrencyCode : '—'), 0, 1, 'R');
$pdf->Ln(1.5);

$securiaceQuoteShowDiscount = false;
foreach ($securiaceQuoteItems as $securiaceQuoteDiscountItem) {
    if (is_array($securiaceQuoteDiscountItem)
        && isset($securiaceQuoteDiscountItem['discount'])
        && is_numeric($securiaceQuoteDiscountItem['discount'])
        && abs((float) $securiaceQuoteDiscountItem['discount']) > 0.00001
    ) {
        $securiaceQuoteShowDiscount = true;
        break;
    }
}
if ($securiaceQuoteShowDiscount) {
    $itemWidths = array(
        $securiaceQuoteUsableWidth * 0.52,
        $securiaceQuoteUsableWidth * 0.07,
        $securiaceQuoteUsableWidth * 0.15,
        $securiaceQuoteUsableWidth * 0.11,
        $securiaceQuoteUsableWidth * 0.15,
    );
    $itemHeaders = array('DESCRIPTION', 'QTY', 'UNIT PRICE', 'DISCOUNT', 'AMOUNT');
} else {
    $itemWidths = array(
        $securiaceQuoteUsableWidth * 0.61,
        $securiaceQuoteUsableWidth * 0.08,
        $securiaceQuoteUsableWidth * 0.15,
        $securiaceQuoteUsableWidth * 0.16,
    );
    $itemHeaders = array('DESCRIPTION', 'QTY', 'UNIT PRICE', 'AMOUNT');
}
$drawItemHeader = static function () use (
    $pdf,
    $securiaceQuoteFont,
    $securiaceQuoteMargin,
    $securiaceQuoteUsableWidth,
    $securiaceQuoteBrand,
    $securiaceQuoteDrawCard,
    $itemWidths,
    $itemHeaders
) {
    $headerY = $pdf->GetY();
    $securiaceQuoteDrawCard($securiaceQuoteMargin, $headerY, $securiaceQuoteUsableWidth, 7, $securiaceQuoteBrand, $securiaceQuoteBrand, 2.65, '1001');
    $pdf->SetFont($securiaceQuoteFont, 'B', 6.2);
    $pdf->SetTextColor(255, 255, 255);
    $pdf->SetXY($securiaceQuoteMargin + 3, $headerY + 1.4);
    $lastHeaderIndex = count($itemHeaders) - 1;
    foreach ($itemHeaders as $headerIndex => $header) {
        $width = $itemWidths[$headerIndex] - ($headerIndex === 0 || $headerIndex === $lastHeaderIndex ? 3 : 0);
        $pdf->Cell(
            $width,
            4,
            $header,
            0,
            $headerIndex === $lastHeaderIndex ? 1 : 0,
            $headerIndex === 0 ? 'L' : 'R'
        );
    }
    $pdf->SetY($headerY + 7);
};
$drawItemsContinuation = static function () use (
    $pdf,
    $securiaceQuotePaintPage,
    $securiaceQuoteTopMargin,
    $securiaceQuoteDrawLabel,
    $securiaceQuoteMargin,
    $securiaceQuoteUsableWidth,
    $securiaceQuoteFont,
    $securiaceQuoteInk,
    $securiaceQuoteMuted,
    $securiaceQuoteCurrencyCode,
    $drawItemHeader
) {
    $pdf->AddPage();
    $securiaceQuotePaintPage();
    $pdf->SetY($securiaceQuoteTopMargin);
    $securiaceQuoteDrawLabel('Commercials · continued', $securiaceQuoteMargin, $pdf->GetY(), $securiaceQuoteUsableWidth);
    $pdf->SetFont($securiaceQuoteFont, 'B', 9);
    $pdf->SetTextColor($securiaceQuoteInk[0], $securiaceQuoteInk[1], $securiaceQuoteInk[2]);
    $pdf->SetXY($securiaceQuoteMargin, $pdf->GetY() + 3.5);
    $pdf->Cell($securiaceQuoteUsableWidth - 40, 4.5, 'Scope and pricing', 0, 0, 'L');
    $pdf->SetFont($securiaceQuoteFont, 'B', 6);
    $pdf->SetTextColor($securiaceQuoteMuted[0], $securiaceQuoteMuted[1], $securiaceQuoteMuted[2]);
    $pdf->Cell(40, 4.5, 'Currency · ' . ($securiaceQuoteCurrencyCode !== '' ? $securiaceQuoteCurrencyCode : '—'), 0, 1, 'R');
    $pdf->Ln(1.5);
    $drawItemHeader();
};
$securiaceQuoteSplitTextForHeight = static function ($text, $width, $maxHeight) use ($pdf) {
    $text = trim((string) $text);
    if ($text === '') {
        return array('', '');
    }
    if ($maxHeight <= 0) {
        return array('', $text);
    }
    if ($pdf->getStringHeight($width, $text) <= $maxHeight) {
        return array($text, '');
    }

    $hasMb = function_exists('mb_strlen') && function_exists('mb_substr');
    $length = $hasMb ? mb_strlen($text, 'UTF-8') : strlen($text);
    $slice = static function ($value, $start, $size = null) use ($hasMb) {
        if ($hasMb) {
            $effectiveSize = $size === null ? mb_strlen($value, 'UTF-8') : $size;
            return mb_substr($value, $start, $effectiveSize, 'UTF-8');
        }
        return $size === null ? substr($value, $start) : substr($value, $start, $size);
    };

    $low = 1;
    $high = $length;
    $best = 0;
    while ($low <= $high) {
        $middle = (int) floor(($low + $high) / 2);
        $candidate = $slice($text, 0, $middle);
        if ($pdf->getStringHeight($width, $candidate) <= $maxHeight) {
            $best = $middle;
            $low = $middle + 1;
        } else {
            $high = $middle - 1;
        }
    }
    if ($best < 1) {
        return array('', $text);
    }

    $prefix = $slice($text, 0, $best);
    $newlineBoundary = strrpos($prefix, "\n");
    $spaceBoundary = strrpos($prefix, ' ');
    $boundary = max($newlineBoundary === false ? 0 : $newlineBoundary, $spaceBoundary === false ? 0 : $spaceBoundary);
    if ($boundary > (int) floor($best * 0.55)) {
        $best = $boundary;
    }

    $chunk = trim($slice($text, 0, $best));
    $remainder = ltrim($slice($text, $best));
    return array($chunk, $remainder);
};

$securiaceQuoteNormalizedDescriptions = array();
$preparedQuoteItems = array();
$securiaceQuoteDetailContinuationCount = 0;
$securiaceQuoteMaxDetailContinuationHeaderHeight = 0;
foreach ($securiaceQuoteItems as $item) {
    if (!is_array($item)) {
        continue;
    }
    $description = isset($item['description']) ? $securiaceQuotePlainMultiline($item['description']) : 'Quote item';
    $securiaceQuoteNormalizedDescriptions[] = $description;
    $parts = explode("\n", $description, 2);
    $discountValue = isset($item['discount']) && is_numeric($item['discount']) ? (float) $item['discount'] : 0.0;
    $preparedQuoteItems[] = array(
        'title' => $parts[0] !== '' ? $parts[0] : 'Quote item',
        'detail' => isset($parts[1]) ? $parts[1] : '',
        'qty' => isset($item['qty']) ? (string) $item['qty'] : '—',
        'unitprice' => $securiaceQuoteFormatMoney(isset($item['unitprice']) ? $item['unitprice'] : 0),
        'discount' => rtrim(rtrim(number_format($discountValue, 2, '.', ''), '0'), '.') . '%',
        'total' => $securiaceQuoteFormatMoney(isset($item['total']) ? $item['total'] : 0),
    );
}
$drawItemHeader();
if (empty($preparedQuoteItems)) {
    $rowY = $pdf->GetY();
    $securiaceQuoteDrawCard($securiaceQuoteMargin, $rowY, $securiaceQuoteUsableWidth, 10, $securiaceQuotePaper, $securiaceQuoteLine, 2.65, '0110');
    $pdf->SetFont($securiaceQuoteFont, '', 7);
    $pdf->SetTextColor($securiaceQuoteMuted[0], $securiaceQuoteMuted[1], $securiaceQuoteMuted[2]);
    $pdf->SetXY($securiaceQuoteMargin, $rowY + 2.4);
    $pdf->Cell($securiaceQuoteUsableWidth, 4, 'No quote items found.', 0, 1, 'C');
    $pdf->SetY($rowY + 10);
} else {
    foreach ($preparedQuoteItems as $itemIndex => $preparedItem) {
        $pdf->SetFont($securiaceQuoteFont, 'B', 7.1);
        $titleHeight = $pdf->getStringHeight($itemWidths[0] - 6, $preparedItem['title']);
        $priceRowHeight = max(10, $titleHeight + 4);
        $pdf->SetFont($securiaceQuoteFont, '', 6.8);
        $remainingDetail = $preparedItem['detail'];
        $pageBottom = $securiaceQuotePageHeight - $securiaceQuoteBottomMargin;
        $minimumFirstSegment = $priceRowHeight + ($remainingDetail !== '' ? 8 : 0);
        if ($pdf->GetY() + $minimumFirstSegment > $pageBottom) {
            $drawItemsContinuation();
        }

        $rowY = $pdf->GetY();
        $detailWidth = $securiaceQuoteUsableWidth - 8;
        $detailChunk = '';
        $detailHeight = 0;
        if ($remainingDetail !== '') {
            $maxDetailHeight = max(3.5, $pageBottom - $rowY - $priceRowHeight - 4);
            list($detailChunk, $remainingDetail) = $securiaceQuoteSplitTextForHeight(
                $remainingDetail,
                $detailWidth,
                $maxDetailHeight
            );
            if ($detailChunk === '') {
                $drawItemsContinuation();
                $rowY = $pdf->GetY();
                $maxDetailHeight = max(3.5, $pageBottom - $rowY - $priceRowHeight - 4);
                list($detailChunk, $remainingDetail) = $securiaceQuoteSplitTextForHeight(
                    $remainingDetail,
                    $detailWidth,
                    $maxDetailHeight
                );
            }
            $detailHeight = $detailChunk !== '' ? $pdf->getStringHeight($detailWidth, $detailChunk) : 0;
        }
        $rowHeight = $priceRowHeight + ($detailHeight > 0 ? $detailHeight + 4 : 0);
        $rowFill = $itemIndex % 2 === 0 ? $securiaceQuotePaper : $securiaceQuoteSurface;
        $corners = $itemIndex === count($preparedQuoteItems) - 1 && $remainingDetail === '' ? '0110' : '0000';
        $securiaceQuoteDrawCard($securiaceQuoteMargin, $rowY, $securiaceQuoteUsableWidth, $rowHeight, $rowFill, $securiaceQuoteLine, 2.65, $corners);
        $pdf->SetFont($securiaceQuoteFont, 'B', 7.1);
        $pdf->SetTextColor($securiaceQuoteInk[0], $securiaceQuoteInk[1], $securiaceQuoteInk[2]);
        $pdf->SetXY($securiaceQuoteMargin + 3, $rowY + 2);
        $pdf->MultiCell($itemWidths[0] - 6, 3.5, $preparedItem['title'], 0, 'L');
        if ($detailChunk !== '') {
            $detailY = $rowY + $priceRowHeight;
            $pdf->SetDrawColor($securiaceQuoteLine[0], $securiaceQuoteLine[1], $securiaceQuoteLine[2]);
            $pdf->SetLineWidth(0.2);
            $pdf->Line(
                $securiaceQuoteMargin + 3,
                $detailY,
                $securiaceQuoteMargin + $securiaceQuoteUsableWidth - 3,
                $detailY
            );
            $pdf->SetFont($securiaceQuoteFont, '', 6.8);
            $pdf->SetTextColor($securiaceQuoteMuted[0], $securiaceQuoteMuted[1], $securiaceQuoteMuted[2]);
            $pdf->SetXY($securiaceQuoteMargin + 4, $detailY + 1.5);
            $pdf->MultiCell($detailWidth, 3.5, $detailChunk, 0, 'L');
        }

        $values = array($preparedItem['qty'], $preparedItem['unitprice']);
        if ($securiaceQuoteShowDiscount) {
            $values[] = $preparedItem['discount'];
        }
        $values[] = $preparedItem['total'];
        $pdf->SetTextColor($securiaceQuoteInk[0], $securiaceQuoteInk[1], $securiaceQuoteInk[2]);
        $pdf->SetXY($securiaceQuoteMargin + $itemWidths[0], $rowY + 2.3);
        $lastColumnIndex = count($itemWidths) - 1;
        foreach ($values as $valueIndex => $value) {
            $columnIndex = $valueIndex + 1;
            $width = $itemWidths[$columnIndex] - ($columnIndex === $lastColumnIndex ? 3 : 0);
            $valueFontSize = 6.5;
            do {
                $pdf->SetFont($securiaceQuoteFont, $columnIndex === $lastColumnIndex ? 'B' : '', $valueFontSize);
                $valueFontSize -= 0.2;
            } while ($pdf->GetStringWidth((string) $value) > $width - 1 && $valueFontSize >= 5.3);
            $pdf->Cell(
                $width,
                4,
                (string) $value,
                0,
                $columnIndex === $lastColumnIndex ? 1 : 0,
                'R'
            );
        }
        $pdf->SetY($rowY + $rowHeight);

        while ($remainingDetail !== '') {
            ++$securiaceQuoteDetailContinuationCount;
            $drawItemsContinuation();
            $continuationY = $pdf->GetY();
            $pdf->SetFont($securiaceQuoteFont, 'B', 6.8);
            $continuationTitleHeight = $pdf->getStringHeight(
                $detailWidth,
                $preparedItem['title']
            );
            $continuationHeaderHeight = max(10, 7 + $continuationTitleHeight);
            $securiaceQuoteMaxDetailContinuationHeaderHeight = max(
                $securiaceQuoteMaxDetailContinuationHeaderHeight,
                $continuationHeaderHeight
            );
            $maxDetailHeight = max(3.5, $pageBottom - $continuationY - $continuationHeaderHeight - 4);
            list($detailChunk, $remainingDetail) = $securiaceQuoteSplitTextForHeight(
                $remainingDetail,
                $detailWidth,
                $maxDetailHeight
            );
            if ($detailChunk === '') {
                break;
            }
            $detailHeight = $pdf->getStringHeight($detailWidth, $detailChunk);
            $continuationHeight = $continuationHeaderHeight + $detailHeight + 4;
            $continuationCorners = $itemIndex === count($preparedQuoteItems) - 1 && $remainingDetail === ''
                ? '0110'
                : '0000';
            $securiaceQuoteDrawCard(
                $securiaceQuoteMargin,
                $continuationY,
                $securiaceQuoteUsableWidth,
                $continuationHeight,
                $rowFill,
                $securiaceQuoteLine,
                2.65,
                $continuationCorners
            );
            $securiaceQuoteDrawLabel(
                'Item details · continued',
                $securiaceQuoteMargin + 4,
                $continuationY + 2,
                $detailWidth
            );
            $pdf->SetFont($securiaceQuoteFont, 'B', 6.8);
            $pdf->SetTextColor($securiaceQuoteInk[0], $securiaceQuoteInk[1], $securiaceQuoteInk[2]);
            $pdf->SetXY($securiaceQuoteMargin + 4, $continuationY + 5.5);
            $pdf->MultiCell($detailWidth, 3.2, $preparedItem['title'], 0, 'L');
            $pdf->SetFont($securiaceQuoteFont, '', 6.8);
            $pdf->SetTextColor($securiaceQuoteMuted[0], $securiaceQuoteMuted[1], $securiaceQuoteMuted[2]);
            $pdf->SetXY($securiaceQuoteMargin + 4, $continuationY + $continuationHeaderHeight);
            $pdf->MultiCell($detailWidth, 3.5, $detailChunk, 0, 'L');
            $pdf->SetY($continuationY + $continuationHeight);
        }
    }
}
$pdf->Ln(3);

// Totals and acceptance context; quotes never show payment or transaction UI.
$totalRows = array(array('Subtotal', isset($subtotal) ? $subtotal : $securiaceQuoteFormatMoney(0), false));
if (isset($taxlevel1['rate']) && (float) $taxlevel1['rate'] > 0) {
    $totalRows[] = array(
        (!empty($taxlevel1['name']) ? $taxlevel1['name'] : 'Tax') . ' · ' . $taxlevel1['rate'] . '%',
        isset($tax1) ? $tax1 : $securiaceQuoteFormatMoney(0),
        false
    );
}
if (isset($taxlevel2['rate']) && (float) $taxlevel2['rate'] > 0) {
    $totalRows[] = array(
        (!empty($taxlevel2['name']) ? $taxlevel2['name'] : 'Additional tax') . ' · ' . $taxlevel2['rate'] . '%',
        isset($tax2) ? $tax2 : $securiaceQuoteFormatMoney(0),
        false
    );
}
$totalRows[] = array('Grand total', isset($total) ? $total : $securiaceQuoteFormatMoney(0), true);
$totalsWidth = min(82, $securiaceQuoteUsableWidth * 0.42);
$acceptanceWidth = $securiaceQuoteUsableWidth - $totalsWidth - 4;
$acceptanceText = $securiaceQuoteConfig['acceptance_note'];
if ($securiaceQuoteConfig['jurisdiction'] !== '') {
    $acceptanceText .= ' Jurisdiction: ' . $securiaceQuoteConfig['jurisdiction'] . '.';
}
$acceptanceText = trim($acceptanceText);
$acceptanceValidityTitle = $securiaceQuoteHasValidUntil
    ? 'Valid until ' . $securiaceQuoteValidUntilDisplay
    : $securiaceQuoteValidUntilDisplay;
$pdf->SetFont($securiaceQuoteFont, 'B', 10);
$acceptanceTitleHeight = $pdf->getStringHeight($acceptanceWidth - 8, $acceptanceValidityTitle);
$pdf->SetFont($securiaceQuoteFont, '', 7);
$acceptanceBodyHeight = $acceptanceText !== ''
    ? $pdf->getStringHeight($acceptanceWidth - 8, $acceptanceText)
    : 0;
$acceptanceHeight = max(23, 12 + $acceptanceTitleHeight + $acceptanceBodyHeight);
$totalsContentHeight = 8 + (count($totalRows) * 5.5) + 1.5;
$totalsHeight = max($acceptanceHeight, $totalsContentHeight);
$securiaceQuoteEnsureSpace($totalsHeight + 4);
$totalsY = $pdf->GetY();
$acceptanceFill = $securiaceQuoteNeedsDateReview ? $securiaceQuoteWarningSoft : $securiaceQuoteBrandSoft;
$acceptanceLine = $securiaceQuoteNeedsDateReview ? $securiaceQuoteWarningLine : $securiaceQuoteLine;
$acceptanceTitleColor = $securiaceQuoteNeedsDateReview ? $securiaceQuoteWarning : $securiaceQuoteBrandDark;
$securiaceQuoteDrawCard($securiaceQuoteMargin, $totalsY, $acceptanceWidth, $totalsHeight, $acceptanceFill, $acceptanceLine);
$securiaceQuoteDrawLabel('Validity and acceptance', $securiaceQuoteMargin + 4, $totalsY + 3, $acceptanceWidth - 8);
$pdf->SetFont($securiaceQuoteFont, 'B', 10);
$pdf->SetTextColor($acceptanceTitleColor[0], $acceptanceTitleColor[1], $acceptanceTitleColor[2]);
$pdf->SetXY($securiaceQuoteMargin + 4, $totalsY + 8);
$pdf->MultiCell(
    $acceptanceWidth - 8,
    5,
    $acceptanceValidityTitle,
    0,
    'L'
);
$pdf->SetFont($securiaceQuoteFont, '', 7);
$pdf->SetTextColor($securiaceQuoteMuted[0], $securiaceQuoteMuted[1], $securiaceQuoteMuted[2]);
$pdf->SetX($securiaceQuoteMargin + 4);
$pdf->MultiCell($acceptanceWidth - 8, 3.7, $acceptanceText, 0, 'L');

$totalsX = $securiaceQuoteMargin + $acceptanceWidth + 4;
$securiaceQuoteDrawCard($totalsX, $totalsY, $totalsWidth, $totalsHeight, $securiaceQuoteSurface, $securiaceQuoteLine);
$totalRowY = $totalsY + 4;
foreach ($totalRows as $totalRow) {
    if ($totalRow[2]) {
        $pdf->SetDrawColor($securiaceQuoteLine[0], $securiaceQuoteLine[1], $securiaceQuoteLine[2]);
        $pdf->Line($totalsX + 3, $totalRowY, $totalsX + $totalsWidth - 3, $totalRowY);
        $totalRowY += 1.5;
    }
    $pdf->SetFont($securiaceQuoteFont, $totalRow[2] ? 'B' : '', $totalRow[2] ? 8 : 7);
    $pdf->SetTextColor($totalRow[2] ? $securiaceQuoteInk[0] : $securiaceQuoteMuted[0], $totalRow[2] ? $securiaceQuoteInk[1] : $securiaceQuoteMuted[1], $totalRow[2] ? $securiaceQuoteInk[2] : $securiaceQuoteMuted[2]);
    $pdf->SetXY($totalsX + 3, $totalRowY);
    $pdf->Cell($totalsWidth * 0.48, 4, $totalRow[0], 0, 0, 'L');
    $pdf->SetFont($securiaceQuoteFont, 'B', $totalRow[2] ? 8 : 7);
    $pdf->SetTextColor($securiaceQuoteInk[0], $securiaceQuoteInk[1], $securiaceQuoteInk[2]);
    $pdf->Cell($totalsWidth * 0.46, 4, $totalRow[1], 0, 1, 'R');
    $totalRowY += 5.5;
}
$pdf->SetY($totalsY + $totalsHeight + 4);

$securiaceQuoteRenderedNotes = false;

// Batch-safe repeated context and footer.
$securiaceQuoteGeneratedAt = function_exists('getTodaysDate') ? getTodaysDate(1) : date('j M Y');
$securiaceQuoteFinalPage = $pdf->getPage();
$securiaceQuotePageCount = $securiaceQuoteFinalPage - $securiaceQuoteStartPage + 1;
$securiaceQuotePreviousAutoPageBreak = $pdf->getAutoPageBreak();
$securiaceQuotePreviousBreakMargin = $pdf->getBreakMargin();
$pdf->SetAutoPageBreak(false, 0);
$securiaceQuoteStampedPages = array();
for ($page = $securiaceQuoteStartPage; $page <= $securiaceQuoteFinalPage; ++$page) {
    $securiaceQuoteStampedPages[] = $page;
    $pdf->setPage($page);
    $pdf->SetAutoPageBreak(false, 0);
    if ($page > $securiaceQuoteStartPage) {
        $pdf->SetFont($securiaceQuoteFont, 'B', 7);
        $pdf->SetTextColor($securiaceQuoteBrand[0], $securiaceQuoteBrand[1], $securiaceQuoteBrand[2]);
        $pdf->SetXY($securiaceQuoteMargin, 8);
        $pdf->Cell($securiaceQuoteUsableWidth * 0.6, 4, $securiaceQuoteCompanyName, 0, 0, 'L');
        $pdf->SetTextColor($securiaceQuoteInk[0], $securiaceQuoteInk[1], $securiaceQuoteInk[2]);
        $pdf->Cell($securiaceQuoteUsableWidth * 0.4, 4, 'Quote · ' . $securiaceQuoteNumber, 0, 1, 'R');
        $pdf->SetDrawColor($securiaceQuoteBrand[0], $securiaceQuoteBrand[1], $securiaceQuoteBrand[2]);
        $pdf->Line($securiaceQuoteMargin, 13, $securiaceQuotePageWidth - $securiaceQuoteMargin, 13);
    }
    $pdf->SetFont($securiaceQuoteFont, '', 5.8);
    $pdf->SetTextColor($securiaceQuoteMuted[0], $securiaceQuoteMuted[1], $securiaceQuoteMuted[2]);
    $pdf->SetXY($securiaceQuoteMargin, $securiaceQuotePageHeight - 10);
    $footerReference = 'Generated ' . $securiaceQuoteGeneratedAt . ' · ' . $securiaceQuoteCompanyName;
    if ($securiaceQuoteNumber !== '—') {
        $footerReference .= ' · Quote ' . $securiaceQuoteNumber;
    }
    $pdf->Cell($securiaceQuoteUsableWidth * 0.7, 4, $footerReference, 0, 0, 'L');
    $relativePage = $page - $securiaceQuoteStartPage + 1;
    $pdf->Cell($securiaceQuoteUsableWidth * 0.3, 4, 'Page ' . $relativePage . ' of ' . $securiaceQuotePageCount, 0, 1, 'R');
}
$pdf->SetAutoPageBreak($securiaceQuotePreviousAutoPageBreak, $securiaceQuotePreviousBreakMargin);
$pdf->setPage($securiaceQuoteFinalPage);

restore_error_handler();
$securiaceQuoteLastPhpError = error_get_last();
$securiaceQuoteHttpStatus = function_exists('http_response_code') ? http_response_code() : false;
if (is_int($securiaceQuoteHttpStatus)
    && $securiaceQuoteHttpStatus >= 500
    && $securiaceQuoteIsTcpdfDeprecation($securiaceQuoteLastPhpError)
) {
    http_response_code(200);
}
