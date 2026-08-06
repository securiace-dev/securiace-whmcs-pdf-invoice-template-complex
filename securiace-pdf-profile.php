<?php

/**
 * Shared issuer/payment profile resolver for the modern WHMCS PDF templates.
 *
 * The file deliberately returns a closure instead of declaring functions or
 * classes. WHMCS batch generation can include a template more than once in the
 * same process, so global declarations would create redeclaration failures.
 *
 * @return Closure(array<string, mixed>): array<string, mixed>
 */
return (static function () {
    $scalarString = static function ($value): string {
        if (is_scalar($value)) {
            return (string) $value;
        }
        if (is_object($value) && method_exists($value, '__toString')) {
            return (string) $value;
        }
        return '';
    };

    $plainText = static function ($value, int $maximum = 512) use ($scalarString): string {
        $text = $scalarString($value);
        $text = preg_replace('/<\s*br\s*\/?>/iu', "\n", $text);
        $text = strip_tags($text === null ? '' : $text);
        $text = html_entity_decode($text, ENT_QUOTES | ENT_HTML5, 'UTF-8');
        $text = str_replace(array("\r\n", "\r", '：'), array("\n", "\n", ':'), $text);
        $text = preg_replace('/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/u', '', $text);
        $text = trim($text === null ? '' : $text);
        if ($maximum > 0) {
            if (function_exists('mb_strlen') && function_exists('mb_substr')) {
                if (mb_strlen($text, 'UTF-8') > $maximum) {
                    $text = mb_substr($text, 0, $maximum, 'UTF-8');
                }
            } elseif (strlen($text) > $maximum) {
                $text = substr($text, 0, $maximum);
            }
        }
        return $text;
    };

    $normalizeLabel = static function ($value) use ($plainText): string {
        $label = $plainText($value, 80);
        $label = function_exists('mb_strtolower')
            ? mb_strtolower($label, 'UTF-8')
            : strtolower($label);
        $label = preg_replace('/[^a-z0-9]+/u', ' ', $label);
        return trim($label === null ? '' : $label);
    };

    $normalizeCurrencies = static function ($value) use ($scalarString): array {
        $values = is_array($value) ? $value : preg_split('/[\s,;|]+/', $scalarString($value));
        if (!is_array($values)) {
            return array();
        }
        $currencies = array();
        foreach ($values as $candidate) {
            if (!is_scalar($candidate)
                && !(is_object($candidate) && method_exists($candidate, '__toString'))
            ) {
                continue;
            }
            $candidate = strtoupper(trim((string) $candidate));
            if (preg_match('/^[A-Z]{3}$/', $candidate) && !in_array($candidate, $currencies, true)) {
                $currencies[] = $candidate;
            }
        }
        return $currencies;
    };

    $aliases = array(
        'legal name' => 'legal_name',
        'business name' => 'legal_name',
        'company name' => 'legal_name',
        'company address' => 'address',
        'registered address' => 'address',
        'business address' => 'address',
        'address' => 'address',
        'helpdesk' => 'support_email',
        'helpdesk email' => 'support_email',
        'support email' => 'support_email',
        'billing email' => 'support_email',
        'email' => 'support_email',
        'email address' => 'support_email',
        'mobile' => 'mobile',
        'mobile number' => 'mobile',
        'phone' => 'mobile',
        'phone number' => 'mobile',
        'telephone' => 'mobile',
        'tel' => 'mobile',
        'pan' => 'pan',
        'pan number' => 'pan',
        'msme' => 'udyam',
        'msme number' => 'udyam',
        'udyam' => 'udyam',
        'udyam number' => 'udyam',
        'udyam registration' => 'udyam',
        'gst' => 'gstin',
        'gstin' => 'gstin',
        'gst number' => 'gstin',
        'tax id' => 'gstin',
        'upi' => 'upi_id',
        'upi id' => 'upi_id',
        'vpa' => 'upi_id',
        'upi payee name' => 'upi_payee_name',
        'payee name' => 'upi_payee_name',
        'account name' => 'account_name',
        'beneficiary' => 'account_name',
        'beneficiary name' => 'account_name',
        'account number' => 'account_number',
        'account no' => 'account_number',
        'a c no' => 'account_number',
        'ifsc' => 'routing_code',
        'ifsc code' => 'routing_code',
        'routing code' => 'routing_code',
        'swift' => 'routing_code',
        'swift code' => 'routing_code',
        'bank branch' => 'branch',
        'branch' => 'branch',
        'account type' => 'account_type',
        'type' => 'account_type',
        'bank name' => 'bank_name',
        'bank' => 'bank_name',
        'currency' => 'currencies',
        'currencies' => 'currencies',
        'account currency' => 'currencies',
        'account currencies' => 'currencies',
        'website' => 'website',
        'url' => 'website',
    );

    $parsePayTo = static function ($payTo) use (
        $scalarString,
        $plainText,
        $normalizeLabel,
        $normalizeCurrencies,
        $aliases
    ): array {
        $rawLines = is_array($payTo) ? $payTo : explode("\n", $scalarString($payTo));
        $lines = array();
        foreach ($rawLines as $rawLine) {
            if (!is_scalar($rawLine)
                && !(is_object($rawLine) && method_exists($rawLine, '__toString'))
            ) {
                continue;
            }
            $normalized = $plainText($rawLine, 512);
            foreach (explode("\n", $normalized) as $line) {
                $lines[] = trim($line);
            }
        }

        $parsed = array(
            'fields' => array(),
            'address_lines' => array(),
            'banks' => array(),
            'conflicts' => array(),
            'warnings' => array(),
            'unknown_labels' => array(),
        );
        $currentSection = '';
        $currentBank = null;
        $addressContinuation = false;

        $assign = static function (
            array &$container,
            string $key,
            $value,
            string $conflictCode,
            array &$conflicts
        ): void {
            if ($value === '' || $value === array()) {
                return;
            }
            if (!array_key_exists($key, $container)) {
                $container[$key] = $value;
                return;
            }
            if ($container[$key] === $value) {
                return;
            }
            if (!in_array($conflictCode, $conflicts, true)) {
                $conflicts[] = $conflictCode;
            }
        };

        foreach ($lines as $lineNumber => $line) {
            if ($line === '') {
                $addressContinuation = false;
                continue;
            }

            if (preg_match('/^\[\s*([^\]]{1,80})\s*\]$/u', $line, $sectionMatch)) {
                $currentSection = $normalizeLabel($sectionMatch[1]);
                $addressContinuation = false;
                if (strpos($currentSection, 'bank') !== false
                    || strpos($currentSection, 'account') !== false
                    || strpos($currentSection, 'remittance') !== false
                ) {
                    $currentBank = count($parsed['banks']);
                    $parsed['banks'][$currentBank] = array('_conflicted' => false);
                    if (preg_match_all('/\b[A-Z]{3}\b/i', $sectionMatch[1], $currencyMatches)) {
                        $sectionCurrencies = $normalizeCurrencies($currencyMatches[0]);
                        if (!empty($sectionCurrencies)) {
                            $parsed['banks'][$currentBank]['currencies'] = $sectionCurrencies;
                        }
                    }
                } else {
                    $currentBank = null;
                }
                continue;
            }

            $separator = strpos($line, ':');
            if ($separator !== false) {
                $rawLabel = substr($line, 0, $separator);
                $value = $plainText(substr($line, $separator + 1), 384);
                $normalizedLabel = $normalizeLabel($rawLabel);
                $canonical = isset($aliases[$normalizedLabel]) ? $aliases[$normalizedLabel] : '';
                $addressContinuation = false;

                if ($canonical === '') {
                    if ($normalizedLabel !== '' && !in_array($normalizedLabel, $parsed['unknown_labels'], true)) {
                        $parsed['unknown_labels'][] = $normalizedLabel;
                    }
                    continue;
                }

                if ($canonical === 'address') {
                    if ($value !== '') {
                        $parsed['address_lines'][] = $value;
                        $addressContinuation = true;
                    }
                    continue;
                }

                $bankFields = array(
                    'account_name', 'account_number', 'routing_code', 'branch',
                    'account_type', 'bank_name', 'currencies'
                );
                if (in_array($canonical, $bankFields, true)) {
                    if ($currentBank === null) {
                        $currentBank = count($parsed['banks']);
                        $parsed['banks'][$currentBank] = array('_conflicted' => false);
                    }
                    $bankValue = $canonical === 'currencies' ? $normalizeCurrencies($value) : $value;
                    $beforeConflictCount = count($parsed['conflicts']);
                    $assign(
                        $parsed['banks'][$currentBank],
                        $canonical,
                        $bankValue,
                        'pay-to-bank-' . $currentBank . '-' . $canonical . '-conflict',
                        $parsed['conflicts']
                    );
                    if (count($parsed['conflicts']) > $beforeConflictCount) {
                        $parsed['banks'][$currentBank]['_conflicted'] = true;
                    }
                    continue;
                }

                $assign(
                    $parsed['fields'],
                    $canonical,
                    $value,
                    'pay-to-' . $canonical . '-conflict',
                    $parsed['conflicts']
                );
                continue;
            }

            if ($addressContinuation || strpos($currentSection, 'address') !== false) {
                $parsed['address_lines'][] = $plainText($line, 384);
                $addressContinuation = true;
                continue;
            }

            if ($currentBank === null) {
                $parsed['address_lines'][] = $plainText($line, 384);
            } else {
                $warning = 'pay-to-unlabelled-bank-line-' . ($lineNumber + 1);
                if (!in_array($warning, $parsed['warnings'], true)) {
                    $parsed['warnings'][] = $warning;
                }
            }
        }

        return $parsed;
    };

    $normalizeBank = static function (
        array $bank,
        string $source,
        array $defaultCurrencies
    ) use ($plainText, $normalizeCurrencies): array {
        $routingCode = $plainText(
            isset($bank['routing_code']) ? $bank['routing_code'] : (isset($bank['ifsc']) ? $bank['ifsc'] : ''),
            64
        );
        $currencies = $normalizeCurrencies(isset($bank['currencies']) ? $bank['currencies'] : array());
        $usedDefaultCurrencies = false;
        if (empty($currencies) && !empty($defaultCurrencies)) {
            $currencies = $defaultCurrencies;
            $usedDefaultCurrencies = true;
        }
        $accountNumber = $plainText(isset($bank['account_number']) ? $bank['account_number'] : '', 64);
        $compactNumber = preg_replace('/[\s-]+/', '', $accountNumber);
        $accountNumberValid = $compactNumber !== null
            && preg_match('/^[A-Z0-9]{6,34}$/i', $compactNumber) === 1;
        $routingCodeCompact = strtoupper((string) preg_replace('/\s+/', '', $routingCode));
        $routingCodeValid = preg_match('/^[A-Z]{4}0[A-Z0-9]{6}$/', $routingCodeCompact) === 1
            || preg_match('/^[A-Z0-9]{6,15}$/', $routingCodeCompact) === 1;

        $normalized = array(
            'account_name' => $plainText(isset($bank['account_name']) ? $bank['account_name'] : '', 160),
            'account_number' => $accountNumber,
            'routing_code' => $routingCode,
            'branch' => $plainText(isset($bank['branch']) ? $bank['branch'] : '', 120),
            'account_type' => $plainText(isset($bank['account_type']) ? $bank['account_type'] : '', 80),
            'bank_name' => $plainText(isset($bank['bank_name']) ? $bank['bank_name'] : '', 160),
            'currencies' => $currencies,
            'source' => $source,
            'conflicted' => !empty($bank['_conflicted']),
            'used_default_currencies' => $usedDefaultCurrencies,
        );
        $normalized['complete'] = $normalized['account_name'] !== ''
            && $normalized['account_number'] !== ''
            && $normalized['routing_code'] !== ''
            && $normalized['bank_name'] !== '';
        $normalized['valid'] = $normalized['complete']
            && !$normalized['conflicted']
            && $accountNumberValid
            && $routingCodeValid
            && !empty($normalized['currencies']);

        return $normalized;
    };

    return static function (array $input) use (
        $plainText,
        $normalizeCurrencies,
        $parsePayTo,
        $normalizeBank
    ): array {
        $fallback = isset($input['fallback']) && is_array($input['fallback'])
            ? $input['fallback']
            : array();
        $defaultBankCurrencies = $normalizeCurrencies(
            isset($input['default_bank_currencies'])
                ? $input['default_bank_currencies']
                : (isset($fallback['bank_currencies']) ? $fallback['bank_currencies'] : array())
        );
        $parsed = $parsePayTo(isset($input['pay_to']) ? $input['pay_to'] : array());
        $sources = array();
        $warnings = $parsed['warnings'];
        $conflicts = $parsed['conflicts'];

        $select = static function (
            string $field,
            array $candidates,
            array &$sources
        ) use ($plainText): string {
            foreach ($candidates as $candidate) {
                $value = $plainText(isset($candidate[0]) ? $candidate[0] : '', isset($candidate[2]) ? (int) $candidate[2] : 384);
                if ($value !== '') {
                    $sources[$field] = isset($candidate[1]) ? (string) $candidate[1] : 'unknown';
                    return $value;
                }
            }
            $sources[$field] = 'none';
            return '';
        };

        $businessName = $select('identity.business_name', array(
            array(isset($input['company_name']) ? $input['company_name'] : '', 'whmcs.company_name', 160),
            array(isset($parsed['fields']['legal_name']) ? $parsed['fields']['legal_name'] : '', 'pay_to.legal_name', 160),
            array(isset($fallback['company_name']) ? $fallback['company_name'] : '', 'protected.company_name', 160),
            array('Issuer', 'neutral', 160),
        ), $sources);

        $addressLines = array();
        $addressSource = 'none';
        if (!empty($parsed['address_lines'])) {
            foreach ($parsed['address_lines'] as $addressLine) {
                $addressLine = $plainText($addressLine, 384);
                if ($addressLine === '' || strcasecmp($addressLine, $businessName) === 0) {
                    continue;
                }
                $addressLines[] = $addressLine;
            }
            if (!empty($addressLines)) {
                $addressSource = 'pay_to.address';
            }
        }
        if (empty($addressLines) && !empty($fallback['company_address'])) {
            $fallbackAddress = is_array($fallback['company_address'])
                ? $fallback['company_address']
                : explode("\n", $plainText($fallback['company_address'], 1600));
            foreach ($fallbackAddress as $addressLine) {
                $addressLine = $plainText($addressLine, 384);
                if ($addressLine !== '') {
                    $addressLines[] = $addressLine;
                }
            }
            if (!empty($addressLines)) {
                $addressSource = 'protected.company_address';
            }
        }
        $sources['identity.address_lines'] = $addressSource;

        $supportEmail = $select('identity.support_email', array(
            array(isset($parsed['fields']['support_email']) ? $parsed['fields']['support_email'] : '', 'pay_to.support_email', 254),
            array(isset($input['company_email']) ? $input['company_email'] : '', 'whmcs.company_email', 254),
            array(isset($fallback['company_email']) ? $fallback['company_email'] : '', 'protected.company_email', 254),
        ), $sources);
        $mobile = $select('identity.mobile', array(
            array(isset($parsed['fields']['mobile']) ? $parsed['fields']['mobile'] : '', 'pay_to.mobile', 80),
            array(isset($fallback['company_phone']) ? $fallback['company_phone'] : '', 'protected.company_phone', 80),
        ), $sources);
        $website = $select('identity.website', array(
            array(isset($input['company_url']) ? $input['company_url'] : '', 'whmcs.company_url', 512),
            array(isset($parsed['fields']['website']) ? $parsed['fields']['website'] : '', 'pay_to.website', 512),
            array(isset($fallback['company_url']) ? $fallback['company_url'] : '', 'protected.company_url', 512),
        ), $sources);

        if ($supportEmail !== '' && filter_var($supportEmail, FILTER_VALIDATE_EMAIL) === false) {
            $warnings[] = 'support-email-invalid';
        }
        if ($website !== '' && filter_var($website, FILTER_VALIDATE_URL) === false) {
            $warnings[] = 'website-invalid';
        }

        $registrationCandidates = array(
            'pan' => array(
                array(isset($parsed['fields']['pan']) ? $parsed['fields']['pan'] : '', 'pay_to.pan'),
                array(isset($fallback['company_pan']) ? $fallback['company_pan'] : '', 'protected.company_pan'),
            ),
            'udyam' => array(
                array(isset($parsed['fields']['udyam']) ? $parsed['fields']['udyam'] : '', 'pay_to.udyam'),
                array(isset($fallback['company_msme']) ? $fallback['company_msme'] : '', 'protected.company_msme'),
            ),
            'gstin' => array(
                array(isset($input['tax_code']) ? $input['tax_code'] : '', 'whmcs.tax_code'),
                array(isset($parsed['fields']['gstin']) ? $parsed['fields']['gstin'] : '', 'pay_to.gstin'),
                array(isset($fallback['company_gstin']) ? $fallback['company_gstin'] : '', 'protected.company_gstin'),
            ),
        );
        $registrationLabels = array('pan' => 'PAN', 'udyam' => 'MSME', 'gstin' => 'GSTIN');
        $registrationPatterns = array(
            'pan' => '/^[A-Z]{5}[0-9]{4}[A-Z]$/',
            'udyam' => '/^UDYAM-[A-Z]{2}-[0-9]{2}-[0-9]{7}$/',
            'gstin' => '/^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][A-Z0-9]Z[A-Z0-9]$/',
        );
        $registrations = array();
        foreach ($registrationCandidates as $key => $candidates) {
            $value = $select('registrations.' . $key, array(
                array($candidates[0][0], $candidates[0][1], 64),
                array(isset($candidates[1]) ? $candidates[1][0] : '', isset($candidates[1]) ? $candidates[1][1] : '', 64),
                array(isset($candidates[2]) ? $candidates[2][0] : '', isset($candidates[2]) ? $candidates[2][1] : '', 64),
            ), $sources);
            $value = strtoupper($value);
            if ($value === '') {
                continue;
            }
            $valid = preg_match($registrationPatterns[$key], $value) === 1;
            if (!$valid) {
                $warnings[] = 'registration-' . $key . '-invalid';
            }
            $registrations[$key] = array(
                'label' => $key === 'gstin' && !empty($input['tax_label'])
                    ? $plainText($input['tax_label'], 40)
                    : $registrationLabels[$key],
                'value' => $value,
                'valid' => $valid,
                'source' => $sources['registrations.' . $key],
            );
        }

        $payToBanks = array();
        $payToBankConflict = false;
        foreach ($parsed['banks'] as $bank) {
            $normalized = $normalizeBank($bank, 'pay_to.bank', $defaultBankCurrencies);
            if ($normalized['conflicted']) {
                $payToBankConflict = true;
            }
            if ($normalized['valid']) {
                $payToBanks[] = $normalized;
            }
        }

        $fallbackBanks = array();
        $rawFallbackBanks = array();
        if (isset($fallback['bank_accounts']) && is_array($fallback['bank_accounts'])) {
            $rawFallbackBanks = $fallback['bank_accounts'];
        } elseif (isset($fallback['bank']) && is_array($fallback['bank'])) {
            $rawFallbackBanks = array($fallback['bank']);
        }
        foreach ($rawFallbackBanks as $bank) {
            if (!is_array($bank)) {
                continue;
            }
            $normalized = $normalizeBank($bank, 'protected.bank', $defaultBankCurrencies);
            if ($normalized['valid']) {
                $fallbackBanks[] = $normalized;
            }
        }
        if ($payToBankConflict) {
            $bankAccounts = array();
            $sources['payment.bank_accounts'] = 'disabled-conflict';
        } elseif (!empty($payToBanks)) {
            $bankAccounts = $payToBanks;
            $sources['payment.bank_accounts'] = 'pay_to.bank';
        } else {
            $bankAccounts = $fallbackBanks;
            $sources['payment.bank_accounts'] = !empty($fallbackBanks) ? 'protected.bank' : 'none';
        }
        if (empty($bankAccounts)) {
            $warnings[] = $payToBankConflict ? 'bank-disabled-conflict' : 'bank-unavailable';
        }

        $upiConflict = in_array('pay-to-upi_id-conflict', $conflicts, true);
        $upiId = '';
        $upiSource = 'none';
        if (!$upiConflict && !empty($parsed['fields']['upi_id'])) {
            $upiId = $plainText($parsed['fields']['upi_id'], 320);
            $upiSource = 'pay_to.upi_id';
        } elseif (!$upiConflict && !empty($fallback['upi_id'])) {
            $upiId = $plainText($fallback['upi_id'], 320);
            $upiSource = 'protected.upi_id';
        }
        $upiValid = $upiId !== ''
            && preg_match('/^[A-Z0-9._-]{2,256}@[A-Z0-9.-]{2,64}$/i', $upiId) === 1;
        if ($upiConflict) {
            $warnings[] = 'upi-disabled-conflict';
        } elseif ($upiId !== '' && !$upiValid) {
            $warnings[] = 'upi-invalid';
        }
        $sources['payment.upi'] = $upiSource;
        $upiPayeeName = $select('payment.upi.payee_name', array(
            array(isset($parsed['fields']['upi_payee_name']) ? $parsed['fields']['upi_payee_name'] : '', 'pay_to.upi_payee_name', 160),
            array(isset($fallback['upi_payee_name']) ? $fallback['upi_payee_name'] : '', 'protected.upi_payee_name', 160),
            array($businessName, $sources['identity.business_name'], 160),
        ), $sources);

        $warnings = array_values(array_unique($warnings));
        $conflicts = array_values(array_unique($conflicts));

        return array(
            'schema_version' => 1,
            'identity' => array(
                'business_name' => $businessName,
                'address_lines' => $addressLines,
                'support_email' => $supportEmail,
                'support_email_valid' => $supportEmail === '' || filter_var($supportEmail, FILTER_VALIDATE_EMAIL) !== false,
                'mobile' => $mobile,
                'website' => $website,
                'website_valid' => $website === '' || filter_var($website, FILTER_VALIDATE_URL) !== false,
            ),
            'registrations' => $registrations,
            'payment' => array(
                'upi' => array(
                    'id' => $upiId,
                    'payee_name' => $upiPayeeName,
                    'currencies' => array('INR'),
                    'valid' => $upiValid && !$upiConflict,
                    'source' => $upiSource,
                ),
                'bank_accounts' => $bankAccounts,
            ),
            'policy' => array(
                'jurisdiction' => $plainText(isset($fallback['jurisdiction']) ? $fallback['jurisdiction'] : '', 160),
                'tds_note' => $plainText(isset($fallback['tds_note']) ? $fallback['tds_note'] : '', 512),
                'late_fee_text' => $plainText(isset($fallback['late_fee_text']) ? $fallback['late_fee_text'] : '', 512),
            ),
            'diagnostics' => array(
                'sources' => $sources,
                'conflicts' => $conflicts,
                'warnings' => $warnings,
                'unknown_labels' => $parsed['unknown_labels'],
            ),
        );
    };
})();
