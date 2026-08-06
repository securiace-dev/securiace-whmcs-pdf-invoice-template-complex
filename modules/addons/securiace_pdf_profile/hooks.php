<?php

if (!defined('WHMCS')) {
    die('This file cannot be accessed directly.');
}

require_once __DIR__ . '/lib/SnapshotService.php';

$securiacePdfCaptureSnapshot = static function (int $invoiceId, string $sourceEvent): void {
    try {
        $result = SecuriacePdfProfileSnapshotService::capture($invoiceId, $sourceEvent);
        if (isset($result['status']) && $result['status'] === 'captured' && function_exists('logActivity')) {
            logActivity('PDF issuer snapshot captured for invoice ID: ' . $invoiceId);
        }
    } catch (Throwable $exception) {
        if (function_exists('logActivity')) {
            logActivity('PDF issuer snapshot failed for invoice ID: ' . $invoiceId . '. Review module diagnostics.');
        }
    }
};

add_hook('InvoiceCreation', 1, static function (array $vars) use ($securiacePdfCaptureSnapshot): void {
    $invoiceId = isset($vars['invoiceid']) ? (int) $vars['invoiceid'] : 0;
    if ($invoiceId > 0 && SecuriacePdfProfileSnapshotService::shouldCaptureCreatedInvoice($invoiceId)) {
        $securiacePdfCaptureSnapshot($invoiceId, 'InvoiceCreation');
    }
});

add_hook('InvoicePaidPreEmail', 1, static function (array $vars) use ($securiacePdfCaptureSnapshot): void {
    $invoiceId = isset($vars['invoiceid']) ? (int) $vars['invoiceid'] : 0;
    if ($invoiceId > 0) {
        $securiacePdfCaptureSnapshot($invoiceId, 'InvoicePaidPreEmail');
    }
});
