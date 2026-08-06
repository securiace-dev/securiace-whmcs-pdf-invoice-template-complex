<?php

declare(strict_types=1);

$validator = include __DIR__ . '/../securiace-pdf-snapshot.php';
if (!($validator instanceof Closure)) {
    throw new RuntimeException('Snapshot validator did not return a closure.');
}

/** @param array<string, mixed> $payload @return array<string, string> */
function snapshotTestRow(array $payload): array
{
    $json = json_encode($payload, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
    if (!is_string($json)) {
        throw new RuntimeException('Unable to encode snapshot test payload.');
    }
    return array('payload' => $json, 'checksum' => hash('sha256', $json));
}

/** @param mixed $actual @param mixed $expected */
function assertSnapshotValue(string $field, $actual, $expected): void
{
    if ($actual !== $expected) {
        throw new RuntimeException(
            $field . ' expected ' . var_export($expected, true) . ', got ' . var_export($actual, true)
        );
    }
}

$payload = array(
    'schema_version' => 1,
    'issuer' => array(
        'identity' => array(
            'business_name' => '<b>Historical Example Technologies</b>',
            'address_lines' => array('10 Archive Road', 'Pune, Maharashtra'),
            'support_email' => 'archive@example.invalid',
            'mobile' => '+91 40000 00000',
            'website' => 'https://archive.example.invalid',
        ),
        'registrations' => array(
            'pan' => array('value' => 'ABCDE1234F'),
            'udyam' => array('value' => 'UDYAM-MH-00-0000000'),
        ),
    ),
    'document' => array(
        'title' => 'Invoice',
        'gst_active' => false,
        'final_invoice_number' => 'ST/2073',
        'issue_date' => '2026-08-05',
    ),
);

$valid = $validator(snapshotTestRow($payload));
assertSnapshotValue('valid row', $valid['valid'], true);
assertSnapshotValue(
    'sanitized historical name',
    $valid['snapshot']['issuer']['identity']['business_name'],
    'Historical Example Technologies'
);
assertSnapshotValue('payment key absent', isset($valid['snapshot']['issuer']['payment']), false);
assertSnapshotValue('historical title', $valid['snapshot']['document']['title'], 'Invoice');

$tampered = snapshotTestRow($payload);
$tampered['payload'] .= ' ';
$tamperedResult = $validator($tampered);
assertSnapshotValue('tampered row valid', $tamperedResult['valid'], false);
assertSnapshotValue('tampered warning', $tamperedResult['warning'], 'snapshot-checksum-mismatch');

$paymentPayload = $payload;
$paymentPayload['payment'] = array('upi' => 'must-not-be-stored');
$paymentResult = $validator(snapshotTestRow($paymentPayload));
assertSnapshotValue('payment row valid', $paymentResult['valid'], false);
assertSnapshotValue('payment warning', $paymentResult['warning'], 'snapshot-payment-data-forbidden');

$invalidTitlePayload = $payload;
$invalidTitlePayload['document']['title'] = 'Receipt<script>';
$invalidTitleResult = $validator(snapshotTestRow($invalidTitlePayload));
assertSnapshotValue('invalid title row valid', $invalidTitleResult['valid'], false);
assertSnapshotValue('invalid title warning', $invalidTitleResult['warning'], 'snapshot-document-title-invalid');

fwrite(STDOUT, "PDF snapshot validation tests passed.\n");
