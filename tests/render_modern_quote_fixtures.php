<?php

declare(strict_types=1);

error_reporting(E_ALL & ~E_DEPRECATED & ~E_USER_DEPRECATED);

if ($argc < 3) {
    fwrite(STDERR, "Usage: php tests/render_modern_quote_fixtures.php /path/to/tcpdf.php /output/directory\n");
    exit(64);
}

$tcpdfPath = $argv[1];
$outputDirectory = $argv[2];
$templatePath = realpath(__DIR__ . '/../quotepdf-modern.tpl');
if ($templatePath === false || !is_readable($templatePath)) {
    throw new RuntimeException('Modern quote template is not readable.');
}
if (!is_readable($tcpdfPath)) {
    throw new RuntimeException('TCPDF is not readable: ' . $tcpdfPath);
}
if (!is_dir($outputDirectory) && !mkdir($outputDirectory, 0775, true) && !is_dir($outputDirectory)) {
    throw new RuntimeException('Unable to create quote fixture output directory.');
}
if (!extension_loaded('gd')) {
    throw new RuntimeException('The GD extension is required to create fixture artwork.');
}

require_once $tcpdfPath;

$fixtureRoot = sys_get_temp_dir() . '/securiace-modern-quote-' . bin2hex(random_bytes(8));
$fixtureAssetDirectory = $fixtureRoot . '/assets/img';
if (!mkdir($fixtureAssetDirectory, 0775, true) && !is_dir($fixtureAssetDirectory)) {
    throw new RuntimeException('Unable to create quote fixture assets.');
}
define('ROOTDIR', $fixtureRoot);

if (!function_exists('getTodaysDate')) {
    function getTodaysDate($includeTime = 0)
    {
        return $includeTime ? '5 Aug 2026, 19:10' : '5 Aug 2026';
    }
}
if (!function_exists('formatCurrency')) {
    function formatCurrency($amount)
    {
        $currency = isset($GLOBALS['currency']) && is_array($GLOBALS['currency'])
            ? $GLOBALS['currency']
            : array();
        $prefix = isset($currency['prefix']) ? trim((string) $currency['prefix']) : '';
        $suffix = isset($currency['suffix']) ? trim((string) $currency['suffix']) : '';
        return ($prefix !== '' ? $prefix . ' ' : '')
            . number_format((float) $amount, 2, '.', ',')
            . ($suffix !== '' ? ' ' . $suffix : '');
    }
}

$logo = imagecreatetruecolor(620, 150);
if ($logo === false) {
    throw new RuntimeException('Unable to allocate quote logo fixture.');
}
$paper = imagecolorallocate($logo, 255, 254, 253);
$brand = imagecolorallocate($logo, 79, 11, 112);
$ink = imagecolorallocate($logo, 32, 28, 36);
imagefilledrectangle($logo, 0, 0, 619, 149, $paper);
imagefilledellipse($logo, 72, 75, 78, 78, $brand);
imagestring($logo, 5, 130, 40, 'SECURIACE', $ink);
imagestring($logo, 3, 132, 80, 'TECHNOLOGIES', $brand);
if (!imagepng($logo, $fixtureAssetDirectory . '/logo.png')) {
    throw new RuntimeException('Unable to write quote logo fixture.');
}
if (PHP_VERSION_ID < 80500) {
    imagedestroy($logo);
}

/** @param mixed $actual @param mixed $expected */
function assertQuoteFixtureValue(string $fixture, string $field, $actual, $expected): void
{
    if ($actual !== $expected) {
        throw new RuntimeException(
            $fixture . ' expected ' . $field . '=' . var_export($expected, true)
            . ', got ' . var_export($actual, true)
        );
    }
}

