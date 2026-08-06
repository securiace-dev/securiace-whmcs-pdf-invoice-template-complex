<?php

if (!defined('WHMCS')) {
    die('This file cannot be accessed directly.');
}

require_once __DIR__ . '/lib/SnapshotService.php';

/** @return array<string, mixed> */
function securiace_pdf_profile_config(): array
{
    return array(
        'name' => 'Securiace PDF Profile Snapshots',
        'description' => 'Immutable issuer snapshots and redacted diagnostics for WHMCS invoice PDFs.',
        'version' => '1.0.0',
        'author' => 'Securiace Technologies',
        'language' => 'english',
    );
}

/** @return array<string, string> */
function securiace_pdf_profile_activate(): array
{
    try {
        SecuriacePdfProfileSnapshotService::ensureSchema();
        return array(
            'status' => 'success',
            'description' => 'Issuer snapshot storage is ready. Copy the shared profile helper to WHMCS includes.',
        );
    } catch (Throwable $exception) {
        return array(
            'status' => 'error',
            'description' => 'Unable to prepare issuer snapshot storage. Review the WHMCS activity and error logs.',
        );
    }
}

/** @return array<string, string> */
function securiace_pdf_profile_deactivate(): array
{
    return array(
        'status' => 'success',
        'description' => 'Module deactivated. Historical issuer snapshots were intentionally retained.',
    );
}

/** @param array<string, mixed> $vars */
function securiace_pdf_profile_upgrade(array $vars): void
{
    unset($vars);
    SecuriacePdfProfileSnapshotService::ensureSchema();
}

/** @param array<string, mixed> $vars */
function securiace_pdf_profile_output(array $vars): void
{
    unset($vars);
    try {
        $diagnostics = SecuriacePdfProfileSnapshotService::diagnostics();
    } catch (Throwable $exception) {
        $diagnostics = array(
            'status' => 'diagnostics-unavailable',
            'action' => 'Review the WHMCS activity and error logs.',
        );
    }
    $encoded = json_encode($diagnostics, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
    if (!is_string($encoded)) {
        $encoded = '{"status":"diagnostics-encoding-failed"}';
    }
    echo '<div class="panel panel-default">'
        . '<div class="panel-heading"><strong>PDF profile health</strong></div>'
        . '<div class="panel-body">'
        . '<p>This view reports presence, validation, source, and conflict codes only. '
        . 'It never displays issuer identifiers, bank numbers, UPI IDs, or client data.</p>'
        . '<pre style="white-space:pre-wrap">'
        . htmlspecialchars($encoded, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8')
        . '</pre></div></div>';
}
