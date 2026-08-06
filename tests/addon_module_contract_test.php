<?php

declare(strict_types=1);

$module = file_get_contents(__DIR__ . '/../modules/addons/securiace_pdf_profile/securiace_pdf_profile.php');
$hooks = file_get_contents(__DIR__ . '/../modules/addons/securiace_pdf_profile/hooks.php');
$service = file_get_contents(__DIR__ . '/../modules/addons/securiace_pdf_profile/lib/SnapshotService.php');
if ($module === false || $hooks === false || $service === false) {
    throw new RuntimeException('Unable to read PDF profile addon sources.');
}

$required = array(
    'securiace_pdf_profile_config',
    'securiace_pdf_profile_activate',
    'securiace_pdf_profile_deactivate',
    'securiace_pdf_profile_upgrade',
    'securiace_pdf_profile_output',
    "add_hook('InvoiceCreation'",
    "add_hook('InvoicePaidPreEmail'",
    'shouldCaptureCreatedInvoice',
    'isProformaInvoice',
    "public const TABLE = 'mod_securiace_pdf_issuer_snapshots'",
    "'identity' => \$profile['identity']",
    "'registrations' => \$registrations",
    "'checksum' => hash('sha256', \$payloadJson)",
    "'snapshot_count'",
    "'valid_bank_account_count'",
);
$combined = $module . "\n" . $hooks . "\n" . $service;
foreach ($required as $contract) {
    if (strpos($combined, $contract) === false) {
        throw new RuntimeException('PDF profile addon contract is missing: ' . $contract);
    }
}

$forbidden = array(
    'dropIfExists',
    "'payment' => \$profile['payment']",
    'getMessage()',
    'print_r(',
    'var_dump(',
);
foreach ($forbidden as $contract) {
    if (strpos($combined, $contract) !== false) {
        throw new RuntimeException('PDF profile addon contains a forbidden contract: ' . $contract);
    }
}

fwrite(STDOUT, "PDF profile addon contract tests passed.\n");
