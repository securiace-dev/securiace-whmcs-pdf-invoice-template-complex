<?php

declare(strict_types=1);

error_reporting(E_ALL & ~E_DEPRECATED & ~E_USER_DEPRECATED);

if ($argc < 3) {
    fwrite(STDERR, "Usage: php tests/render_modern_invoice_fixtures.php /path/to/tcpdf.php /output/directory [modern|legacy]\n");
    exit(64);
}

$tcpdfPath = $argv[1];
$outputDirectory = $argv[2];
$templateMode = isset($argv[3]) ? strtolower($argv[3]) : 'modern';
if (!in_array($templateMode, array('modern', 'legacy'), true)) {
    throw new InvalidArgumentException('Template mode must be modern or legacy.');
}
$templateFilename = $templateMode === 'legacy' ? 'invoicepdf.tpl' : 'invoicepdf-modern.tpl';
$templatePath = realpath(__DIR__ . '/../' . $templateFilename);

if ($templatePath === false || !is_readable($templatePath)) {
    throw new RuntimeException('Modern invoice template is not readable.');
}
if (!is_readable($tcpdfPath)) {
    throw new RuntimeException('TCPDF is not readable: ' . $tcpdfPath);
}
if (!is_dir($outputDirectory) && !mkdir($outputDirectory, 0775, true) && !is_dir($outputDirectory)) {
    throw new RuntimeException('Unable to create output directory: ' . $outputDirectory);
}
if (!extension_loaded('gd')) {
    throw new RuntimeException('The GD extension is required to create fixture artwork.');
}

require_once $tcpdfPath;

$fixtureRoot = sys_get_temp_dir() . '/securiace-modern-invoice-' . bin2hex(random_bytes(8));
$fixtureAssetDirectory = $fixtureRoot . '/assets/img';
if (!mkdir($fixtureAssetDirectory, 0775, true) && !is_dir($fixtureAssetDirectory)) {
    throw new RuntimeException('Unable to create the fixture asset directory.');
}
$fixtureIncludesDirectory = $fixtureRoot . '/includes';
if (!mkdir($fixtureIncludesDirectory, 0775, true) && !is_dir($fixtureIncludesDirectory)) {
    throw new RuntimeException('Unable to create the fixture includes directory.');
}
$fixtureProfileHelperSource = realpath(__DIR__ . '/../securiace-pdf-profile.php');
$fixtureSnapshotValidatorSource = realpath(__DIR__ . '/../securiace-pdf-snapshot.php');
if ($fixtureProfileHelperSource === false || $fixtureSnapshotValidatorSource === false) {
    throw new RuntimeException('Unable to resolve invoice runtime helper sources.');
}
$GLOBALS['fixtureInvoiceProfileHelperPath'] = $fixtureIncludesDirectory . '/securiace-pdf-profile.php';
$GLOBALS['fixtureInvoiceSnapshotValidatorPath'] = $fixtureIncludesDirectory . '/securiace-pdf-snapshot.php';
$GLOBALS['fixtureInvoiceProtectedConfigPath'] = $fixtureIncludesDirectory . '/securiace-invoice-config.php';
$GLOBALS['fixtureInvoiceProfileHelperSource'] = $fixtureProfileHelperSource;
$GLOBALS['fixtureInvoiceSnapshotValidatorSource'] = $fixtureSnapshotValidatorSource;

define('ROOTDIR', $fixtureRoot);

final class FixtureInvoiceModel
{
    /** @var array<string, mixed> */
    private $currency;

    /** @var bool */
    private $proforma;

    /** @param array<string, mixed> $currency */
    public function __construct(array $currency, bool $proforma = false)
    {
        $this->currency = $currency;
        $this->proforma = $proforma;
    }

    /** @return array<string, mixed> */
    public function getCurrency(): array
    {
        return $this->currency;
    }

    public function isProformaInvoice(): bool
    {
        return $this->proforma;
    }
}

final class FixtureThrowingBarcodePdf extends TCPDF
{
    public function write2DBarcode(
        $code,
        $type,
        $x = '',
        $y = '',
        $w = '',
        $h = '',
        $style = array(),
        $align = '',
        $distort = false
    ) {
        throw new RuntimeException('Fixture barcode renderer failure.');
    }
}

/** @param array<string, mixed> $fixture */
function prepareInvoiceRuntimeFixture(array &$fixture): bool
{
    $profileMode = isset($fixture['_invoice_profile_helper_mode'])
        ? (string) $fixture['_invoice_profile_helper_mode']
        : 'normal';
    $snapshotMode = isset($fixture['_invoice_snapshot_validator_mode'])
        ? (string) $fixture['_invoice_snapshot_validator_mode']
        : 'normal';
    $configMode = isset($fixture['_invoice_protected_config_mode'])
        ? (string) $fixture['_invoice_protected_config_mode']
        : 'normal';
    $throwBarcode = !empty($fixture['_invoice_throw_barcode']);
    unset(
        $fixture['_invoice_profile_helper_mode'],
        $fixture['_invoice_snapshot_validator_mode'],
        $fixture['_invoice_protected_config_mode'],
        $fixture['_invoice_throw_barcode']
    );

    switch ($profileMode) {
        case 'normal':
            $profilePhp = "<?php\nreturn include '"
                . addslashes($GLOBALS['fixtureInvoiceProfileHelperSource']) . "';\n";
            break;
        case 'invalid-result':
            $profilePhp = "<?php\nreturn static function (array \$input = array()) { return 'invalid'; };\n";
            break;
        case 'runtime-failed':
            $profilePhp = "<?php\nreturn static function (array \$input = array()) { throw new RuntimeException('fixture profile failure'); };\n";
            break;
        case 'invalid-shape':
            $profilePhp = "<?php\nreturn static function (array \$input = array()) { return array('identity' => 'invalid', 'payment' => null); };\n";
            break;
        case 'invalid-nested-fields':
            $profilePhp = "<?php\nreturn static function (array \$input = array()) { return array(\n"
                . "'identity' => array('business_name' => array('invalid'), 'address_lines' => array(array('invalid')), 'support_email' => array('invalid')),\n"
                . "'registrations' => array('pan' => array('value' => array('invalid'))),\n"
                . "'payment' => array('upi' => array('id' => array('invalid'), 'valid' => true), 'bank_accounts' => array()),\n"
                . "'diagnostics' => array('warnings' => array('profile-field-invalid'))\n"
                . "); };\n";
            break;
        default:
            throw new RuntimeException('Unknown invoice profile helper fixture mode: ' . $profileMode);
    }

    switch ($snapshotMode) {
        case 'normal':
            $snapshotPhp = "<?php\nreturn include '"
                . addslashes($GLOBALS['fixtureInvoiceSnapshotValidatorSource']) . "';\n";
            break;
        case 'invalid-result':
            $snapshotPhp = "<?php\nreturn static function (array \$row) { return 'invalid'; };\n";
            break;
        case 'runtime-failed':
            $snapshotPhp = "<?php\nreturn static function (array \$row) { throw new RuntimeException('fixture snapshot failure'); };\n";
            break;
        default:
            throw new RuntimeException('Unknown invoice snapshot validator fixture mode: ' . $snapshotMode);
    }

    if ($configMode === 'normal') {
        $configPhp = "<?php\nreturn array();\n";
    } elseif ($configMode === 'invalid-result') {
        $configPhp = "<?php\nreturn 'invalid';\n";
    } elseif ($configMode === 'runtime-failed') {
        $configPhp = "<?php\nthrow new RuntimeException('fixture config failure');\n";
    } else {
        throw new RuntimeException('Unknown invoice protected config fixture mode: ' . $configMode);
    }

    foreach (array(
        $GLOBALS['fixtureInvoiceProfileHelperPath'] => $profilePhp,
        $GLOBALS['fixtureInvoiceSnapshotValidatorPath'] => $snapshotPhp,
        $GLOBALS['fixtureInvoiceProtectedConfigPath'] => $configPhp,
    ) as $path => $source) {
        if (file_put_contents($path, $source) === false) {
            throw new RuntimeException('Unable to write invoice runtime fixture: ' . $path);
        }
    }

    return $throwBarcode;
}

