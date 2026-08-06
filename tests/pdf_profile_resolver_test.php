<?php

declare(strict_types=1);

$resolver = require __DIR__ . '/../securiace-pdf-profile.php';
if (!$resolver instanceof Closure) {
    throw new RuntimeException('PDF profile helper must return a resolver closure.');
}

/** @param mixed $actual @param mixed $expected */
function assertProfileValue(string $case, string $field, $actual, $expected): void
{
    if ($actual !== $expected) {
        throw new RuntimeException(
            $case . ' ' . $field . ' mismatch: expected '
            . var_export($expected, true) . ', got ' . var_export($actual, true)
        );
    }
}

$fallback = array(
    'company_email' => 'fallback@example.invalid',
    'company_phone' => '+91 70000 00000',
    'company_pan' => 'ABCDE1234F',
    'company_msme' => 'UDYAM-MH-00-0000000',
    'bank_currencies' => array('INR'),
    'bank' => array(
        'account_name' => 'Fallback Systems',
        'account_number' => '0000000000000000',
        'ifsc' => 'DEMO0000001',
        'bank_name' => 'Fallback Bank',
        'branch' => 'Fallback Branch',
    ),
    'upi_id' => 'fallback@example',
);

$sectioned = $resolver(array(
    'company_name' => 'Example Systems',
    'company_email' => 'helpdesk@example.invalid',
    'company_url' => 'https://portal.example.invalid',
    'tax_code' => '',
    'pay_to' => array(
        'UPI: accounts@example',
        '[Bank Account: INR]',
        'Account Name: EXAMPLE SYSTEMS',
        'Account Number: 123456789012',
        'IFSC: DEMO0000001',
        'Bank Branch: Central',
        'Bank Name: Example Bank',
        '',
        'Company Address: 42 Example Road',
        'Pune, Maharashtra 411001',
        'Mobile: +91 80000 00000',
        'PAN: ABCDE1234F',
        'MSME: UDYAM-MH-00-0000000',
    ),
    'fallback' => $fallback,
));
assertProfileValue('sectioned', 'business name', $sectioned['identity']['business_name'], 'Example Systems');
assertProfileValue('sectioned', 'address', $sectioned['identity']['address_lines'], array(
    '42 Example Road',
    'Pune, Maharashtra 411001',
));
assertProfileValue('sectioned', 'support email', $sectioned['identity']['support_email'], 'helpdesk@example.invalid');
assertProfileValue('sectioned', 'mobile', $sectioned['identity']['mobile'], '+91 80000 00000');
assertProfileValue('sectioned', 'PAN source', $sectioned['registrations']['pan']['source'], 'pay_to.pan');
assertProfileValue('sectioned', 'MSME valid', $sectioned['registrations']['udyam']['valid'], true);
assertProfileValue('sectioned', 'UPI valid', $sectioned['payment']['upi']['valid'], true);
assertProfileValue('sectioned', 'bank source', $sectioned['payment']['bank_accounts'][0]['source'], 'pay_to.bank');
assertProfileValue('sectioned', 'bank branch', $sectioned['payment']['bank_accounts'][0]['branch'], 'Central');
assertProfileValue('sectioned', 'bank currency', $sectioned['payment']['bank_accounts'][0]['currencies'], array('INR'));

$legacy = $resolver(array(
    'company_name' => 'Legacy Services',
    'company_url' => 'https://legacy.example.invalid',
    'pay_to' => "Legacy Services\r\n88 Old Road\r\nIndia\r\nHelpdesk: billing@example.invalid\r\nPhone: +91 81000 00000",
    'fallback' => $fallback,
));
assertProfileValue('legacy', 'deduplicated address', $legacy['identity']['address_lines'], array('88 Old Road', 'India'));
assertProfileValue('legacy', 'helpdesk source', $legacy['diagnostics']['sources']['identity.support_email'], 'pay_to.support_email');
assertProfileValue('legacy', 'fallback PAN', $legacy['registrations']['pan']['source'], 'protected.company_pan');
assertProfileValue('legacy', 'fallback bank', $legacy['diagnostics']['sources']['payment.bank_accounts'], 'protected.bank');