/** @param array<string, mixed> $overrides @return array<string, mixed> */
function quoteFixture(array $overrides = array()): array
{
    $base = array(
        '_paper' => 'A4',
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
            'tax_code' => '27ABCDE1234F1Z5',
        ),
        'quotenumber' => 'Q-2026-00218',
        'subject' => 'Managed cloud platform and security operations',
        'stage' => 'Draft',
        'datecreated' => '5 Aug 2026',
        'validuntil' => '19 Aug 2026',
        'userid' => 2048,
        'clientsdetails' => array(
            'firstname' => 'Asha',
            'lastname' => 'Mehta',
            'companyname' => 'Northstar Digital Private Limited',
            'email' => 'accounts@example.invalid',
            'address1' => '42 Product Road',
            'address2' => 'Operations Wing',
            'city' => 'Bengaluru',
            'state' => 'Karnataka',
            'postcode' => '560001',
            'country' => 'India',
            'phonenumber' => '+91 90000 00000',
        ),
        'proposal' => '<h2>Outcome</h2><p>A managed environment with <strong>security operations</strong>, predictable support, and a documented migration.</p><ul><li>Cloud platform setup</li><li>Monthly performance review</li><li>Security hardening</li></ul>',
        'notes' => 'Pricing excludes third-party licences unless explicitly listed.\nWork begins after written acceptance.',
        'taxlevel1' => array('name' => 'GST', 'rate' => 18),
        'taxlevel2' => array('name' => '', 'rate' => 0),
        'subtotal' => '₹ 32,400.00 INR',
        'tax1' => '₹ 5,832.00 INR',
        'tax2' => '₹ 0.00 INR',
        'total' => '₹ 38,232.00 INR',
        'lineitems' => array(
            array(
                'id' => 1,
                'description' => 'Growth Managed infrastructure<br>3 Founder hours/month and monthly security audit',
                'qty' => 1,
                'unitprice' => 24300,
                'discount' => 0,
                'taxable' => 1,
                'total' => '₹ 24,300.00 INR',
            ),
            array(
                'id' => 2,
                'description' => 'Cloud migration and validation<br>One-time onboarding engagement',
                'qty' => 12,
                'unitprice' => 750,
                'discount' => 10,
                'taxable' => 1,
                'total' => '₹ 8,100.00 INR',
            ),
        ),
        'pdfFont' => 'dejavusans',
        'securiaceQuoteTemplateConfig' => array(
            'company_email' => 'fallback@example.invalid',
            'company_phone' => '+91 30000 00000',
            'company_pan' => 'FGHIJ5678K',
            'company_msme' => 'UDYAM-MH-99-9999999',
            'jurisdiction' => 'Example Jurisdiction',
        ),
        '_currency' => array('code' => 'INR', 'prefix' => '₹', 'suffix' => 'INR', 'format' => 1),
    );
    $fixture = array_replace_recursive($base, $overrides);
    // Numeric quote-item arrays are fixtures, not mergeable configuration.
    if (array_key_exists('lineitems', $overrides)) {
        $fixture['lineitems'] = $overrides['lineitems'];
    }
    return $fixture;
}

/** @param array<string, mixed> $fixture @return array<string, mixed> */
function renderQuoteFixture(string $templatePath, string $outputDirectory, string $name, array $fixture): array
{
    $paper = isset($fixture['_paper']) ? $fixture['_paper'] : 'A4';
    $currency = isset($fixture['_currency']) ? $fixture['_currency'] : array();
    unset($fixture['_paper'], $fixture['_currency']);
    $GLOBALS['currency'] = $currency;

    $pdf = new TCPDF('P', 'mm', $paper, true, 'UTF-8', false);
    $pdf->setPrintHeader(false);
    $pdf->setPrintFooter(false);
    $pdf->SetCreator('Securiace quote fixture renderer');
    $pdf->SetAuthor('Securiace Technologies');
    $pdf->SetTitle($name);
    $pdf->AddPage();
    extract($fixture, EXTR_SKIP);

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
    $pdf->Output($outputPath, 'F');
    if (!is_file($outputPath) || filesize($outputPath) < 1000) {
        throw new RuntimeException($name . ' quote PDF is missing or unexpectedly small.');
    }
    return array(
        'pages' => $securiaceQuotePageCount,
        'number' => $securiaceQuoteNumber,
        'currency_code' => $securiaceQuoteCurrencyCode,
        'subject' => $securiaceQuoteSubject,
        'issued_label' => $securiaceQuoteIssuedLabel,
        'issued_display' => $securiaceQuoteIssuedDisplay,
        'valid_until_display' => $securiaceQuoteValidUntilDisplay,
        'date_warnings' => $securiaceQuoteDateWarnings,
        'has_valid_until' => $securiaceQuoteHasValidUntil,
        'summary_height' => $summaryHeight,
        'summary_full_width' => $summaryUsesFullWidth,
        'shows_discount' => $securiaceQuoteShowDiscount,
        'detail_continuations' => $securiaceQuoteDetailContinuationCount,
        'acceptance_height' => $acceptanceHeight,
        'totals_height' => $totalsHeight,
        'sanitized_proposal' => $securiaceQuoteProposalHtml,
        'proposal_plain' => $securiaceQuoteProposalPlain,
        'first_description' => isset($securiaceQuoteNormalizedDescriptions[0])
            ? $securiaceQuoteNormalizedDescriptions[0]
            : null,
        'item_count' => count($preparedQuoteItems),
        'rendered_notes' => $securiaceQuoteRenderedNotes,
        'issuer_name' => $securiaceQuoteCompanyName,
        'issuer_lines' => $securiaceQuoteCompanyLines,
        'issuer_registrations' => $securiaceQuoteSellerRegistrations,
        'issuer_sources' => $securiaceQuoteIssuerDiagnostics['sources'],
        'payment_details_rendered' => $securiaceQuotePaymentDetailsRendered,
        'stamped_pages' => $securiaceQuoteStampedPages,
        'output' => $outputPath,
    );
}