if (!function_exists('getTodaysDate')) {
    function getTodaysDate($includeTime = 0)
    {
        return $includeTime ? '5 Aug 2026, 18:45' : '5 Aug 2026';
    }
}

/** @param array<int, int> $background */
function createFixtureImage(string $path, int $width, int $height, array $background, callable $draw): void
{
    $image = imagecreatetruecolor($width, $height);
    if ($image === false) {
        throw new RuntimeException('Unable to allocate fixture artwork.');
    }
    imagealphablending($image, true);
    imagesavealpha($image, true);
    $fill = imagecolorallocate($image, $background[0], $background[1], $background[2]);
    imagefilledrectangle($image, 0, 0, $width, $height, $fill);
    $draw($image);
    if (!imagepng($image, $path)) {
        if (PHP_VERSION_ID < 80500) {
            imagedestroy($image);
        }
        throw new RuntimeException('Unable to write fixture artwork: ' . $path);
    }
    if (PHP_VERSION_ID < 80500) {
        imagedestroy($image);
    }
}

createFixtureImage(
    $fixtureAssetDirectory . '/logo.png',
    620,
    150,
    array(255, 254, 253),
    static function ($image): void {
        $brand = imagecolorallocate($image, 79, 11, 112);
        $ink = imagecolorallocate($image, 32, 28, 36);
        imagefilledrectangle($image, 12, 24, 76, 118, $brand);
        imagestring($image, 5, 101, 36, 'SECURIACE', $ink);
        imagestring($image, 3, 103, 76, 'SECURE CLOUD OPERATIONS', $brand);
    }
);

createFixtureImage(
    $fixtureAssetDirectory . '/stamp.png',
    240,
    240,
    array(255, 255, 255),
    static function ($image): void {
        $stamp = imagecolorallocate($image, 79, 11, 112);
        imageellipse($image, 120, 120, 210, 210, $stamp);
        imageellipse($image, 120, 120, 184, 184, $stamp);
        imagestring($image, 4, 45, 104, 'SECURIACE', $stamp);
        imagestring($image, 2, 70, 132, 'AUTHORIZED', $stamp);
    }
);

createFixtureImage(
    $fixtureAssetDirectory . '/sign.png',
    420,
    150,
    array(255, 255, 255),
    static function ($image): void {
        $ink = imagecolorallocate($image, 50, 16, 68);
        imagesetthickness($image, 4);
        imageline($image, 18, 104, 88, 54, $ink);
        imageline($image, 88, 54, 132, 106, $ink);
        imageline($image, 132, 106, 202, 34, $ink);
        imageline($image, 202, 34, 254, 96, $ink);
        imageline($image, 254, 96, 390, 62, $ink);
    }
);

/**
 * @param array<string, mixed> $fixture
 * @return array<string, mixed>
 */
