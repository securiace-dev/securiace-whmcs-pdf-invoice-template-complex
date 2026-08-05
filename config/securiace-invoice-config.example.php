<?php

/**
 * Copy this file to:
 *   WHMCS_ROOT/includes/securiace-invoice-config.php
 *
 * Keep the deployed file outside version control. The public template contains
 * no bank account details, signature material, or verification secret.
 */
return array(
    'company_email' => 'billing@example.com',
    'company_phone' => '+91 00000 00000',
    'company_pan' => 'ABCDE1234F',
    'company_msme' => 'UDYAM-XX-00-0000000',
    'bank' => array(
        'account_name' => 'Example Technologies',
        'account_number' => '0000000000000000',
        'ifsc' => 'DEMO0000001',
        'account_type' => 'Current',
        'bank_name' => 'Example Bank',
    ),
    'upi_id' => 'billing@example',
    'verification_secret' => getenv('SECURIACE_INVOICE_VERIFY_SECRET') ?: '',
    // Ambiguous numeric service periods: DMY for India/UK, MDY for US.
    'date_order' => 'DMY',
    'show_it_act_label' => true,
    'jurisdiction' => 'Pune, Maharashtra',
    'overdue_interest' => '18% p.a.',
    'tds_note' => 'If applicable, deduct TDS under Section 194J and provide Form 16A.',
    'acceptance_note' => 'Acceptance confirms the scope and commercial terms shown in this quote.',
);