$longItems = array();
for ($index = 1; $index <= 42; ++$index) {
    $longItems[] = array(
        'id' => $index,
        'description' => 'Managed service workstream ' . $index . '<br>Implementation, validation, documentation, and handover for the selected environment.',
        'qty' => ($index % 4) + 1,
        'unitprice' => 1200 + ($index * 25),
        'discount' => $index % 3 === 0 ? 5 : 0,
        'taxable' => 1,
        'total' => '₹ ' . number_format(2500 + ($index * 100), 2) . ' INR',
    );
}
$longDetail = str_repeat(
    'Stakeholder workshop, infrastructure inventory, architecture review, security observations, '
        . 'risk prioritisation, implementation planning, validation criteria, and documented handover. ',
    90
);
$veryLongSubject = str_repeat(
    'Multi-site infrastructure, software architecture, security operations, and implementation governance ',
    5
);

$fixtures = array(
    'standard' => quoteFixture(),
    'guest' => quoteFixture(array(
        'quotenumber' => 'Q-2026-00219',
        'userid' => 0,
        'clientsdetails' => array(
            'firstname' => 'Rohan',
            'lastname' => 'Sen',
            'companyname' => '',
            'email' => 'rohan@example.invalid',
            'address1' => '11 Lake View',
            'address2' => '',
            'city' => 'Kolkata',
            'state' => 'West Bengal',
            'postcode' => '700001',
            'country' => 'India',
            'phonenumber' => '',
        ),
        'taxlevel1' => array('name' => '', 'rate' => 0),
        'subtotal' => '₹ 24,300.00 INR',
        'tax1' => '₹ 0.00 INR',
        'total' => '₹ 24,300.00 INR',
        'lineitems' => array(array(
            'id' => 1,
            'description' => 'Growth Managed service',
            'qty' => 1,
            'unitprice' => 24300,
            'discount' => 0,
            'taxable' => 0,
            'total' => '₹ 24,300.00 INR',
        )),
    )),
    'sanitized-rich-content' => quoteFixture(array(
        'quotenumber' => 'Q-2026-00220',
        'proposal' => '<script>alert(1)</script><style>body{display:none}</style><h2 onclick="bad()">Secure outcome</h2><p class="lead">Keep <strong data-x="1">approved emphasis</strong> and <a href="https://example.invalid">link text</a>.</p><img src="https://example.invalid/tracker">',
    )),
    'entity-description' => quoteFixture(array(
        'quotenumber' => 'Q-2026-00221',
        'lineitems' => array(array(
            'id' => 1,
            'description' => 'Security R&amp;D &lt;managed&gt;<br>Discovery and implementation',
            'qty' => 2,
            'unitprice' => 1500,
            'discount' => 5,
            'taxable' => 1,
            'total' => '₹ 2,850.00 INR',
        )),
    )),
    'screenshot-regression' => quoteFixture(array(
        'quotenumber' => '182',
        'subject' => 'Onsite Discovery & Blueprint Visit for IT Infrastructure, Software Architecture, and Security Operations',
        'datecreated' => '00/00/0000',
        'validuntil' => '05/09/2026',
        'proposal' => '',
        'lineitems' => array(array(
            'id' => 1,
            'description' => 'Onsite Discovery & Blueprint Visit - Review of current IT/software setup<br>'
                . 'Deliverables: Codebase health and feasibility report; system requirements specification; AI and automation upgrade roadmap; fixed-cost stabilisation and rollout proposal.\n\n'
                . 'Payment term: 100% advance is payable after written acceptance and before visit scheduling.\n'
                . 'Commercial adjustment: If a separately scoped implementation engagement is awarded, this discovery fee may be credited only under the accepted implementation terms.\n'
                . 'Tax: GST is not charged because the supplier is not registered under GST as of the quote date.',
            'qty' => 1,
            'unitprice' => 65000,
            'discount' => 0,
            'taxable' => 0,
            'total' => '₹ 65,000.00 INR',
        )),
        'subtotal' => '₹ 65,000.00 INR',
        'taxlevel1' => array('name' => '', 'rate' => 0),
        'tax1' => '₹ 0.00 INR',
        'total' => '₹ 65,000.00 INR',
    )),
    'invalid-validity-order' => quoteFixture(array(
        'quotenumber' => 'Q-2026-00224',
        'datecreated' => '10/09/2026',
        'validuntil' => '05/09/2026',
    )),
    'mdy-dates' => quoteFixture(array(
        'quotenumber' => 'Q-2026-00225',
        'datecreated' => '08/06/2026',
        'validuntil' => '09/05/2026',
        'securiaceQuoteTemplateConfig' => array(
            'date_order' => 'MDY',
        ),
    )),
    'missing-validity' => quoteFixture(array(
        'quotenumber' => 'Q-2026-00227',
        'validuntil' => '',
    )),
    'very-long-subject' => quoteFixture(array(
        'quotenumber' => 'Q-2026-00228',
        'subject' => trim($veryLongSubject),
        'proposal' => '',
    )),
    'long-detail-a4' => quoteFixture(array(
        'quotenumber' => 'Q-2026-00226',
        'subject' => 'Long-form discovery workstream with multi-page item details',
        'proposal' => '',
        'lineitems' => array(array(
            'id' => 1,
            'description' => 'Discovery and implementation blueprint<br>' . $longDetail,
            'qty' => 1,
            'unitprice' => 65000,
            'discount' => 0,
            'taxable' => 0,
            'total' => '₹ 65,000.00 INR',
        )),
        'subtotal' => '₹ 65,000.00 INR',
        'taxlevel1' => array('name' => '', 'rate' => 0),
        'tax1' => '₹ 0.00 INR',
        'total' => '₹ 65,000.00 INR',
    )),
    'long-letter' => quoteFixture(array(
        '_paper' => 'LETTER',
        'quotenumber' => 'Q-2026-00222',
        'subject' => 'Multi-phase managed infrastructure transformation programme',
        'proposal' => '<h2>Programme overview</h2><p>' . str_repeat('This proposal coordinates infrastructure, security, migration, observability, acceptance, and operational handover. ', 24) . '</p>',
        'lineitems' => $longItems,
        'subtotal' => '₹ 190,000.00 INR',
        'tax1' => '₹ 34,200.00 INR',
        'total' => '₹ 224,200.00 INR',
    )),
);