function renderFixture(string $templatePath, string $outputDirectory, string $name, array $fixture, string $templateMode): array
{
    $paper = isset($fixture['_paper']) ? $fixture['_paper'] : 'A4';
    unset($fixture['_paper']);
    $throwBarcode = prepareInvoiceRuntimeFixture($fixture);

    $pdf = $throwBarcode
        ? new FixtureThrowingBarcodePdf('P', 'mm', $paper, true, 'UTF-8', false)
        : new TCPDF('P', 'mm', $paper, true, 'UTF-8', false);
    $pdf->setPrintHeader(false);
    $pdf->setPrintFooter(false);
    $pdf->SetCreator('Securiace fixture renderer');
    $pdf->SetAuthor('Securiace Technologies');
    $pdf->SetTitle($name);
    $pdf->AddPage();

    extract($fixture, EXTR_SKIP);
    $GLOBALS['currencyformat'] = isset($fixture['currencyformat']) ? $fixture['currencyformat'] : 1;

    $previousHandler = set_error_handler(
        static function (int $severity, string $message, string $file, int $line): bool {
            if (($severity & (E_WARNING | E_NOTICE | E_USER_WARNING | E_USER_NOTICE)) === 0) {
                return false;
            }
            throw new ErrorException($message, 0, $severity, $file, $line);
        }
    );

    try {
        include $templatePath;
    } finally {
        restore_error_handler();
    }

    $outputPath = rtrim($outputDirectory, DIRECTORY_SEPARATOR) . DIRECTORY_SEPARATOR . $name . '.pdf';
    $result = array('name' => $name, 'path' => $outputPath, 'pages' => $pdf->getNumPages());
    if ($templateMode === 'modern') {
        $result = array_merge($result, array(
            'template_pages' => $securiaceModernPageCount,
            'start_page' => $securiaceModernStartPage,
            'stamped_pages' => $securiaceModernStampedPages,
            'invoice_number' => $securiaceModernInvoiceNumber,
            'proforma_reference' => $securiaceModernProformaReference,
            'document_title' => $securiaceModernDocumentTitle,
            'document_kicker' => $securiaceModernDocumentKicker,
            'document_title_font_size' => $securiaceModernDocumentTitleFontSize,
            'gst_active' => $securiaceModernGstActive,
            'commercial_invoice_active' => $securiaceModernCommercialInvoiceActive,
            'numbering_valid' => $securiaceModernNumberingDiagnostics['valid'],
            'numbering_length' => $securiaceModernNumberingDiagnostics['length'],
            'numbering_max_length' => $securiaceModernNumberingDiagnostics['max_length'],
            'status_key' => $securiaceModernStatusKey,
            'is_overdue' => $securiaceModernIsOverdue,
            'days_overdue' => $securiaceModernDaysOverdue,
            'issue_date_display' => $securiaceModernIssueDateDisplay,
            'due_date_display' => $securiaceModernDueDateDisplay,
            'seller_registrations' => $securiaceModernSellerRegistrations,
            'issuer_name' => $securiaceModernCompanyName,
            'issuer_lines' => $securiaceModernSellerLines,
            'issuer_sources' => $securiaceModernIssuerDiagnostics['sources'],
            'issuer_warnings' => $securiaceModernIssuerDiagnostics['warnings'],
            'snapshot_applied' => $securiaceModernSnapshotApplied,
            'is_payable' => $securiaceModernIsPayable,
            'has_upi' => $securiaceModernCanUseUpi,
            'has_bank' => $securiaceModernHasBankDetails,
            'bank_branch' => isset($securiaceModernSelectedBankAccount['branch'])
                ? $securiaceModernSelectedBankAccount['branch']
                : null,
            'currency_code' => $securiaceModernCurrencyCode,
            'amount_paid_display' => $securiaceModernAmountPaidDisplay,
            'core_qr_present' => $securiaceModernCoreQrHtml !== '',
            'is_batch' => $securiaceModernIsBatch,
            'rendered_core_qr' => $securiaceModernRenderedCoreQr,
            'rendered_support' => $securiaceModernRenderedSupport,
            'rendered_notes' => $securiaceModernRenderedNotes,
            'rendered_renewals' => $securiaceModernRenderedRenewals,
            'rendered_authorization' => $securiaceModernRenderedAuthorization,
            'rendered_upi' => $securiaceModernRenderedUpi,
            'rendered_bank' => $securiaceModernRenderedBank,
            'rendered_settlement' => $securiaceModernRenderedSettlement,
            'transaction_reference' => isset($securiaceModernTransactions[0]['reference'])
                ? $securiaceModernTransactions[0]['reference']
                : null,
            'first_item_description' => isset($securiaceModernRenderedItemDescriptions[0])
                ? $securiaceModernRenderedItemDescriptions[0]
                : null,
            'settlement_mismatch' => $securiaceModernSettlementMismatch,
            'reconciliation_delta' => $securiaceModernReconciliationDeltaNumeric,
            'total_numeric' => $securiaceModernTotalNumeric,
            'balance_numeric' => $securiaceModernBalanceNumeric,
            'renewal_date' => isset($securiaceModernRenewals[0]['date'])
                ? $securiaceModernRenewals[0]['date']
                : null,
            'verification_id' => $securiaceModernVerificationId,
        ));
    }
    $pdf->Output($outputPath, 'F');

    if (!is_file($outputPath) || filesize($outputPath) < 1000) {
        throw new RuntimeException('Rendered fixture is missing or unexpectedly small: ' . $name);
    }
    $handle = fopen($outputPath, 'rb');
    if ($handle === false) {
        throw new RuntimeException('Unable to inspect rendered fixture: ' . $name);
    }
    $signature = fread($handle, 4);
    fclose($handle);
    if ($signature !== '%PDF') {
        throw new RuntimeException('Rendered fixture is not a PDF: ' . $name);
    }

    return $result;
}

/**
 * Exercise WHMCS's admin batch behavior: one TCPDF instance receives multiple
 * invoice pages, and every template include must stamp only its own page range.
 *
 * @param array<string, array<string, mixed>> $fixtures
 * @return array<int, array<string, mixed>>
 */
function renderBatchFixtures(string $templatePath, string $outputDirectory, array $fixtures): array
{
    $pdf = new TCPDF('P', 'mm', 'A4', true, 'UTF-8', false);
    $pdf->setPrintHeader(false);
    $pdf->setPrintFooter(false);
    $pdf->SetCreator('Securiace batch fixture renderer');
    $pdf->SetAuthor('Securiace Technologies');
    $pdf->SetTitle('Batch invoice fixture');

    $ranges = array();
    foreach ($fixtures as $name => $fixture) {
        $paper = isset($fixture['_paper']) ? $fixture['_paper'] : 'A4';
        unset($fixture['_paper']);
        prepareInvoiceRuntimeFixture($fixture);
        if (strtoupper((string) $paper) !== 'A4') {
            throw new RuntimeException('Batch fixtures must use the same A4 PDF instance.');
        }

        $pdf->AddPage();
        extract($fixture, EXTR_OVERWRITE);
        $securiaceInvoiceRenderProfile = 'batch';
        $GLOBALS['currencyformat'] = isset($fixture['currencyformat']) ? $fixture['currencyformat'] : 1;

        $previousHandler = set_error_handler(
            static function (int $severity, string $message, string $file, int $line): bool {
                if (($severity & (E_WARNING | E_NOTICE | E_USER_WARNING | E_USER_NOTICE)) === 0) {
                    return false;
                }
                throw new ErrorException($message, 0, $severity, $file, $line);
            }
        );
        try {
            include $templatePath;
        } finally {
            restore_error_handler();
        }

        $expectedPages = range($securiaceModernStartPage, $securiaceModernFinalPage);
        if ($securiaceModernStampedPages !== $expectedPages) {
            throw new RuntimeException(
                $name . ' stamped pages outside its own batch range: '
                . json_encode($securiaceModernStampedPages)
            );
        }
        $ranges[] = array(
            'name' => $name,
            'start' => $securiaceModernStartPage,
            'end' => $securiaceModernFinalPage,
            'stamped' => $securiaceModernStampedPages,
            'is_batch' => $securiaceModernIsBatch,
            'rendered_core_qr' => $securiaceModernRenderedCoreQr,
            'rendered_support' => $securiaceModernRenderedSupport,
            'rendered_notes' => $securiaceModernRenderedNotes,
            'rendered_renewals' => $securiaceModernRenderedRenewals,
            'rendered_authorization' => $securiaceModernRenderedAuthorization,
            'rendered_upi' => $securiaceModernRenderedUpi,
            'rendered_bank' => $securiaceModernRenderedBank,
            'rendered_settlement' => $securiaceModernRenderedSettlement,
        );
    }

    $outputPath = rtrim($outputDirectory, DIRECTORY_SEPARATOR) . DIRECTORY_SEPARATOR . 'batch-two-invoices.pdf';
    $pdf->Output($outputPath, 'F');
    if (!is_file($outputPath) || filesize($outputPath) < 1000) {
        throw new RuntimeException('Batch PDF fixture is missing or unexpectedly small.');
    }
    if (count($ranges) !== count($fixtures)) {
        throw new RuntimeException('Batch PDF did not render every requested invoice.');
    }
    for ($index = 1; $index < count($ranges); ++$index) {
        if ($ranges[$index]['start'] <= $ranges[$index - 1]['end']) {
            throw new RuntimeException('Batch invoice page ranges overlap.');
        }
    }

    return $ranges;
}