$incompleteBank = $resolver(array(
    'company_name' => 'Incomplete Bank Example',
    'pay_to' => array(
        '[Bank Account]',
        'Account Name: Incomplete Bank Example',
        'Account Number: 123456789012',
    ),
    'fallback' => $fallback,
));
assertProfileValue('incomplete', 'atomic fallback source', $incompleteBank['diagnostics']['sources']['payment.bank_accounts'], 'protected.bank');
assertProfileValue('incomplete', 'atomic fallback account', $incompleteBank['payment']['bank_accounts'][0]['account_name'], 'Fallback Systems');

$conflictedBank = $resolver(array(
    'company_name' => 'Conflict Example',
    'pay_to' => array(
        '[Bank Account]',
        'Account Name: Conflict Example',
        'Account Number: 111111111111',
        'Account Number: 222222222222',
        'IFSC: DEMO0000001',
        'Bank Name: Example Bank',
    ),
    'fallback' => $fallback,
));
assertProfileValue('conflict', 'bank disabled', $conflictedBank['payment']['bank_accounts'], array());
assertProfileValue('conflict', 'bank source', $conflictedBank['diagnostics']['sources']['payment.bank_accounts'], 'disabled-conflict');
assertProfileValue('conflict', 'safe conflict code', in_array(
    'pay-to-bank-0-account_number-conflict',
    $conflictedBank['diagnostics']['conflicts'],
    true
), true);

$conflictedUpi = $resolver(array(
    'company_name' => 'UPI Conflict Example',
    'pay_to' => array('UPI: first@example', 'VPA: second@example'),
    'fallback' => $fallback,
));
assertProfileValue('upi conflict', 'disabled', $conflictedUpi['payment']['upi']['valid'], false);
assertProfileValue('upi conflict', 'value withheld', $conflictedUpi['payment']['upi']['id'], '');

$multipleBanks = $resolver(array(
    'company_name' => 'Multiple Bank Example',
    'pay_to' => array(
        '[Bank Account: INR]',
        'Account Name: Multiple Bank Example',
        'Account Number: 123456789012',
        'IFSC: DEMO0000001',
        'Bank Name: Example Bank',
        '[Bank Account: USD]',
        'Beneficiary: Multiple Bank Example',
        'Account No: USD123456789',
        'SWIFT: DEMOUS33',
        'Bank: Example International Bank',
    ),
));
assertProfileValue('multiple bank', 'count', count($multipleBanks['payment']['bank_accounts']), 2);
assertProfileValue('multiple bank', 'USD currency', $multipleBanks['payment']['bank_accounts'][1]['currencies'], array('USD'));

$sanitized = $resolver(array(
    'company_name' => '',
    'pay_to' => array(
        'Company Name: <strong>Markup Example</strong>',
        "Company Address: 7 Safe Street\x00",
        'Mystery Token: must-not-appear-in-diagnostics',
        'PAN: malformed',
        'UPI: not a valid vpa',
    ),
));
assertProfileValue('sanitized', 'name', $sanitized['identity']['business_name'], 'Markup Example');
assertProfileValue('sanitized', 'address', $sanitized['identity']['address_lines'], array('7 Safe Street'));
assertProfileValue('sanitized', 'unknown label only', $sanitized['diagnostics']['unknown_labels'], array('mystery token'));
assertProfileValue('sanitized', 'invalid PAN advisory', $sanitized['registrations']['pan']['valid'], false);
assertProfileValue('sanitized', 'invalid UPI', $sanitized['payment']['upi']['valid'], false);

$empty = $resolver(array());
assertProfileValue('empty', 'neutral issuer', $empty['identity']['business_name'], 'Issuer');
assertProfileValue('empty', 'no address', $empty['identity']['address_lines'], array());
assertProfileValue('empty', 'no payment', $empty['payment']['bank_accounts'], array());

fwrite(STDOUT, "PDF profile resolver tests passed.\n");
