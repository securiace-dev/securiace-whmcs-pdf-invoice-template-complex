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

define('ROOTDIR', $fixtureRoot);

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

    $pdf = new TCPDF('P', 'mm', $paper, true, 'UTF-8', false);
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
            'invoice_number' => $securiaceModernInvoiceNumber,
            'document_title' => $securiaceModernDocumentTitle,
            'is_payable' => $securiaceModernIsPayable,
            'has_upi' => $securiaceModernCanUseUpi,
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

/** @param array<string, mixed> $overrides */
function invoiceFixture(array $overrides = array()): array
{
    $base = array(
        'pdfFont' => 'dejavusans',
        'companyname' => 'Securiace Technologies',
        'companyaddress' => array('88 Secure Cloud Avenue', 'Pune, Maharashtra 411001', 'India'),
        'taxCode' => '27ABCDE1234F1Z5',
        'taxIdLabel' => 'GSTIN',
        'currencycode' => 'INR',
        'currencyprefix' => '₹',
        'currencysuffix' => 'INR',
        'currencyformat' => 1,
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
        'notes' => 'Thank you for choosing Securiace. Please quote the invoice number with every payment.',
        'securiaceInvoiceConfig' => array(
            'company_email' => 'billing@example.invalid',
            'company_phone' => '+91 20000 00000',
            'company_pan' => 'ABCDE1234F',
            'company_msme' => 'UDYAM-MH-00-0000000',
            'bank' => array(
                'account_name' => 'Securiace Technologies',
                'account_number' => '0000000000000000',
                'ifsc' => 'DEMO0000001',
                'account_type' => 'Current',
                'bank_name' => 'Example Bank',
            ),
            'upi_id' => 'billing@example.invalid',
            'verification_secret' => 'fixture-only-secret',
            'date_order' => 'DMY',
            'show_it_act_label' => true,
            'jurisdiction' => 'Pune, Maharashtra',
            'overdue_interest' => '18% p.a.',
            'tds_note' => 'If applicable, deduct TDS under Section 194J and provide Form 16A.',
        ),
    );

    return array_replace_recursive($base, $overrides);
}

$paidTransaction = array(
    'date' => '5 Aug 2026',
    'gateway' => 'Bank Transfer',
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
        'status' => 'Overdue',
        'duedate' => '1 Aug 2026',
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
        'invoiceitems' => array(array('description' => 'European managed infrastructure', 'amount' => '€ 1.234,56 EUR')),
        'subtotal' => '€ 1.234,56 EUR',
        'taxname' => '',
        'taxrate' => '',
        'tax' => '€ 0,00 EUR',
        'total' => '€ 1.234,56 EUR',
        'balance' => '€ 1.234,56 EUR',
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
    'paid' => array('is_payable' => false, 'has_upi' => false, 'settlement_mismatch' => false, 'document_title' => 'Invoice', 'renewal_date' => '4 Sep 2026'),
    'unpaid' => array('is_payable' => true, 'has_upi' => true, 'settlement_mismatch' => false, 'document_title' => 'Invoice'),
    'partial' => array('is_payable' => true, 'has_upi' => true, 'settlement_mismatch' => false, 'document_title' => 'Invoice'),
    'refunded' => array('is_payable' => false, 'has_upi' => false, 'settlement_mismatch' => false, 'document_title' => 'Invoice'),
    'proforma' => array('is_payable' => true, 'has_upi' => true, 'settlement_mismatch' => false, 'document_title' => 'Proforma Invoice', 'invoice_number' => '300000124'),
    'paid-adjusted' => array('is_payable' => false, 'has_upi' => false, 'settlement_mismatch' => true, 'document_title' => 'Invoice'),
    'reconciled-adjustment' => array('is_payable' => true, 'has_upi' => true, 'settlement_mismatch' => false, 'document_title' => 'Invoice', 'reconciliation_delta' => 9990.0, 'renewal_date' => '2 Aug 2027'),
    'overdue' => array('is_payable' => true, 'has_upi' => true, 'settlement_mismatch' => false, 'document_title' => 'Invoice'),
    'cancelled' => array('is_payable' => false, 'has_upi' => false, 'settlement_mismatch' => false, 'document_title' => 'Invoice'),
    'collections' => array('is_payable' => false, 'has_upi' => false, 'settlement_mismatch' => false, 'document_title' => 'Invoice'),
    'draft' => array('is_payable' => false, 'has_upi' => false, 'settlement_mismatch' => false, 'document_title' => 'Invoice'),
    'zero-total' => array('is_payable' => false, 'has_upi' => false, 'settlement_mismatch' => false, 'document_title' => 'Invoice', 'total_numeric' => 0.0, 'balance_numeric' => 0.0),
    'euro-format2' => array('is_payable' => true, 'has_upi' => false, 'settlement_mismatch' => false, 'document_title' => 'Invoice', 'total_numeric' => 1234.56, 'balance_numeric' => 1234.56),
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