/** @param mixed $actual */
function assertFixtureValue(string $fixture, string $field, $actual, $expected): void
{
    if ($actual !== $expected) {
        throw new RuntimeException(
            $fixture . ' expected ' . $field . '=' . var_export($expected, true)
            . ', received ' . var_export($actual, true)
        );
    }
}

/** @param array<string, mixed> $overrides @return array<string, string> */
function invoiceSnapshotRow(array $overrides = array()): array
{
    $payload = array_replace_recursive(array(
        'schema_version' => 1,
        'issuer' => array(
            'identity' => array(
                'business_name' => 'Historical Example Technologies',
                'address_lines' => array('10 Archive Road', 'Pune, Maharashtra 411002', 'India'),
                'support_email' => 'archive@example.invalid',
                'mobile' => '+91 40000 00000',
                'website' => 'https://archive.example.invalid',
            ),
            'registrations' => array(
                'pan' => array('value' => 'FGHIJ5678K'),
                'udyam' => array('value' => 'UDYAM-MH-99-9999999'),
            ),
        ),
        'document' => array(
            'title' => 'Invoice',
            'gst_active' => false,
            'final_invoice_number' => 'ST/2073',
            'issue_date' => '2026-08-05',
        ),
    ), $overrides);
    $json = json_encode($payload, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
    if (!is_string($json)) {
        throw new RuntimeException('Unable to encode invoice snapshot fixture.');
    }
    return array('payload' => $json, 'checksum' => hash('sha256', $json));
}

/** @param array<string, mixed> $overrides */
function invoiceFixture(array $overrides = array()): array
{
    $base = array(
        'pdfFont' => 'dejavusans',
        'securiaceInvoiceToday' => '5 Aug 2026',
        'companyname' => 'Example Technologies',
        'companyurl' => 'https://portal.example.invalid',
        'companyaddress' => array(
            'UPI: billing@example.invalid',
            '[Bank Account: INR]',
            'Account Name: EXAMPLE TECHNOLOGIES',
            'Account Number: 0000000000000000',
            'IFSC: DEMO0000001',
            'Bank Branch: Example Branch',
            'Account Type: Current',
            'Bank Name: Example Bank',
            '',
            'Company Address: 88 Secure Cloud Avenue',
            'Pune, Maharashtra 411001',
            'India',
            'Mobile: +91 20000 00000',
            'PAN: ABCDE1234F',
            'MSME: UDYAM-MH-00-0000000',
        ),
        'securiacePdfSettings' => array(
            'company_email' => 'helpdesk@example.invalid',
            'company_url' => 'https://portal.example.invalid',
            'tax_code' => '',
            'late_fee_type' => 'Percentage',
            'late_fee_amount' => '10.00',
            'late_fee_minimum' => '100.00',
        ),
        'taxCode' => '27ABCDE1234F1Z5',
        'taxIdLabel' => 'GSTIN',
        'currencycode' => 'INR',
        'currencyprefix' => '₹',
        'currencysuffix' => 'INR',
        'currencyformat' => 1,
        'model' => new FixtureInvoiceModel(array(
            'code' => 'INR',
            'prefix' => '₹',
            'suffix' => 'INR',
            'format' => 1,
        )),
        'clientsdetails' => array(
            'id' => 2048,
            'companyname' => 'Northstar Digital Private Limited',
            'firstname' => 'Asha',
            'lastname' => 'Mehta',
            'address1' => '42 Product Road',
            'address2' => 'Operations Wing',
            'city' => 'Bengaluru',
            'state' => 'Karnataka',
            'postcode' => '560001',
            'country' => 'India',
            'email' => 'accounts@example.invalid',
            'phonenumber' => '+91 90000 00000',
            'tax_id' => '29AAACN0000A1Z5',
        ),
        'customfields' => array(
            array('fieldname' => 'Purchase order', 'value' => 'PO-2026-0814'),
        ),
        'invoiceid' => 300000123,
        'invoicenum' => 'INV-2026-00123',
        'pagetitle' => 'Invoice #INV-2026-00123',
        'isProforma' => false,
        'datecreated' => '5 Aug 2026',
        'duedate' => '12 Aug 2026',
        'datepaid' => '',
        'status' => 'Unpaid',
        'invoiceitems' => array(
            array(
                'description' => "Managed VPS — Growth\nService period: 05/08/2026 - 04/09/2026",
                'amount' => '₹ 8,466.10 INR',
            ),
        ),
        'subtotal' => '₹ 8,466.10 INR',
        'discount' => '₹ 0.00 INR',
        'taxname' => 'IGST',
        'taxrate' => '18.00',
        'tax' => '₹ 1,523.90 INR',
        'taxname2' => '',
        'taxrate2' => '',
        'tax2' => '₹ 0.00 INR',
        'credit' => '₹ 0.00 INR',
        'total' => '₹ 9,990.00 INR',
        'balance' => '₹ 9,990.00 INR',
        'transactions' => array(),
        'notes' => 'Thank you for choosing Example Technologies. Please quote the invoice number with every payment.',
        'securiaceInvoiceConfig' => array(
            'company_email' => 'billing@example.invalid',
            'company_phone' => '+91 20000 00000',
            'company_pan' => 'ABCDE1234F',
            'company_msme' => 'UDYAM-MH-00-0000000',
            'bank' => array(
                'account_name' => 'Fallback Technologies',
                'account_number' => '0000000000000000',
                'ifsc' => 'DEMO0000001',
                'branch' => 'Fallback Branch',
                'account_type' => 'Current',
                'bank_name' => 'Fallback Bank',
            ),
            'bank_currencies' => array('INR'),
            'upi_id' => 'billing@example.invalid',
            'verification_secret' => 'fixture-only-secret',
            'date_order' => 'DMY',
            'show_it_act_label' => true,
            'jurisdiction' => 'Example Jurisdiction',
            'late_fee_text' => '',
            'tds_note' => 'If applicable, deduct TDS under Section 194J and provide Form 16A.',
        ),
    );

    return array_replace_recursive($base, $overrides);
}

$paidTransaction = array(
    'date' => 'Wednesday, August 5th, 2026',
    'gateway' => 'NEFT/IMPS/UPI/BHIM/Cheque (Offline Only)',
    'transid' => 'UTR-AXIS-20260805-883711',
    'amount' => '₹ 9,990.00 INR',
    'status' => 'Completed',
);

$longItems = array();
for ($index = 1; $index <= 28; ++$index) {
    $longItems[] = array(
        'description' => sprintf(
            'Managed infrastructure line %02d — monitoring, security hardening, backup verification and operational support',
            $index
        ),
        'qty' => $index % 4 === 0 ? 2 : 1,
        'amount' => '₹ 600.00 INR',
    );
}

$fixtures = array(
    'paid' => invoiceFixture(array(
        'status' => 'Paid',
        'datepaid' => '5 Aug 2026',
        'balance' => '₹ 0.00 INR',
        'transactions' => array($paidTransaction),
    )),
    'unpaid' => invoiceFixture(),
    'partial' => invoiceFixture(array(
        'transactions' => array(array_replace($paidTransaction, array('amount' => '₹ 5,000.00 INR'))),
        'balance' => '₹ 4,990.00 INR',
    )),
    'refunded' => invoiceFixture(array(
        'status' => 'Refunded',
        'datepaid' => '5 Aug 2026',
        'balance' => '₹ 0.00 INR',
        'transactions' => array(
            $paidTransaction,
            array(
                'date' => '6 Aug 2026',
                'gateway' => 'Bank Transfer',
                'transid' => 'REFUND-20260806-2249',
                'amount' => '₹ -9,990.00 INR',
                'status' => 'Refunded',
            ),
        ),
    )),
    'proforma' => invoiceFixture(array(
        'invoiceid' => 300000124,
        'invoicenum' => '',
        'pagetitle' => 'Proforma Invoice #300000124',
        'isProformaInvoice' => true,
        'model' => new FixtureInvoiceModel(array(
            'code' => 'INR',
            'prefix' => '₹',
            'suffix' => 'INR',
            'format' => 1,
        ), true),
        'securiaceInvoiceConfig' => array(
            'gst_registered' => true,
            'gst_effective_date' => '2026-08-01',
        ),
    )),
    'paid-adjusted' => invoiceFixture(array(
        'status' => 'Paid',
        'datepaid' => '5 Aug 2026',
        'balance' => '₹ 199.00 INR',
        'transactions' => array(array_replace($paidTransaction, array('amount' => '₹ 9,791.00 INR'))),
    )),
    'reconciled-adjustment' => invoiceFixture(array(
        'invoiceid' => 300000126,
        'invoicenum' => 'INV-2026-00126',
        'invoiceitems' => array(array(
            'description' => "WordPress Deluxe\nService period: 03/08/2026 - 02/08/2027",
            'amount' => '₹ 0.00 INR',
        )),
        'subtotal' => '₹ 0.00 INR',
        'taxname' => '',
        'taxrate' => '',
        'tax' => '₹ 0.00 INR',
        'total' => '₹ 9,990.00 INR',
        'balance' => '₹ 9,990.00 INR',
    )),
    'overdue' => invoiceFixture(array(
        'status' => 'Unpaid',
        'datecreated' => 'Saturday, July 4th, 2026',
        'duedate' => 'Monday, August 3rd, 2026',
        'invoicenum' => '',
        'pagetitle' => 'Proforma Invoice #300000123',
        'model' => new FixtureInvoiceModel(array(
            'code' => 'INR',
            'prefix' => '₹',
            'suffix' => 'INR',
            'format' => 1,
        ), true),
    )),
    'cancelled' => invoiceFixture(array(
        'status' => 'Cancelled',
    )),
    'collections' => invoiceFixture(array(
        'status' => 'Collections',
    )),
    'draft' => invoiceFixture(array(
        'status' => 'Draft',
    )),
    'zero-total' => invoiceFixture(array(
        'invoiceitems' => array(array('description' => 'Complimentary migration assistance', 'amount' => '₹ 0.00 INR')),
        'subtotal' => '₹ 0.00 INR',
        'taxname' => '',
        'taxrate' => '',
        'tax' => '₹ 0.00 INR',
        'total' => '₹ 0.00 INR',
        'balance' => '₹ 0.00 INR',
    )),
    'euro-format2' => invoiceFixture(array(
        'invoiceid' => 300000127,
        'invoicenum' => 'INV-2026-00127',
        'currencycode' => 'EUR',
        'currencyprefix' => '€',
        'currencysuffix' => 'EUR',
        'currencyformat' => 2,
        'model' => new FixtureInvoiceModel(array(
            'code' => 'EUR',
            'prefix' => '€',
            'suffix' => 'EUR',
            'format' => 2,
        )),
        'invoiceitems' => array(array('description' => 'European managed infrastructure', 'amount' => '€ 1.234,56 EUR')),
        'subtotal' => '€ 1.234,56 EUR',
        'taxname' => '',
        'taxrate' => '',
        'tax' => '€ 0,00 EUR',
        'total' => '€ 1.234,56 EUR',
        'balance' => '€ 1.234,56 EUR',
        'securiaceInvoiceConfig' => array(
            'commercial_invoice_currencies' => array('EUR'),
        ),
    )),
    'gst-active' => invoiceFixture(array(
        'invoiceid' => 300000133,
        'invoicenum' => 'ST/1234567890123',
        'status' => 'Paid',
        'datepaid' => '5 Aug 2026',
        'balance' => '₹ 0.00 INR',
        'transactions' => array($paidTransaction),
        'securiaceInvoiceConfig' => array(
            'gst_registered' => true,
            'gst_effective_date' => '2026-08-01',
        ),
    )),
    'gst-not-effective' => invoiceFixture(array(
        'invoiceid' => 300000134,
        'invoicenum' => 'ST/2071',
        'securiaceInvoiceConfig' => array(
            'gst_registered' => true,
            'gst_effective_date' => '2026-09-01',
        ),
    )),
    'gst-export-title' => invoiceFixture(array(
        'invoiceid' => 300000136,
        'invoicenum' => 'ST/2072',
        'status' => 'Paid',
        'datepaid' => '5 Aug 2026',
        'balance' => '₹ 0.00 INR',
        'transactions' => array($paidTransaction),
        'securiaceInvoiceConfig' => array(
            'gst_registered' => true,
            'gst_effective_date' => '2026-08-01',
            'gst_final_title' => 'Tax Invoice — Export of Services',
        ),
    )),
    'invalid-final-number' => invoiceFixture(array(
        'invoiceid' => 300000135,
        'invoicenum' => 'ST/12345678901234',
    )),
    'snapshot-paid' => invoiceFixture(array(
        'invoiceid' => 300000137,
        'invoicenum' => 'ST/2073',
        'status' => 'Paid',
        'datepaid' => '5 Aug 2026',
        'balance' => '₹ 0.00 INR',
        'transactions' => array($paidTransaction),
        'securiacePdfSnapshotRow' => invoiceSnapshotRow(),
    )),
    'snapshot-proforma-ignored' => invoiceFixture(array(
        'invoiceid' => 300000138,
        'invoicenum' => '',
        'pagetitle' => 'Proforma Invoice #300000138',
        'model' => new FixtureInvoiceModel(array(
            'code' => 'INR',
            'prefix' => '₹',
            'suffix' => 'INR',
            'format' => 1,
        ), true),
        'securiacePdfSnapshotRow' => invoiceSnapshotRow(),
    )),
    'snapshot-corrupt' => invoiceFixture(array(
        'invoiceid' => 300000139,
        'invoicenum' => 'ST/2074',
        'securiacePdfSnapshotRow' => array(
            'payload' => '{}',
            'checksum' => str_repeat('0', 64),
        ),
    )),
    'profile-helper-invalid-result' => invoiceFixture(array(
        'invoiceid' => 300000140,
        'companyname' => 'Profile Fallback Issuer',
        '_invoice_profile_helper_mode' => 'invalid-result',
    )),
    'profile-helper-runtime-failed' => invoiceFixture(array(
        'invoiceid' => 300000141,
        'companyname' => 'Runtime Fallback Issuer',
        '_invoice_profile_helper_mode' => 'runtime-failed',
    )),
    'profile-helper-invalid-shape' => invoiceFixture(array(
        'invoiceid' => 300000142,
        'companyname' => 'Shape Fallback Issuer',
        '_invoice_profile_helper_mode' => 'invalid-shape',
    )),
    'profile-helper-invalid-nested-fields' => invoiceFixture(array(
        'invoiceid' => 300000143,
        '_invoice_profile_helper_mode' => 'invalid-nested-fields',
    )),
    'snapshot-validator-invalid-result' => invoiceFixture(array(
        'invoiceid' => 300000144,
        'invoicenum' => 'ST/2075',
        'securiacePdfSnapshotRow' => invoiceSnapshotRow(),
        '_invoice_snapshot_validator_mode' => 'invalid-result',
    )),
    'snapshot-validator-runtime-failed' => invoiceFixture(array(
        'invoiceid' => 300000145,
        'invoicenum' => 'ST/2076',
        'securiacePdfSnapshotRow' => invoiceSnapshotRow(),
        '_invoice_snapshot_validator_mode' => 'runtime-failed',
    )),
    'protected-config-invalid-result' => invoiceFixture(array(
        'invoiceid' => 300000146,
        '_invoice_protected_config_mode' => 'invalid-result',
    )),
    'protected-config-runtime-failed' => invoiceFixture(array(
        'invoiceid' => 300000147,
        '_invoice_protected_config_mode' => 'runtime-failed',
    )),
    'upi-barcode-runtime-failed' => invoiceFixture(array(
        'invoiceid' => 300000148,
        '_invoice_throw_barcode' => true,
    )),
    'unknown-currency' => invoiceFixture(array(
        'invoiceid' => 300000129,
        'invoicenum' => 'INV-2026-00129',
        'currencycode' => '',
        'currencyprefix' => '',
        'currencysuffix' => '',
        'model' => new FixtureInvoiceModel(array()),
    )),
    'entity-description' => invoiceFixture(array(
        'invoiceid' => 300000130,
        'invoicenum' => 'INV-2026-00130',
        'invoiceitems' => array(array(
            'description' => 'Security R&amp;D &lt;managed&gt;<br>Service period: 05/08/2026 - 04/09/2026',
            'amount' => '₹ 8,466.10 INR',
        )),
    )),
    'whmcs9-ledger' => invoiceFixture(array(
        'invoiceid' => 300000131,
        'invoicenum' => 'INV-2026-00131',
        'status' => 'Paid',
        'statuslocale' => 'Paid',
        'datepaid' => '5 Aug 2026',
        'invoiceamount' => '₹ 9,990.00 INR',
        'amountpaid' => '₹ 9,990.00 INR',
        'balance' => '₹ 0.00 INR',
        'invoiceQrHtml' => '<div style="font-size:7px">WHMCS core invoice QR</div>',
        'transactions' => array(array(
            'date' => '5 Aug 2026',
            'gateway' => 'Bank Transfer',
            'typeLabel' => 'Payment',
            'referenceId' => 'WHMCS9-REFERENCE-00131',
            'isCreditNote' => false,
            'isDebitNote' => false,
            'amount' => '₹ 9,990.00 INR',
        )),
    )),
    'whmcs9-credit-note' => invoiceFixture(array(
        'invoiceid' => 300000132,
        'invoicenum' => 'INV-2026-00132',
        'transactions' => array(array(
            'date' => '5 Aug 2026',
            'gateway' => '',
            'typeLabel' => 'Credit',
            'referenceId' => 'CN-00132',
            'isCreditNote' => true,
            'isDebitNote' => false,
            'amount' => '₹ 1,000.00 INR',
        )),
    )),
    'invalid-config' => invoiceFixture(array(
        'invoiceid' => 300000128,
        'invoicenum' => 'INV-2026-00128',
        'companyaddress' => array('Valid company line', array('invalid nested line')),
        'clientsdetails' => null,
        'securiaceInvoiceConfig' => array(
            'company_email' => array('invalid'),
            'bank' => 'invalid',
            'upi_id' => '',
        ),
    )),
    'long-letter' => invoiceFixture(array(
        '_paper' => 'LETTER',
        'invoiceid' => 300000125,
        'invoicenum' => 'INV-2026-00125',
        'invoiceitems' => $longItems,
        'clientsdetails' => array(
            'companyname' => 'International Infrastructure & Reliability Engineering Corporation',
            'address1' => 'Suite 1208, 355 Long International Commerce Boulevard',
            'address2' => 'Attn: Finance, Procurement and Cloud Operations',
            'city' => 'San Francisco',
            'state' => 'California',
            'postcode' => '94105',
            'country' => 'United States',
            'email' => 'ap-team@example.invalid',
            'phonenumber' => '+1 555 010 2026',
            'tax_id' => 'US-TAX-000000',
        ),
        'subtotal' => '₹ 16,800.00 INR',
        'tax' => '₹ 3,024.00 INR',
        'total' => '₹ 19,824.00 INR',
        'balance' => '₹ 19,824.00 INR',
        'notes' => str_repeat('This fixture verifies page continuation, dense line items, long names and stable footer placement. ', 8),
    )),
);

$expectations = array(
    'paid' => array(
        'is_payable' => false,
        'has_upi' => false,
        'has_bank' => true,
        'rendered_bank' => false,
        'rendered_authorization' => true,
        'rendered_support' => false,
        'rendered_renewals' => true,
        'settlement_mismatch' => false,
        'document_title' => 'Invoice',
        'document_kicker' => 'INVOICE',
        'gst_active' => false,
        'numbering_valid' => true,
        'renewal_date' => '4 Sep 2026',
        'pages' => 1,
        'issuer_name' => 'Example Technologies',
        'issuer_lines' => array(
            '88 Secure Cloud Avenue',
            'Pune, Maharashtra 411001',
            'India',
            'Helpdesk · helpdesk@example.invalid',
            'Mobile · +91 20000 00000',
        ),
        'issuer_sources' => array(
            'identity.business_name' => 'whmcs.company_name',
            'identity.address_lines' => 'pay_to.address',
            'identity.support_email' => 'whmcs.company_email',
            'identity.mobile' => 'pay_to.mobile',
            'identity.website' => 'whmcs.company_url',
            'registrations.pan' => 'pay_to.pan',
            'registrations.udyam' => 'pay_to.udyam',
            'registrations.gstin' => 'whmcs.tax_code',
            'payment.bank_accounts' => 'pay_to.bank',
            'payment.upi' => 'pay_to.upi_id',
            'payment.upi.payee_name' => 'whmcs.company_name',
        ),
        'seller_registrations' => array(
            'PAN · ABCDE1234F',
            'MSME · UDYAM-MH-00-0000000',
        ),
    ),
    'unpaid' => array('is_payable' => true, 'has_upi' => true, 'has_bank' => true, 'bank_branch' => 'Example Branch', 'rendered_upi' => true, 'rendered_bank' => true, 'rendered_support' => true, 'settlement_mismatch' => false, 'document_title' => 'Invoice'),
    'partial' => array('is_payable' => true, 'has_upi' => true, 'settlement_mismatch' => false, 'document_title' => 'Invoice'),
    'refunded' => array('is_payable' => false, 'has_upi' => false, 'rendered_support' => false, 'settlement_mismatch' => false, 'document_title' => 'Invoice'),
    'proforma' => array('is_payable' => true, 'has_upi' => true, 'rendered_upi' => true, 'settlement_mismatch' => false, 'document_title' => 'Proforma Invoice', 'document_kicker' => 'PROFORMA INVOICE', 'invoice_number' => 'PI/300000124', 'proforma_reference' => 'PI/300000124', 'gst_active' => true, 'numbering_valid' => true),
    'paid-adjusted' => array('is_payable' => false, 'has_upi' => false, 'settlement_mismatch' => true, 'document_title' => 'Invoice'),
    'reconciled-adjustment' => array('is_payable' => true, 'has_upi' => true, 'settlement_mismatch' => false, 'document_title' => 'Invoice', 'reconciliation_delta' => 9990.0, 'renewal_date' => '2 Aug 2027'),
    'overdue' => array('is_payable' => true, 'has_upi' => true, 'rendered_upi' => true, 'settlement_mismatch' => false, 'document_title' => 'Proforma Invoice', 'invoice_number' => 'PI/300000123', 'status_key' => 'overdue', 'is_overdue' => true, 'days_overdue' => 2, 'issue_date_display' => '4 Jul 2026', 'due_date_display' => '3 Aug 2026'),
    'cancelled' => array('is_payable' => false, 'has_upi' => false, 'settlement_mismatch' => false, 'document_title' => 'Invoice'),
    'collections' => array('is_payable' => false, 'has_upi' => false, 'settlement_mismatch' => false, 'document_title' => 'Invoice'),
    'draft' => array('is_payable' => false, 'has_upi' => false, 'settlement_mismatch' => false, 'document_title' => 'Invoice'),
    'zero-total' => array('is_payable' => false, 'has_upi' => false, 'settlement_mismatch' => false, 'document_title' => 'Invoice', 'total_numeric' => 0.0, 'balance_numeric' => 0.0),
    'euro-format2' => array('is_payable' => true, 'has_upi' => false, 'has_bank' => false, 'rendered_bank' => false, 'rendered_support' => true, 'settlement_mismatch' => false, 'document_title' => 'Commercial Invoice', 'document_kicker' => 'COMMERCIAL INVOICE', 'commercial_invoice_active' => true, 'numbering_valid' => true, 'total_numeric' => 1234.56, 'balance_numeric' => 1234.56),
    'gst-active' => array('is_payable' => false, 'has_upi' => false, 'document_title' => 'Tax Invoice', 'document_kicker' => 'TAX INVOICE', 'gst_active' => true, 'numbering_valid' => true, 'numbering_length' => 16, 'numbering_max_length' => 16, 'seller_registrations' => array('PAN · ABCDE1234F', 'MSME · UDYAM-MH-00-0000000', 'GSTIN · 27ABCDE1234F1Z5')),
    'gst-not-effective' => array('is_payable' => true, 'document_title' => 'Invoice', 'document_kicker' => 'INVOICE', 'gst_active' => false, 'numbering_valid' => true, 'seller_registrations' => array('PAN · ABCDE1234F', 'MSME · UDYAM-MH-00-0000000')),
    'gst-export-title' => array('is_payable' => false, 'document_title' => 'Tax Invoice — Export of Services', 'document_kicker' => 'TAX INVOICE — EXPORT OF SERVICES', 'document_title_font_size' => 14, 'gst_active' => true, 'numbering_valid' => true),
    'invalid-final-number' => array('is_payable' => true, 'document_title' => 'Invoice', 'numbering_valid' => false, 'numbering_length' => 17, 'numbering_max_length' => 16, 'issuer_warnings' => array('final-invoice-number-invalid')),
    'snapshot-paid' => array('is_payable' => false, 'document_title' => 'Invoice', 'snapshot_applied' => true, 'issuer_name' => 'Historical Example Technologies', 'issuer_lines' => array('10 Archive Road', 'Pune, Maharashtra 411002', 'India', 'Helpdesk · archive@example.invalid', 'Mobile · +91 40000 00000'), 'seller_registrations' => array('PAN · FGHIJ5678K', 'MSME · UDYAM-MH-99-9999999'), 'rendered_bank' => false, 'rendered_upi' => false),
    'snapshot-proforma-ignored' => array('is_payable' => true, 'document_title' => 'Proforma Invoice', 'snapshot_applied' => false, 'issuer_name' => 'Example Technologies'),
    'snapshot-corrupt' => array('is_payable' => true, 'document_title' => 'Invoice', 'snapshot_applied' => false, 'issuer_name' => 'Example Technologies', 'issuer_warnings' => array('snapshot-checksum-mismatch')),
    'profile-helper-invalid-result' => array('is_payable' => true, 'issuer_name' => 'Profile Fallback Issuer', 'has_upi' => false, 'issuer_warnings' => array('profile-helper-invalid-result')),
    'profile-helper-runtime-failed' => array('is_payable' => true, 'issuer_name' => 'Runtime Fallback Issuer', 'has_upi' => false, 'issuer_warnings' => array('profile-helper-runtime-failed')),
    'profile-helper-invalid-shape' => array('is_payable' => true, 'issuer_name' => 'Issuer', 'has_upi' => false, 'issuer_warnings' => array('profile-identity-invalid', 'profile-payment-invalid')),
    'profile-helper-invalid-nested-fields' => array('is_payable' => true, 'issuer_name' => 'Issuer', 'has_upi' => false, 'issuer_warnings' => array('profile-field-invalid')),
    'snapshot-validator-invalid-result' => array('is_payable' => true, 'snapshot_applied' => false, 'issuer_name' => 'Example Technologies', 'issuer_warnings' => array('snapshot-validator-invalid-result')),
    'snapshot-validator-runtime-failed' => array('is_payable' => true, 'snapshot_applied' => false, 'issuer_name' => 'Example Technologies', 'issuer_warnings' => array('snapshot-validator-runtime-failed')),
    'protected-config-invalid-result' => array('is_payable' => true, 'issuer_name' => 'Example Technologies', 'issuer_warnings' => array('protected-config-invalid-result')),
    'protected-config-runtime-failed' => array('is_payable' => true, 'issuer_name' => 'Example Technologies', 'issuer_warnings' => array('protected-config-include-failed')),
    'upi-barcode-runtime-failed' => array('is_payable' => true, 'has_upi' => true, 'rendered_upi' => true, 'issuer_warnings' => array('upi-qr-render-failed')),
    'unknown-currency' => array('is_payable' => true, 'has_upi' => false, 'rendered_support' => true, 'currency_code' => '', 'document_title' => 'Invoice'),
    'entity-description' => array('is_payable' => true, 'has_upi' => true, 'first_item_description' => "Security R&D <managed>\nService period: 05/08/2026 - 04/09/2026", 'document_title' => 'Invoice'),
    'whmcs9-ledger' => array('is_payable' => false, 'has_upi' => false, 'currency_code' => 'INR', 'core_qr_present' => true, 'rendered_core_qr' => false, 'transaction_reference' => 'WHMCS9-REFERENCE-00131', 'amount_paid_display' => '₹ 9,990.00 INR', 'document_title' => 'Invoice'),
    'whmcs9-credit-note' => array('is_payable' => true, 'has_upi' => true, 'transaction_reference' => 'Credit note · CN-00132', 'document_title' => 'Invoice'),
    'invalid-config' => array('is_payable' => true, 'has_upi' => false, 'settlement_mismatch' => false, 'document_title' => 'Invoice'),
    'long-letter' => array('is_payable' => true, 'has_upi' => true, 'settlement_mismatch' => false, 'document_title' => 'Invoice'),
);

if ($templateMode === 'legacy') {
    $fixtures = array(
        'legacy-paid' => invoiceFixture(array(
            'status' => 'Paid',
            'datepaid' => '5 Aug 2026',
            'balance' => '₹ 0.00 INR',
            'transactions' => array($paidTransaction),
        )),
        'legacy-unpaid' => invoiceFixture(),
    );
    $expectations = array('legacy-paid' => array(), 'legacy-unpaid' => array());
}

$results = array();
try {
    foreach ($fixtures as $name => $fixture) {
        $result = renderFixture($templatePath, $outputDirectory, $name, $fixture, $templateMode);
        foreach ($expectations[$name] as $field => $expected) {
            assertFixtureValue($name, $field, $result[$field], $expected);
        }
        if ($templateMode === 'modern') {
            assertFixtureValue($name, 'template_pages', $result['pages'], $result['template_pages']);
        }
        if ($templateMode === 'modern' && $name === 'long-letter' && $result['pages'] < 2) {
            throw new RuntimeException('Long Letter fixture should span at least two pages.');
        }
        $results[$name] = $result;
    }

    if ($templateMode === 'modern') {
        $batchRanges = renderBatchFixtures(
            $templatePath,
            $outputDirectory,
            array(
                'batch-paid' => array_replace($fixtures['paid'], array(
                    'invoiceQrHtml' => '<div>Batch QR must not render</div>',
                    'notes' => str_repeat('Batch notes must not render. ', 20),
                )),
                'batch-unpaid' => $fixtures['unpaid'],
            )
        );
        assertFixtureValue('batch-paid', 'stamped_pages', $batchRanges[0]['stamped'], array(1));
        assertFixtureValue('batch-unpaid', 'stamped_pages', $batchRanges[1]['stamped'], array(2));
        foreach ($batchRanges as $batchRange) {
            assertFixtureValue($batchRange['name'], 'is_batch', $batchRange['is_batch'], true);
            foreach (array(
                'rendered_core_qr',
                'rendered_support',
                'rendered_notes',
                'rendered_renewals',
                'rendered_authorization',
                'rendered_upi',
                'rendered_bank',
                'rendered_settlement',
            ) as $suppressedField) {
                assertFixtureValue($batchRange['name'], $suppressedField, $batchRange[$suppressedField], false);
            }
        }

        $secondPaid = renderFixture($templatePath, $outputDirectory, 'paid-repeat', $fixtures['paid'], $templateMode);
        assertFixtureValue(
            'paid-repeat',
            'verification_id',
            $secondPaid['verification_id'],
            $results['paid']['verification_id']
        );
        @unlink($secondPaid['path']);
    }

    foreach ($results as $result) {
        if ($templateMode === 'modern') {
            fwrite(
                STDOUT,
                sprintf(
                    "%-22s %d page(s)  payable=%s  upi=%s  %s\n",
                    $result['name'],
                    $result['pages'],
                    $result['is_payable'] ? 'yes' : 'no',
                    $result['has_upi'] ? 'yes' : 'no',
                    basename($result['path'])
                )
            );
        } else {
            fwrite(STDOUT, sprintf("%-22s %d page(s)  %s\n", $result['name'], $result['pages'], basename($result['path'])));
        }
    }
    fwrite(STDOUT, ucfirst($templateMode) . " invoice TCPDF fixtures passed.\n");
} finally {
    $paths = array(
        $fixtureAssetDirectory . '/logo.png',
        $fixtureAssetDirectory . '/stamp.png',
        $fixtureAssetDirectory . '/sign.png',
    );
    foreach ($paths as $path) {
        if (is_file($path)) {
            @unlink($path);
        }
    }
    @rmdir($fixtureAssetDirectory);
    @rmdir(dirname($fixtureAssetDirectory));
    @rmdir($fixtureRoot);
}
