<?php

/**
 * Validate and normalize an immutable PDF issuer snapshot row.
 *
 * The closure accepts a database-shaped array with payload and checksum keys.
 * It performs no database access, which keeps validation dependency-free and
 * reusable from WHMCS templates and tests.
 *
 * @return Closure(array<string, mixed>): array<string, mixed>
 */
return static function (array $row): array {
    $failure = static function (string $warning): array {
        return array('valid' => false, 'warning' => $warning, 'snapshot' => array());
    };
    $plain = static function ($value, int $maximum = 512): string {
        if (!is_scalar($value)
            && !(is_object($value) && method_exists($value, '__toString'))
        ) {
            return '';
        }
        $value = html_entity_decode(strip_tags((string) $value), ENT_QUOTES | ENT_HTML5, 'UTF-8');
        $value = preg_replace('/[\x00-\x1F\x7F]/u', ' ', $value);
        $value = trim(preg_replace('/\s+/u', ' ', $value === null ? '' : $value));
        if (function_exists('mb_substr')) {
            return mb_substr($value, 0, $maximum, 'UTF-8');
        }
        return substr($value, 0, $maximum);
    };

    $payloadJson = isset($row['payload']) && is_scalar($row['payload'])
        ? (string) $row['payload']
        : '';
    $checksum = isset($row['checksum']) && is_scalar($row['checksum'])
        ? strtolower(trim((string) $row['checksum']))
        : '';
    if ($payloadJson === '' || preg_match('/^[a-f0-9]{64}$/', $checksum) !== 1) {
        return $failure('snapshot-row-incomplete');
    }
    if (!hash_equals($checksum, hash('sha256', $payloadJson))) {
        return $failure('snapshot-checksum-mismatch');
    }

    $payload = json_decode($payloadJson, true);
    if (!is_array($payload) || json_last_error() !== JSON_ERROR_NONE) {
        return $failure('snapshot-json-invalid');
    }
    if (!isset($payload['schema_version']) || (int) $payload['schema_version'] !== 1) {
        return $failure('snapshot-schema-unsupported');
    }
    if (isset($payload['payment'])
        || (isset($payload['issuer']) && is_array($payload['issuer']) && isset($payload['issuer']['payment']))
    ) {
        return $failure('snapshot-payment-data-forbidden');
    }
    if (empty($payload['issuer']['identity']) || !is_array($payload['issuer']['identity'])) {
        return $failure('snapshot-identity-missing');
    }

    $rawIdentity = $payload['issuer']['identity'];
    $identity = array(
        'business_name' => $plain(isset($rawIdentity['business_name']) ? $rawIdentity['business_name'] : '', 160),
        'address_lines' => array(),
        'support_email' => $plain(isset($rawIdentity['support_email']) ? $rawIdentity['support_email'] : '', 254),
        'mobile' => $plain(isset($rawIdentity['mobile']) ? $rawIdentity['mobile'] : '', 80),
        'website' => $plain(isset($rawIdentity['website']) ? $rawIdentity['website'] : '', 512),
    );
    if ($identity['business_name'] === '') {
        return $failure('snapshot-business-name-missing');
    }
    $rawAddressLines = isset($rawIdentity['address_lines']) && is_array($rawIdentity['address_lines'])
        ? $rawIdentity['address_lines']
        : array();
    foreach (array_slice($rawAddressLines, 0, 8) as $rawAddressLine) {
        $addressLine = $plain($rawAddressLine, 384);
        if ($addressLine !== '') {
            $identity['address_lines'][] = $addressLine;
        }
    }
    $identity['support_email_valid'] = $identity['support_email'] === ''
        || filter_var($identity['support_email'], FILTER_VALIDATE_EMAIL) !== false;
    $identity['website_valid'] = $identity['website'] === ''
        || filter_var($identity['website'], FILTER_VALIDATE_URL) !== false;

    $registrationPatterns = array(
        'pan' => '/^[A-Z]{5}[0-9]{4}[A-Z]$/',
        'udyam' => '/^UDYAM-[A-Z]{2}-[0-9]{2}-[0-9]{7}$/',
        'gstin' => '/^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][A-Z0-9]Z[A-Z0-9]$/',
    );
    $registrationLabels = array('pan' => 'PAN', 'udyam' => 'MSME', 'gstin' => 'GSTIN');
    $registrations = array();
    $rawRegistrations = isset($payload['issuer']['registrations'])
        && is_array($payload['issuer']['registrations'])
        ? $payload['issuer']['registrations']
        : array();
    foreach ($registrationPatterns as $registrationKey => $registrationPattern) {
        if (!isset($rawRegistrations[$registrationKey]) || !is_array($rawRegistrations[$registrationKey])) {
            continue;
        }
        $registrationValue = strtoupper($plain(
            isset($rawRegistrations[$registrationKey]['value'])
                ? $rawRegistrations[$registrationKey]['value']
                : '',
            64
        ));
        if ($registrationValue === '') {
            continue;
        }
        $registrations[$registrationKey] = array(
            'label' => $registrationLabels[$registrationKey],
            'value' => $registrationValue,
            'valid' => preg_match($registrationPattern, $registrationValue) === 1,
            'source' => 'snapshot',
        );
    }

    $allowedTitles = array(
        'Invoice',
        'Commercial Invoice',
        'Tax Invoice',
        'Tax Invoice — Export of Services',
    );
    $rawDocument = isset($payload['document']) && is_array($payload['document'])
        ? $payload['document']
        : array();
    $documentTitle = $plain(isset($rawDocument['title']) ? $rawDocument['title'] : '', 80);
    if (!in_array($documentTitle, $allowedTitles, true)) {
        return $failure('snapshot-document-title-invalid');
    }
    $document = array(
        'title' => $documentTitle,
        'gst_active' => !empty($rawDocument['gst_active']),
        'final_invoice_number' => $plain(
            isset($rawDocument['final_invoice_number']) ? $rawDocument['final_invoice_number'] : '',
            191
        ),
        'issue_date' => $plain(isset($rawDocument['issue_date']) ? $rawDocument['issue_date'] : '', 32),
    );

    return array(
        'valid' => true,
        'warning' => '',
        'snapshot' => array(
            'schema_version' => 1,
            'issuer' => array('identity' => $identity, 'registrations' => $registrations),
            'document' => $document,
        ),
    );
};