$expectations = array(
    'standard' => array(
        'number' => 'Q-2026-00218',
        'currency_code' => 'INR',
        'item_count' => 2,
        'shows_discount' => true,
        'rendered_notes' => false,
        'issuer_name' => 'Example Technologies',
        'issuer_lines' => array(
            '88 Secure Cloud Avenue',
            'Pune, Maharashtra 411001',
            'India',
            'Helpdesk · helpdesk@example.invalid',
            'Mobile · +91 20000 00000',
        ),
        'issuer_registrations' => array(
            'PAN · ABCDE1234F',
            'MSME · UDYAM-MH-00-0000000',
            'GSTIN · 27ABCDE1234F1Z5',
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
        'payment_details_rendered' => false,
    ),
    'guest' => array('number' => 'Q-2026-00219', 'currency_code' => 'INR', 'item_count' => 1, 'shows_discount' => false),
    'sanitized-rich-content' => array('number' => 'Q-2026-00220', 'currency_code' => 'INR', 'item_count' => 2),
    'entity-description' => array('number' => 'Q-2026-00221', 'currency_code' => 'INR', 'item_count' => 1, 'first_description' => "Security R&D <managed>\nDiscovery and implementation"),
    'screenshot-regression' => array(
        'number' => '182',
        'currency_code' => 'INR',
        'item_count' => 1,
        'subject' => 'Onsite Discovery & Blueprint Visit for IT Infrastructure, Software Architecture, and Security Operations',
        'issued_label' => 'Generated',
        'issued_display' => '5 Aug 2026',
        'valid_until_display' => '5 Sep 2026',
        'date_warnings' => array('issue-date-invalid-or-missing'),
        'has_valid_until' => true,
        'shows_discount' => false,
    ),
    'invalid-validity-order' => array(
        'number' => 'Q-2026-00224',
        'issued_label' => 'Issued',
        'issued_display' => '10 Sep 2026',
        'valid_until_display' => 'Review required',
        'date_warnings' => array('valid-until-precedes-issue-date'),
        'has_valid_until' => false,
    ),
    'mdy-dates' => array(
        'number' => 'Q-2026-00225',
        'issued_label' => 'Issued',
        'issued_display' => '6 Aug 2026',
        'valid_until_display' => '5 Sep 2026',
        'date_warnings' => array(),
        'has_valid_until' => true,
    ),
    'missing-validity' => array(
        'number' => 'Q-2026-00227',
        'valid_until_display' => 'No expiry stated',
        'date_warnings' => array('valid-until-invalid-or-missing'),
        'has_valid_until' => false,
    ),
    'very-long-subject' => array(
        'number' => 'Q-2026-00228',
        'subject' => trim($veryLongSubject),
        'summary_full_width' => true,
    ),
    'long-detail-a4' => array(
        'number' => 'Q-2026-00226',
        'item_count' => 1,
        'shows_discount' => false,
    ),
    'long-letter' => array('number' => 'Q-2026-00222', 'currency_code' => 'INR', 'item_count' => 42, 'shows_discount' => true),
);

foreach ($fixtures as $name => $fixture) {
    $result = renderQuoteFixture($templatePath, $outputDirectory, $name, $fixture);
    foreach ($expectations[$name] as $field => $expected) {
        assertQuoteFixtureValue($name, $field, $result[$field], $expected);
    }
    if ($result['stamped_pages'] !== range(1, $result['pages'])) {
        throw new RuntimeException($name . ' did not stamp every page in its own PDF.');
    }
    if ($name === 'long-letter' && $result['pages'] < 2) {
        throw new RuntimeException('Long quote fixture did not exercise multi-page rendering.');
    }
    if ($name === 'screenshot-regression') {
        if ($result['summary_height'] <= 16 || $result['summary_full_width']) {
            throw new RuntimeException('Screenshot subject did not expand inside its metadata card.');
        }
        if ($result['totals_height'] !== $result['acceptance_height']) {
            throw new RuntimeException('Acceptance and totals cards did not share their measured height.');
        }
    }
    if ($name === 'long-detail-a4') {
        if ($result['pages'] < 2 || $result['detail_continuations'] < 1) {
            throw new RuntimeException('Long quote-item detail did not exercise continuation rendering.');
        }
    }
    if ($name === 'very-long-subject' && $result['summary_height'] <= 16) {
        throw new RuntimeException('Very long quote subject did not expand its full-width summary.');
    }
    if ($name === 'sanitized-rich-content') {
        foreach (array('script', 'style', 'onclick', '<img', '<a ', 'data-x') as $forbidden) {
            if (stripos($result['sanitized_proposal'], $forbidden) !== false) {
                throw new RuntimeException('Sanitized proposal retained forbidden content: ' . $forbidden);
            }
        }
        foreach (array('<h2>', '<p>', '<strong>', 'link text') as $required) {
            if (strpos($result['sanitized_proposal'], $required) === false) {
                throw new RuntimeException('Sanitized proposal lost allowed content: ' . $required);
            }
        }
    }
    fwrite(
        STDOUT,
        str_pad($name, 25) . ' ' . $result['pages'] . ' page(s)  ' . basename($result['output']) . "\n"
    );
}

fwrite(STDOUT, "Modern quote TCPDF fixtures passed.\n");
