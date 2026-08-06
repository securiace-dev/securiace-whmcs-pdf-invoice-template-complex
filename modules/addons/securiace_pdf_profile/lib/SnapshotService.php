<?php

use WHMCS\Config\Setting;
use WHMCS\Database\Capsule;

final class SecuriacePdfProfileSnapshotService
{
    public const TABLE = 'mod_securiace_pdf_issuer_snapshots';
    public const SCHEMA_VERSION = 1;

    public static function ensureSchema(): void
    {
        if (Capsule::schema()->hasTable(self::TABLE)) {
            return;
        }
        Capsule::schema()->create(self::TABLE, static function ($table): void {
            $table->unsignedInteger('invoice_id')->primary();
            $table->unsignedTinyInteger('schema_version')->default(self::SCHEMA_VERSION);
            $table->string('final_invoice_number', 191)->default('');
            $table->string('document_title', 80);
            $table->string('source_event', 40);
            $table->mediumText('payload');
            $table->char('checksum', 64);
            $table->dateTime('captured_at');
            $table->index(array('document_title', 'captured_at'), 'snapshot_document_captured');
        });
    }

    public static function shouldCaptureCreatedInvoice(int $invoiceId): bool
    {
        try {
            $invoice = \WHMCS\Billing\Invoice::find($invoiceId);
            return $invoice
                && method_exists($invoice, 'isProformaInvoice')
                && !$invoice->isProformaInvoice();
        } catch (Throwable $exception) {
            return false;
        }
    }

    /** @return array<string, mixed> */
    public static function capture(int $invoiceId, string $sourceEvent): array
    {
        if ($invoiceId <= 0) {
            return array('status' => 'invalid-invoice-id');
        }
        if (!Capsule::schema()->hasTable(self::TABLE)) {
            return array('status' => 'schema-unavailable');
        }
        if (Capsule::table(self::TABLE)->where('invoice_id', $invoiceId)->exists()) {
            return array('status' => 'already-captured');
        }

        $invoice = Capsule::table('tblinvoices')
            ->where('id', $invoiceId)
            ->first(array('id', 'userid', 'date', 'invoicenum'));
        if (!$invoice) {
            return array('status' => 'invoice-unavailable');
        }

        $profile = self::resolveCurrentProfile();
        if (empty($profile['identity']['business_name'])) {
            return array('status' => 'profile-unavailable');
        }
        $runtimeConfig = self::runtimeConfig();
        $currencyCode = self::invoiceCurrencyCode((int) $invoice->userid);
        $gstin = isset($profile['registrations']['gstin'])
            && !empty($profile['registrations']['gstin']['valid'])
            ? strtoupper((string) $profile['registrations']['gstin']['value'])
            : '';
        $issueDate = self::dateValue((string) $invoice->date);
        $gstEffectiveDate = self::dateValue(
            isset($runtimeConfig['gst_effective_date']) ? (string) $runtimeConfig['gst_effective_date'] : ''
        );
        $gstRegistered = self::booleanValue(
            isset($runtimeConfig['gst_registered']) ? $runtimeConfig['gst_registered'] : false
        );
        $gstActive = $gstRegistered
            && $gstin !== ''
            && $issueDate instanceof DateTimeImmutable
            && $gstEffectiveDate instanceof DateTimeImmutable
            && $issueDate >= $gstEffectiveDate;

        $commercialCurrencies = self::currencies(
            isset($runtimeConfig['commercial_invoice_currencies'])
                ? $runtimeConfig['commercial_invoice_currencies']
                : array()
        );
        if ($gstActive) {
            $title = isset($runtimeConfig['gst_final_title'])
                ? (string) $runtimeConfig['gst_final_title']
                : 'Tax Invoice';
            if (!in_array($title, array('Tax Invoice', 'Tax Invoice — Export of Services'), true)) {
                $title = 'Tax Invoice';
            }
        } elseif (in_array($currencyCode, $commercialCurrencies, true)) {
            $title = 'Commercial Invoice';
        } else {
            $title = 'Invoice';
        }

        $registrations = isset($profile['registrations']) && is_array($profile['registrations'])
            ? $profile['registrations']
            : array();
        if (!$gstActive) {
            unset($registrations['gstin']);
        }
        $finalNumber = trim((string) $invoice->invoicenum);
        if ($finalNumber === '') {
            $finalNumber = (string) $invoiceId;
        }
        $payload = array(
            'schema_version' => self::SCHEMA_VERSION,
            'issuer' => array(
                'identity' => $profile['identity'],
                'registrations' => $registrations,
            ),
            'document' => array(
                'title' => $title,
                'gst_active' => $gstActive,
                'final_invoice_number' => $finalNumber,
                'issue_date' => $issueDate instanceof DateTimeImmutable ? $issueDate->format('Y-m-d') : '',
            ),
        );
        $payloadJson = json_encode($payload, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
        if (!is_string($payloadJson)) {
            return array('status' => 'snapshot-encoding-failed');
        }

        try {
            Capsule::table(self::TABLE)->insert(array(
                'invoice_id' => $invoiceId,
                'schema_version' => self::SCHEMA_VERSION,
                'final_invoice_number' => $finalNumber,
                'document_title' => $title,
                'source_event' => substr($sourceEvent, 0, 40),
                'payload' => $payloadJson,
                'checksum' => hash('sha256', $payloadJson),
                'captured_at' => date('Y-m-d H:i:s'),
            ));
        } catch (Throwable $exception) {
            if (Capsule::table(self::TABLE)->where('invoice_id', $invoiceId)->exists()) {
                return array('status' => 'already-captured');
            }
            throw $exception;
        }

        return array('status' => 'captured', 'document_title' => $title);
    }

    /** @return array<string, mixed> */
    public static function diagnostics(): array
    {
        $profile = self::resolveCurrentProfile();
        $tableAvailable = Capsule::schema()->hasTable(self::TABLE);
        $registrations = isset($profile['registrations']) && is_array($profile['registrations'])
            ? $profile['registrations']
            : array();
        $bankAccounts = isset($profile['payment']['bank_accounts']) && is_array($profile['payment']['bank_accounts'])
            ? $profile['payment']['bank_accounts']
            : array();

        return array(
            'schema_version' => self::SCHEMA_VERSION,
            'snapshot_table' => $tableAvailable ? 'available' : 'missing',
            'snapshot_count' => $tableAvailable ? (int) Capsule::table(self::TABLE)->count() : 0,
            'profile_helper' => self::profileHelperPath() !== '' ? 'available' : 'missing',
            'protected_config' => is_readable(ROOTDIR . '/includes/securiace-invoice-config.php')
                ? 'available'
                : 'missing',
            'identity' => array(
                'business_name_present' => !empty($profile['identity']['business_name']),
                'address_line_count' => isset($profile['identity']['address_lines'])
                    && is_array($profile['identity']['address_lines'])
                    ? count($profile['identity']['address_lines'])
                    : 0,
                'support_email_present' => !empty($profile['identity']['support_email']),
                'support_email_valid' => !empty($profile['identity']['support_email_valid']),
                'mobile_present' => !empty($profile['identity']['mobile']),
            ),
            'registrations' => array(
                'pan' => self::registrationStatus($registrations, 'pan'),
                'udyam' => self::registrationStatus($registrations, 'udyam'),
                'gstin' => self::registrationStatus($registrations, 'gstin'),
            ),
            'payment' => array(
                'valid_bank_account_count' => count($bankAccounts),
                'upi_present' => !empty($profile['payment']['upi']['id']),
                'upi_valid' => !empty($profile['payment']['upi']['valid']),
            ),
            'sources' => isset($profile['diagnostics']['sources']) ? $profile['diagnostics']['sources'] : array(),
            'warnings' => isset($profile['diagnostics']['warnings']) ? $profile['diagnostics']['warnings'] : array(),
            'conflicts' => isset($profile['diagnostics']['conflicts']) ? $profile['diagnostics']['conflicts'] : array(),
        );
    }

    /** @return array<string, mixed> */
    private static function resolveCurrentProfile(): array
    {
        $path = self::profileHelperPath();
        if ($path === '') {
            return array(
                'identity' => array(),
                'registrations' => array(),
                'payment' => array('upi' => array(), 'bank_accounts' => array()),
                'diagnostics' => array(
                    'sources' => array(),
                    'warnings' => array('profile-helper-unavailable'),
                    'conflicts' => array(),
                ),
            );
        }
        $resolver = include $path;
        if (!($resolver instanceof Closure)) {
            return array();
        }
        $runtimeConfig = self::runtimeConfig();
        return $resolver(array(
            'company_name' => Setting::getValue('CompanyName'),
            'company_email' => Setting::getValue('Email'),
            'company_url' => Setting::getValue('Domain'),
            'tax_code' => Setting::getValue('TaxCode'),
            'tax_label' => 'GSTIN',
            'pay_to' => Setting::getValue('InvoicePayTo'),
            'default_bank_currencies' => isset($runtimeConfig['bank_currencies'])
                ? $runtimeConfig['bank_currencies']
                : array('INR'),
            'fallback' => $runtimeConfig,
        ));
    }

    /** @return array<string, mixed> */
    private static function runtimeConfig(): array
    {
        $path = ROOTDIR . '/includes/securiace-invoice-config.php';
        if (!is_readable($path)) {
            return array();
        }
        $config = include $path;
        return is_array($config) ? $config : array();
    }

    private static function profileHelperPath(): string
    {
        $path = ROOTDIR . '/includes/securiace-pdf-profile.php';
        return is_readable($path) ? $path : '';
    }

    private static function invoiceCurrencyCode(int $clientId): string
    {
        if ($clientId <= 0) {
            return '';
        }
        $currency = Capsule::table('tblclients')
            ->join('tblcurrencies', 'tblcurrencies.id', '=', 'tblclients.currency')
            ->where('tblclients.id', $clientId)
            ->value('tblcurrencies.code');
        return is_scalar($currency) ? strtoupper(trim((string) $currency)) : '';
    }

    private static function dateValue(string $value): ?DateTimeImmutable
    {
        $value = trim($value);
        if ($value === '' || $value === '0000-00-00') {
            return null;
        }
        try {
            return new DateTimeImmutable($value);
        } catch (Throwable $exception) {
            return null;
        }
    }

    private static function booleanValue($value): bool
    {
        if (is_bool($value)) {
            return $value;
        }
        if (!is_scalar($value)) {
            return false;
        }
        return filter_var($value, FILTER_VALIDATE_BOOLEAN) === true;
    }

    /** @return array<int, string> */
    private static function currencies($value): array
    {
        if (!is_array($value)) {
            return array();
        }
        $currencies = array();
        foreach ($value as $currency) {
            if (!is_scalar($currency)) {
                continue;
            }
            $currency = strtoupper(trim((string) $currency));
            if (preg_match('/^[A-Z]{3}$/', $currency) && !in_array($currency, $currencies, true)) {
                $currencies[] = $currency;
            }
        }
        return $currencies;
    }

    /** @param array<string, mixed> $registrations @return array<string, mixed> */
    private static function registrationStatus(array $registrations, string $key): array
    {
        return array(
            'present' => isset($registrations[$key]) && !empty($registrations[$key]['value']),
            'valid' => isset($registrations[$key]) && !empty($registrations[$key]['valid']),
            'source' => isset($registrations[$key]['source']) ? $registrations[$key]['source'] : 'none',
        );
    }
}
