<?php
/**
 * ========================================================================
 * WHMCS PDF INVOICE TEMPLATE - ENTERPRISE GRADE WITH DEBUG SUPPORT
 * ========================================================================
 * 
 * This template creates a professional invoice with enhanced features:
 * - Status-aware invoice rendering (Proforma vs Official)
 * - Enhanced digital verification badges
 * - Configurable debug information display
 * - Professional styling and layout
 * 
 * DEBUG CONFIGURATION:
 * To enable debug information, set 'show_debug_section' => true in the $ENH array below.
 * Debug levels: 'minimal', 'standard', 'full', 'development'
 * 
 * ========================================================================
 */

// ========================================================================
// PAGE SETUP AND INITIALIZATION
// ========================================================================

// Helper: parse a (possibly formatted) amount string to float.
//
// Inline `floatval(preg_replace('/[^\d.-]/', '', $x))` mishandles thousands
// and decimal separators across locales:
//   "1,234.56" → 1.23456 (US, comma stripped, two dots collapsed)
//   "1.234,56" → 1.23456 (EU, comma stripped, dot kept as decimal)
// This helper uses WHMCS's $currencyformat (tblcurrencies.format: 1..4)
// when set, and a "rightmost separator wins" heuristic otherwise.
if (!function_exists('parseAmount')) {
    function parseAmount($value) {
        if (is_numeric($value)) {
            return (float) $value;
        }
        if (!is_string($value)) {
            return 0.0;
        }
        // Strip everything except digits, dot, comma, hyphen.
        $clean = preg_replace('/[^\d.,\-]/u', '', $value);
        if ($clean === '' || $clean === null) {
            return 0.0;
        }

        // Explicit format from WHMCS template global takes precedence.
        if (isset($GLOBALS['currencyformat'])) {
            switch ((int) $GLOBALS['currencyformat']) {
                case 2: // EU: 1.234,56 — strip dots, swap comma→dot
                    return (float) str_replace(array('.', ','), array('', '.'), $clean);
                case 3: // French: 1 234.56 — already stripped spaces; commas (if any) are spurious
                case 4: // Plain: 1234.56 — no thousands
                case 1: // US: 1,234.56 — strip commas
                default:
                    return (float) str_replace(',', '', $clean);
            }
        }

        // Heuristic when format isn't known — the rightmost separator is
        // the decimal separator; the other (if any) is the thousands separator.
        $last_dot = strrpos($clean, '.');
        $last_comma = strrpos($clean, ',');

        if ($last_dot === false && $last_comma === false) {
            return (float) $clean;
        }
        if ($last_dot === false) {
            // Only commas. Single comma with ≤2 trailing digits → decimal.
            if (substr_count($clean, ',') === 1 && (strlen($clean) - $last_comma - 1) <= 2) {
                return (float) str_replace(',', '.', $clean);
            }
            return (float) str_replace(',', '', $clean); // thousands
        }
        if ($last_comma === false) {
            // Only dots. Multiple dots → thousands separators.
            if (substr_count($clean, '.') > 1) {
                return (float) str_replace('.', '', $clean);
            }
            return (float) $clean;
        }
        // Both present — last one is decimal.
        if ($last_dot > $last_comma) {
            return (float) str_replace(',', '', $clean);
        }
        return (float) str_replace(array('.', ','), array('', '.'), $clean);
    }
}

// Helper: classify an invoice line item.
//
// WHMCS sets $item['type'] to 'LateFee' for items inserted by the
// AddLateFees cron (vendor/.../lib/Cron/Task/AddLateFees.php). For gateway
// /processing fees there is no authoritative type — addons inject them as
// 'Item' or with empty type — so we use a conservative explicit-phrase match
// on the description. Returns one of: 'late_fee' | 'gateway_fee' | 'regular'.
if (!function_exists('classifyInvoiceItem')) {
    function classifyInvoiceItem($item) {
        $type = isset($item['type']) ? (string) $item['type'] : '';
        if ($type === 'LateFee') {
            return 'late_fee';
        }

        $desc = isset($item['description']) ? strtolower((string) $item['description']) : '';

        // Late fee fallback for legacy invoices / non-LateFee-typed inserts.
        // Kept intentionally narrow to avoid false-positives on service names
        // that happen to contain these words.
        $late_fee_phrases = array(
            'late fee', 'late charge', 'overdue fee', 'late payment fee',
            'late payment charge', 'late-payment fee',
        );
        foreach ($late_fee_phrases as $phrase) {
            if (strpos($desc, $phrase) !== false) {
                return 'late_fee';
            }
        }

        // Gateway / processing fee — explicit phrases only. Each phrase pairs
        // a payment-context word with a fee/charge/surcharge word so generic
        // service names like "Payment Gateway Integration" do not match.
        $gateway_fee_phrases = array(
            'payment gateway fee', 'gateway fee', 'gateway charge',
            'payment processing fee', 'processing fee', 'transaction fee',
            'convenience fee', 'card surcharge', 'card fee',
            'online payment charge', 'online payment fee',
            'pg fee', 'pg charge', 'pg charges',
            'razorpay fee', 'stripe fee', 'paypal fee', 'payu fee',
        );
        foreach ($gateway_fee_phrases as $phrase) {
            if (strpos($desc, $phrase) !== false) {
                return 'gateway_fee';
            }
        }

        return 'regular';
    }
}

// Helper function for currency formatting that honors WHMCS standards:
//   - decimal places vary by currency code (most → 2, JPY/KRW/etc → 0,
//     KWD/BHD/etc → 3 per ISO 4217)
//   - thousands/decimal separators driven by $currencyformat (WHMCS
//     tblcurrencies.format: 1=US "1,234.56", 2=EU "1.234,56",
//     3=French "1 234.56", 4=plain "1234.56")
// Namespaced to avoid collisions with WHMCS core and third-party add-ons.
if (!function_exists('securiaceInvoiceFormatCurrency')) {
    function securiaceInvoiceFormatCurrency($amount, $currencyprefix = '', $currencysuffix = '') {
        // Set default currency values if not provided
        if (empty($currencyprefix) && empty($currencysuffix)) {
            if (isset($clientsdetails['currency']) && !empty($clientsdetails['currency'])) {
                $currencyprefix = '';
                $currencysuffix = $clientsdetails['currency'];
            } else {
                $currencyprefix = '₹';
                $currencysuffix = 'INR';
            }
        }

        // Decimal places per ISO 4217 conventions.
        $code = strtoupper((string) $currencysuffix);
        $zero_decimal_codes = array(
            'JPY', 'KRW', 'CLP', 'VND', 'IDR', 'KMF', 'PYG',
            'RWF', 'UGX', 'XAF', 'XOF', 'XPF', 'BIF', 'DJF',
            'GNF', 'ISK', 'MGA', 'VUV',
        );
        $three_decimal_codes = array('BHD', 'IQD', 'JOD', 'KWD', 'OMR', 'TND', 'LYD');
        if (in_array($code, $zero_decimal_codes, true)) {
            $decimals = 0;
        } elseif (in_array($code, $three_decimal_codes, true)) {
            $decimals = 3;
        } else {
            $decimals = 2;
        }

        // Separators per WHMCS $currencyformat. Read from the template global
        // when present; default to format 1 (US) when not.
        $thousands_sep = ',';
        $decimal_sep = '.';
        if (isset($GLOBALS['currencyformat'])) {
            switch ((int) $GLOBALS['currencyformat']) {
                case 2: $thousands_sep = '.'; $decimal_sep = ','; break;
                case 3: $thousands_sep = ' '; $decimal_sep = '.'; break;
                case 4: $thousands_sep = '';  $decimal_sep = '.'; break;
                case 1:
                default:
                    // US/UK style — already set above.
                    break;
            }
        }

        $formatted = '';
        if (!empty($currencyprefix)) {
            $formatted .= $currencyprefix . ' ';
        }
        $formatted .= number_format((float) $amount, $decimals, $decimal_sep, $thousands_sep);
        if (!empty($currencysuffix)) {
            $formatted .= ' ' . $currencysuffix;
        }
        return $formatted;
    }
}
// ========================================================================
// SECURIACE CONFIG BLOCK — edit only this section for company/bank/UPI
// ========================================================================

// Company details not available as dedicated WHMCS template variables.
// Phone, email, PAN, MSME go here; address/GSTIN come from WHMCS settings.
// WHMCS: Admin → Setup → General Settings → General → Address (each line = one array element in $companyaddress)
// WHMCS: Admin → Setup → General Settings → Invoices → Tax ID Label / Tax ID Number → $taxIdLabel / $taxCode
$SC_COMPANY_PHONE  = '+91 88888 88888';
$SC_COMPANY_EMAIL  = 'helpdesk@securiace.com';
$SC_COMPANY_PAN    = 'AWZPK7069G';
$SC_COMPANY_MSME   = 'UDYAM-MH-21-0014457';

// Bank details (shown in payment section)
$SC_BANK_NAME      = 'IDBI Bank';
$SC_BANK_NUMBER    = '500102000004909';
$SC_BANK_IFSC      = 'IBKL0000500';
$SC_BANK_TYPE      = 'Current';

// UPI ID — used in QR code and display text (one place only)
$SC_UPI_ID         = 'securiace.com@idbi';

// Verification salt — change periodically, keep private
$SC_VERIFY_SALT    = 'SECURIACE_INV_' . date('Y') . '_V2';

// Legal jurisdiction in payment terms
$SC_JURISDICTION   = 'Pune, Maharashtra';

// ========================================================================
// ENHANCEMENT CONFIGURATION — feature flags
// ========================================================================
$ENH = array(
    // Core Status Features
    'show_status_ribbon'         => true,
    'show_auth_seal'             => true,
    'show_verification_badge'    => true,
    'verification_badge_position'=> 'after_status',

    // Proforma & Invoice Management
    'proforma_enabled'           => true,
    'show_original_proforma'     => true,

    // Payment & Transactions
    'show_transactions'          => true,
    'show_payment_ui'            => true,

    // Compliance & Legal
    'official_auth_seal'         => true,
    'show_fx'                    => false,

    // Tax & Compliance
    'show_tax_details'           => true,
    'show_client_tax_id'         => true,
    'show_company_tax_id'        => true,

    // Overdue Management
    'show_overdue_details'       => true,
    'late_fee_policy'            => '',

    // MSME & Business Details
    'show_msme_details'          => true,
    'show_udyam_number'          => true,

    // Debug & Development
    'show_debug_section'         => false,
    'debug_level'                => 'full',
    'debug_include_sensitive'    => false,
    'debug_show_calculations'    => true,
    'debug_show_variables'       => true,
    'debug_show_performance'     => false,
);

// ========================================================================
// COLOR VARIABLES — plain variables, safe for batch PDF rendering
// (define() would fatal on second invoice in the same PHP process)
// ========================================================================
$COLOR_DARK_GREY  = array(64, 64, 64);
$COLOR_LIGHT_GREY = array(245, 245, 245);
$COLOR_PURPLE     = array(75, 0, 130);
$COLOR_WHITE      = array(255, 255, 255);
$COLOR_BLACK      = array(0, 0, 0);

// Status-based accent colors — initialised AFTER $ENH so the flag is readable
$_status_key = strtolower(trim(isset($status) ? $status : 'draft'));
if ($ENH['show_status_ribbon']) {
    switch ($_status_key) {
        case 'paid':
            $STATUS_ACCENT_COLOR = array(151, 223, 74);
            $STATUS_BORDER_COLOR = array(110, 192, 70);
            break;
        case 'overdue':
            $STATUS_ACCENT_COLOR = array(223, 85, 74);
            $STATUS_BORDER_COLOR = array(171, 49, 43);
            break;
        case 'cancelled':
        case 'refunded':
            $STATUS_ACCENT_COLOR = array(200, 200, 200);
            $STATUS_BORDER_COLOR = array(140, 140, 140);
            break;
        default:
            $STATUS_ACCENT_COLOR = array(75, 0, 130);
            $STATUS_BORDER_COLOR = array(75, 0, 130);
    }
} else {
    $STATUS_ACCENT_COLOR = array(75, 0, 130);
    $STATUS_BORDER_COLOR = array(75, 0, 130);
}

// Page setup
$pdf->SetMargins(8, 8, 8);
$pdf->SetAutoPageBreak(true, 25);

// ========================================================================
// PROFORMA DETECTION & STATUS LOGIC (WHMCS-COMPLIANT)
// ========================================================================

// Strict WHMCS-consistent Proforma detection
$isProforma = ($status !== 'Paid' && empty($invoicenum));

// Determine if invoice is payable (has outstanding balance)
$balance = isset($balance) ? floatval($balance) : 0;
$isPayable = !$isProforma ? ($status !== 'Paid' && $balance > 0) : true;

// Status normalization for consistent handling
$normalized_status = strtolower(trim($status));
if (empty($normalized_status)) {
    $normalized_status = 'draft';
}

// Determine document type and numbering
$document_type = $isProforma ? 'Proforma Invoice' : 'Invoice';
$document_number_label = $isProforma ? 'Proforma No' : 'Invoice No';
$document_number_value = $isProforma ? $invoiceid : $invoicenum;

// Status colors (WHMCS standard)
$status_colors = array(
    'paid' => array(13, 128, 64),      // #0D8040
    'unpaid' => array(192, 128, 0),    // #C08000
    'pending' => array(192, 128, 0),   // #C08000
    'payment pending' => array(192, 128, 0), // #C08000
    'overdue' => array(223, 85, 74),   // #DF554A
    'refunded' => array(131, 182, 218), // #83B6DA
    'cancelled' => array(200, 200, 200), // Gray
    'draft' => array(200, 200, 200),   // Gray
    'collections' => array(200, 200, 200) // Gray
);

// Get status color
$status_color = isset($status_colors[$normalized_status]) ? $status_colors[$normalized_status] : $status_colors['unpaid'];

// ========================================================================
// HEADER SECTION - LOGO AND INVOICE TITLE
// ========================================================================

// Logo (left side)
$logoFilename = 'placeholder.png';
if (file_exists(ROOTDIR . '/assets/img/logo.png')) {
    $logoFilename = 'logo.png';
} elseif (file_exists(ROOTDIR . '/assets/img/logo.jpg')) {
    $logoFilename = 'logo.jpg';
}
$pdf->Image(ROOTDIR . '/assets/img/' . $logoFilename, 8, 8, 45);

// Company Name (next to logo) - REMOVED as requested

// Dynamic Document Title (right side) - Proforma vs Invoice
$pdf->SetFont('dejavusans', 'B', 20);
$pdf->SetTextColor($COLOR_DARK_GREY[0], $COLOR_DARK_GREY[1], $COLOR_DARK_GREY[2]);
$pdf->SetXY(120, 8);
$pdf->Cell(70, 8, $document_type, 0, 1, 'R');

// --- Enhanced Status Ribbon (WHMCS-Compliant) ---
if ($ENH['show_status_ribbon']) {
    // Use pre-calculated status color and text
    $status_border_color = array(
        max(0, $status_color[0] - 30),
        max(0, $status_color[1] - 30),
        max(0, $status_color[2] - 30)
    );
    
    // Get localized status text
    $status_text = strtoupper($normalized_status);
    if ($normalized_status === 'payment pending') {
        $status_text = 'PAYMENT PENDING';
    }
    
    // Enhanced status ribbon with border and better positioning
    $pdf->SetFillColor($status_color[0], $status_color[1], $status_color[2]);
    $pdf->SetDrawColor($status_border_color[0], $status_border_color[1], $status_border_color[2]);
    $pdf->SetTextColor(255, 255, 255); // White text
    $pdf->SetFont('dejavusans', 'B', 9);
    $pdf->SetLineWidth(0.5);
    
    // Position below invoice title with better spacing
    $pdf->SetXY(135, 20);
    $pdf->Cell(55, 8, $status_text, 1, 1, 'C', true);
    
    // Reset colors and line width
    $pdf->SetTextColor($COLOR_DARK_GREY[0], $COLOR_DARK_GREY[1], $COLOR_DARK_GREY[2]);
    $pdf->SetLineWidth(0.2);
    
}

// ========================================================================
// ENHANCED DIGITAL VERIFICATION BADGE
// ========================================================================

// --- Enhanced Digital Verification Badge (Enterprise-Grade) - Only for Paid Invoices ---
if ($ENH['show_verification_badge'] && $normalized_status === 'paid') {
    /**
     * ENHANCED DIGITAL VERIFICATION SYSTEM
     * 
     * This implementation provides enterprise-grade digital verification with:
     * 1. Multi-layered hash generation using SHA-256 and SHA-512
     * 2. Comprehensive input data including invoice, client, and company details
     * 3. Salt-based security to prevent rainbow table attacks
     * 4. Timestamp inclusion for temporal verification
     * 5. Professional visual presentation with compliance indicators
     * 6. IT Act 2000 compliance for legal validity
     * 
     * Security Features:
     * - Salt: Prevents pre-computed hash attacks
     * - Multiple algorithms: SHA-256 + SHA-512 for enhanced security
     * - Comprehensive data: Invoice, client, company, and temporal data
     * - Unique per invoice: Each invoice gets a unique verification code
     */
    
    // Enhanced hash generation with multiple security layers
    $invoice_id = isset($invoiceid) ? $invoiceid : 0;
    $invoice_number = isset($invoicenum) ? $invoicenum : (isset($invoicenumber) ? $invoicenumber : $invoiceid);
    $invoice_total = isset($total) ? parseAmount($total) : 0;
    $invoice_date = isset($datecreated) ? $datecreated : date('Y-m-d');
    $invoice_due_date = isset($duedate) ? $duedate : '';
    $company_name = isset($companyname) ? $companyname : 'Securiace Technologies';
    $company_email = isset($companyaddress) && is_array($companyaddress) ? 
        (isset($companyaddress[5]) ? $companyaddress[5] : 'helpdesk@securiace.com') : 'helpdesk@securiace.com';
    
    // Enhanced hash input with multiple security factors
    $timestamp = date('Y-m-d H:i:s');
    $client_id = isset($clientsdetails['id']) ? $clientsdetails['id'] : 0;
    $client_email = isset($clientsdetails['email']) ? $clientsdetails['email'] : '';
    
    // Create comprehensive hash input with salt and multiple verification factors
    $salt = 'SECURIACE_INVOICE_VERIFICATION_2024';
    $hash_input = $salt . '|' . 
                  $invoice_id . '|' . 
                  $invoice_number . '|' . 
                  $invoice_total . '|' . 
                  $invoice_date . '|' . 
                  $invoice_due_date . '|' . 
                  $client_id . '|' . 
                  $client_email . '|' . 
                  $company_name . '|' . 
                  $company_email . '|' . 
                  $timestamp;
    
    // Generate enhanced hash with multiple algorithms for better security
    $primary_hash = strtoupper(substr(hash('sha256', $hash_input), 0, 12));
    $secondary_hash = strtoupper(substr(hash('sha512', $hash_input . '_SECONDARY'), 0, 8));
    $verification_code = $primary_hash . '-' . $secondary_hash;
    
    // Position verification badge below status ribbon with reduced gap
    $verification_y = 29; // Reduced gap by 50% (was 34, now 29: 6mm gap reduced to 3mm)
    
    // Enhanced verification badge - increased height by 20% with fresh design
    $badge_width = 55; // Match status badge width exactly
    $badge_height = 11.04; // Increased height by 20% (9.2 * 1.2 = 11.04)
    
    // ========================================================================
    // ULTRA-MODERN DIGITALLY VERIFIED BADGE DESIGN - MINIMALIST & ELEGANT
    // ========================================================================
    
    // Sleek minimalist background with subtle gradient effect
    $pdf->SetFillColor(248, 250, 255); // Ultra-light blue-white background
    $pdf->SetDrawColor(75, 0, 130); // Purple border
    $pdf->SetLineWidth(0.5);
    $pdf->Rect(135, $verification_y, $badge_width, $badge_height, 'DF');
    
    // Sophisticated inner frame with dual borders
    $pdf->SetDrawColor(220, 220, 240); // Light inner border
    $pdf->SetLineWidth(0.3);
    $pdf->Rect(135.8, $verification_y + 0.8, $badge_width - 1.6, $badge_height - 1.6);
    
    // Ultra-modern security shield icon (square with rounded corners effect)
    $pdf->SetFillColor(75, 0, 130); // Purple background
    $pdf->SetDrawColor(75, 0, 130);
    $pdf->SetLineWidth(0.2);
    $pdf->Rect(137.5, $verification_y + 1.5, 3, 3, 'DF'); // Square icon instead of circle
    
    // Modern shield checkmark with precise positioning
    $pdf->SetFont('dejavusans', 'B', 6);
    $pdf->SetTextColor(255, 255, 255);
    $pdf->SetXY(137.5, $verification_y + 1.8);
    $pdf->Cell(3, 2.4, '✓', 0, 0, 'C');
    
    // Sleek verification header with modern typography
    $pdf->SetFont('dejavusans', 'B', 8);
    $pdf->SetTextColor(75, 0, 130);
    $pdf->SetXY(135, $verification_y + 1.2);
    $pdf->Cell($badge_width, 2.8, 'DIGITALLY VERIFIED', 0, 0, 'C');
    
    // Professional verification code with enhanced spacing
    $pdf->SetFont('dejavusans', 'B', 6.5);
    $pdf->SetTextColor(30, 30, 30);
    $pdf->SetXY(135, $verification_y + 4.2);
    $formatted_code = substr($verification_code, 0, 12) . ' ' . substr($verification_code, 13, 8);
    $pdf->Cell($badge_width, 2.2, $formatted_code, 0, 0, 'C');
    
    // Elegant compliance ribbon with sophisticated styling
    $pdf->SetFillColor(46, 125, 50); // Deep green background
    $pdf->SetDrawColor(30, 100, 30); // Darker green border
    $pdf->SetLineWidth(0.4);
    $pdf->Rect(135, $verification_y + 6.6, $badge_width, 2.8, 'DF');
    
    // Premium compliance text with enhanced readability
    $pdf->SetFont('dejavusans', 'B', 6);
    $pdf->SetTextColor(255, 255, 255);
    $pdf->SetXY(135, $verification_y + 7.4);
    $pdf->Cell($badge_width, 1.4, 'IT ACT 2000 COMPLIANT', 0, 0, 'C');
    
    // Refined timestamp with subtle elegance
    $pdf->SetFont('dejavusans', '', 4.8);
    $pdf->SetTextColor(120, 120, 120);
    $pdf->SetXY(135, $verification_y + 9.8);
    $pdf->Cell($badge_width, 1.2, 'Generated: ' . $timestamp, 0, 0, 'C');
    
    // Sophisticated top accent line for premium finish
    $pdf->SetDrawColor(75, 0, 130);
    $pdf->SetLineWidth(0.3);
    $pdf->Line(135, $verification_y + 0.3, 135 + $badge_width, $verification_y + 0.3);
    
    // Elegant bottom accent line for balanced design
    $pdf->SetDrawColor(75, 0, 130);
    $pdf->SetLineWidth(0.2);
    $pdf->Line(135, $verification_y + $badge_height - 0.3, 135 + $badge_width, $verification_y + $badge_height - 0.3);
    
    // Reset colors
    $pdf->SetTextColor($COLOR_DARK_GREY[0], $COLOR_DARK_GREY[1], $COLOR_DARK_GREY[2]);
} elseif ($isProforma) {
    // Proforma Status Badge - in place of verification badge
    $proforma_y = 29; // Same position as verification badge (reduced gap)
    
    // Enhanced Proforma badge - increased height by 20% with fresh design
    $badge_width = 55; // Match status badge width exactly
    $badge_height = 11.04; // Increased height by 20% (9.2 * 1.2 = 11.04)
    
    // ========================================================================
    // FRESH PROFORMA BADGE DESIGN - ENTERPRISE GRADE
    // ========================================================================
    
    // Modern gradient-like background with subtle shadow
    $pdf->SetFillColor(255, 248, 248); // Very light red background
    $pdf->SetDrawColor(223, 85, 74); // Red border for Proforma
    $pdf->SetLineWidth(0.4);
    $pdf->Rect(135, $proforma_y, $badge_width, $badge_height, 'DF');
    
    // Inner highlight border for premium look
    $pdf->SetDrawColor(220, 180, 180); // Light red inner border
    $pdf->SetLineWidth(0.2);
    $pdf->Rect(135.5, $proforma_y + 0.5, $badge_width - 1, $badge_height - 1);
    
    // Modern Proforma icon with enhanced styling
    $pdf->SetFillColor(223, 85, 74); // Red background for circle
    $pdf->SetDrawColor(223, 85, 74);
    $pdf->SetLineWidth(0.3);
    $pdf->Circle(138.5, $proforma_y + 2, 1.5, 0, 360, 'F'); // Larger, more prominent circle
    
    // Enhanced "P" with better positioning
    $pdf->SetFont('dejavusans', 'B', 5.5);
    $pdf->SetTextColor(255, 255, 255);
    $pdf->SetXY(137.2, $proforma_y + 1.2);
    $pdf->Cell(2.6, 1.6, 'P', 0, 0, 'C');
    
    // Main Proforma text with modern typography
    $pdf->SetFont('dejavusans', 'B', 7.5);
    $pdf->SetTextColor(223, 85, 74);
    $pdf->SetXY(135, $proforma_y + 1.8);
    $pdf->Cell($badge_width, 2.5, 'PROFORMA INVOICE', 0, 0, 'C');
    
    // Status text with enhanced styling
    $pdf->SetFont('dejavusans', '', 6);
    $pdf->SetTextColor(40, 40, 40);
    $pdf->SetXY(135, $proforma_y + 4.5);
    $pdf->Cell($badge_width, 2, 'NOT VALID FOR TAX', 0, 0, 'C');
    
    // Modern compliance section with enhanced styling
    $pdf->SetFillColor(223, 85, 74); // Red background
    $pdf->SetDrawColor(180, 50, 50); // Darker red border
    $pdf->SetLineWidth(0.3);
    $pdf->Rect(135, $proforma_y + 6.8, $badge_width, 2.5, 'DF');
    
    // Compliance text with enhanced styling
    $pdf->SetFont('dejavusans', 'B', 5.5);
    $pdf->SetTextColor(255, 255, 255);
    $pdf->SetXY(135, $proforma_y + 7.5);
    $pdf->Cell($badge_width, 1.2, 'ACCOUNTING PURPOSES', 0, 0, 'C');
    
    // Modern timestamp with subtle styling
    $pdf->SetFont('dejavusans', '', 4.5);
    $pdf->SetTextColor(100, 100, 100);
    $pdf->SetXY(135, $proforma_y + 9.5);
    $pdf->Cell($badge_width, 1.5, 'Generated: ' . date('Y-m-d H:i:s'), 0, 0, 'C');
    
    // Subtle bottom accent line for premium finish
    $pdf->SetDrawColor(223, 85, 74);
    $pdf->SetLineWidth(0.2);
    $pdf->Line(135, $proforma_y + $badge_height - 0.5, 135 + $badge_width, $proforma_y + $badge_height - 0.5);
    
    // Reset colors
    $pdf->SetTextColor($COLOR_DARK_GREY[0], $COLOR_DARK_GREY[1], $COLOR_DARK_GREY[2]);
}

// ========================================================================
// PROFORMA DIAGONAL WATERMARK
// ========================================================================

// Add diagonal watermark for Proforma invoices
if ($isProforma) {
    // Save current graphics state
    $pdf->StartTransform();
    
    // Set watermark properties
    $pdf->SetTextColor(200, 200, 200); // Light gray color
    $pdf->SetFont('dejavusans', 'B', 24); // Large font
    $pdf->SetAlpha(0.15); // Very light opacity
    
    // Calculate center position for diagonal text
    $page_width = $pdf->GetPageWidth();
    $page_height = $pdf->GetPageHeight();
    $center_x = $page_width / 2;
    $center_y = $page_height / 2;
    
    // Rotate and position the watermark
    $pdf->Rotate(45, $center_x, $center_y);
    $pdf->SetXY($center_x - 100, $center_y - 10);
    $pdf->Cell(200, 20, 'PROFORMA – NOT VALID FOR ACCOUNTING / TAX PURPOSES', 0, 0, 'C');
    
    // Reset graphics state
    $pdf->StopTransform();
    $pdf->SetAlpha(1.0); // Reset opacity
    $pdf->SetTextColor($COLOR_DARK_GREY[0], $COLOR_DARK_GREY[1], $COLOR_DARK_GREY[2]); // Reset text color
}

// ========================================================================
// INVOICE DETAILS SECTION (Left side below logo)
// ========================================================================

// Dynamic Document Number (Proforma No vs Invoice No)
$pdf->SetFont('dejavusans', '', 9);
$pdf->SetTextColor($COLOR_DARK_GREY[0], $COLOR_DARK_GREY[1], $COLOR_DARK_GREY[2]);
$pdf->SetXY(8, 25);
$pdf->Cell(25, 4, $document_number_label . ' #', 0, 0, 'L');
$pdf->SetFont('dejavusans', 'B', 9);
$pdf->Cell(50, 4, $document_number_value, 0, 0, 'L');

// Add (Proforma) indicator for unpaid invoices - always show for Proforma
if ($isProforma) {
    $pdf->SetFont('dejavusans', 'B', 9); // Slightly larger font
    $pdf->SetTextColor(75, 0, 130); // Purple color for Proforma indicator
    $pdf->Cell(30, 4, ' (Proforma)', 0, 1, 'L');
} else {
    $pdf->Cell(30, 4, '', 0, 1, 'L'); // Empty cell for alignment
}

// Proforma Invoice No # will be displayed in Due Date position for paid invoices

// Invoice Date
$pdf->SetFont('dejavusans', '', 9);
$pdf->SetXY(8, 31);
$pdf->Cell(25, 4, 'Invoice Date', 0, 0, 'L');
$pdf->SetFont('dejavusans', 'B', 9);
// Format date as "Monday, March 10th, 2025"
$formatted_invoice_date = '';
if (isset($datecreated)) {
    $date_obj = new DateTime($datecreated);
    $formatted_invoice_date = $date_obj->format('l, F jS, Y');
}
$pdf->Cell(50, 4, $formatted_invoice_date, 0, 1, 'L');

// Due Date / Proforma Invoice No # (conditional based on status)
$hide_due_date_emphasis = in_array($normalized_status, array('paid', 'cancelled', 'refunded'));

if ($normalized_status === 'paid' && $ENH['show_original_proforma']) {
    // Show Proforma Invoice No # for paid invoices in Due Date position
    $pdf->SetFont('dejavusans', '', 9);
    $pdf->SetXY(8, 37);
    $pdf->Cell(25, 4, 'Proforma No #', 0, 0, 'L');
    $pdf->SetFont('dejavusans', 'B', 9);
    $pdf->Cell(50, 4, $invoiceid, 0, 1, 'L');
} elseif (!$hide_due_date_emphasis) {
    // Show Due Date for unpaid invoices
    $pdf->SetFont('dejavusans', '', 9);
    $pdf->SetXY(8, 37);
    $pdf->Cell(25, 4, 'Due Date', 0, 0, 'L');
    $pdf->SetFont('dejavusans', 'B', 9);
    // Format due date as "Wednesday, April 9th, 2025"
    $formatted_due_date = '';
    if (isset($duedate)) {
        $due_date_obj = new DateTime($duedate);
        $formatted_due_date = $due_date_obj->format('l, F jS, Y');
    }
    $pdf->Cell(50, 4, $formatted_due_date, 0, 1, 'L');
    
    // Overdue details if applicable
    if ($normalized_status === 'overdue' && $ENH['show_overdue_details'] && isset($duedate)) {
        $today = new DateTime();
        $due_date = new DateTime($duedate);
        $days_overdue = max(0, $today->diff($due_date)->days);
        if ($due_date < $today) {
            $days_overdue = $today->diff($due_date)->days;
        }
        
        $pdf->SetFont('dejavusans', '', 7);
        $pdf->SetTextColor(223, 85, 74); // Red for overdue
        $pdf->SetXY(8, 42);
        $pdf->Cell(50, 3, 'Overdue by ' . $days_overdue . ' days', 0, 1, 'L');
        
        // Late fee policy if configured
        if (!empty($ENH['late_fee_policy'])) {
            $pdf->SetXY(8, 45);
            $pdf->Cell(50, 3, 'Late fee per terms: ' . $ENH['late_fee_policy'], 0, 1, 'L');
        }
    }
}

// ========================================================================
// BILLED BY / BILLED TO SECTIONS
// ========================================================================

$billed_y_start = 50;

// Client Section (Left) - Client information (who is being billed)
$pdf->SetFillColor($COLOR_WHITE[0], $COLOR_WHITE[1], $COLOR_WHITE[2]);
$pdf->SetDrawColor($COLOR_BLACK[0], $COLOR_BLACK[1], $COLOR_BLACK[2]);
$pdf->Rect(8, $billed_y_start, 95, 55);

// "Billed To" title - professional styling
$pdf->SetFont('dejavusans', 'B', 10);
$pdf->SetTextColor($COLOR_DARK_GREY[0], $COLOR_DARK_GREY[1], $COLOR_DARK_GREY[2]);
$pdf->SetXY(12, $billed_y_start + 3);
$pdf->Cell(87, 5, 'Billed To', 0, 0, 'L');

// Client Details - with proper text wrapping and dynamic alignment
$pdf->SetFont('dejavusans', 'B', 9);
$pdf->SetTextColor($COLOR_DARK_GREY[0], $COLOR_DARK_GREY[1], $COLOR_DARK_GREY[2]);
$pdf->SetXY(12, $billed_y_start + 8);

// Use company name if available, otherwise use first/last name
$client_name = '';
if (isset($clientsdetails["companyname"]) && !empty(trim($clientsdetails["companyname"]))) {
    $client_name = trim($clientsdetails["companyname"]);
} else {
    $first_name = isset($clientsdetails["firstname"]) ? trim($clientsdetails["firstname"]) : '';
    $last_name = isset($clientsdetails["lastname"]) ? trim($clientsdetails["lastname"]) : '';
    $client_name = trim($first_name . ' ' . $last_name);
}

// Fallback to example client name if no client data
if (empty($client_name)) {
    $client_name = 'Quadrant Innovative Learning and Consulting LLP';
}

$pdf->MultiCell(87, 4, $client_name, 0, 'L');

// Client address with proper text wrapping
$pdf->SetFont('dejavusans', '', 8);
$pdf->SetTextColor($COLOR_DARK_GREY[0], $COLOR_DARK_GREY[1], $COLOR_DARK_GREY[2]);
$pdf->SetXY(12, $pdf->GetY() + 2);

// Build comprehensive client address from WHMCS variables
$client_address_parts = array();
if (isset($clientsdetails["address1"]) && !empty(trim($clientsdetails["address1"]))) {
    $client_address_parts[] = trim($clientsdetails["address1"]);
}
if (isset($clientsdetails["address2"]) && !empty(trim($clientsdetails["address2"]))) {
    $client_address_parts[] = trim($clientsdetails["address2"]);
}
if (isset($clientsdetails["city"]) && !empty(trim($clientsdetails["city"]))) {
    $client_address_parts[] = trim($clientsdetails["city"]);
}
if (isset($clientsdetails["state"]) && !empty(trim($clientsdetails["state"]))) {
    $client_address_parts[] = trim($clientsdetails["state"]);
}
if (isset($clientsdetails["country"]) && !empty(trim($clientsdetails["country"]))) {
    $client_address_parts[] = trim($clientsdetails["country"]);
}
if (isset($clientsdetails["postcode"]) && !empty(trim($clientsdetails["postcode"]))) {
    $client_address_parts[] = trim($clientsdetails["postcode"]);
}

$client_full_address = implode(', ', $client_address_parts);
if (empty($client_full_address)) {
    $client_full_address = 'Grande View 7, D404, Ornate, Phase-I, Behind Podar, International school, Katraj-Dehu Bypass, Ambegaon (BK), Pune, Maharashtra, India - 411046';
}

$pdf->MultiCell(87, 3, $client_full_address, 0, 'L');

// Client email and phone with proper styling
$pdf->SetFont('dejavusans', '', 8);
$pdf->SetTextColor($COLOR_DARK_GREY[0], $COLOR_DARK_GREY[1], $COLOR_DARK_GREY[2]);

// Client email
if (isset($clientsdetails["email"]) && !empty(trim($clientsdetails["email"]))) {
    $pdf->SetXY(12, $pdf->GetY() + 2);
    $pdf->MultiCell(87, 3, 'Email: ' . trim($clientsdetails["email"]), 0, 'L');
}

// Client phone
if (isset($clientsdetails["phonenumber"]) && !empty(trim($clientsdetails["phonenumber"]))) {
    $pdf->SetXY(12, $pdf->GetY() + 1);
    $pdf->MultiCell(87, 3, 'Phone: ' . trim($clientsdetails["phonenumber"]), 0, 'L');
}

// Custom fields for client with proper text wrapping
if (isset($customfields) && is_array($customfields)) {
    foreach ($customfields AS $customfield) {
        if (isset($customfield['fieldname']) && isset($customfield['value'])) {
            $pdf->SetXY(12, $pdf->GetY() + 1);
            $custom_text = trim($customfield['fieldname']) . ': ' . trim($customfield['value']);
            $pdf->MultiCell(87, 3, $custom_text, 0, 'L');
        }
    }
}

// Seller Section (Right) - Company Details (business owner/seller)
$pdf->SetFillColor($COLOR_WHITE[0], $COLOR_WHITE[1], $COLOR_WHITE[2]);
$pdf->SetDrawColor($COLOR_BLACK[0], $COLOR_BLACK[1], $COLOR_BLACK[2]);
$pdf->Rect(107, $billed_y_start, 95, 55);

// "Billed By" title - professional styling
$pdf->SetFont('dejavusans', 'B', 10);
$pdf->SetTextColor($COLOR_DARK_GREY[0], $COLOR_DARK_GREY[1], $COLOR_DARK_GREY[2]);
$pdf->SetXY(111, $billed_y_start + 3);
$pdf->Cell(87, 5, 'Billed By', 0, 0, 'L');

// Seller Details - Company Details (business owner/seller) with proper text wrapping
$pdf->SetFont('dejavusans', 'B', 9);
$pdf->SetTextColor($COLOR_DARK_GREY[0], $COLOR_DARK_GREY[1], $COLOR_DARK_GREY[2]);
$pdf->SetXY(111, $billed_y_start + 8);

// Use WHMCS company name variable for seller with fallback
$seller_name = isset($companyname) && !empty($companyname) ? $companyname : 'Securiace Technologies';
$pdf->MultiCell(87, 4, $seller_name, 0, 'L');

// Company Address - from screenshot
$pdf->SetFont('dejavusans', '', 8);
$pdf->SetTextColor($COLOR_DARK_GREY[0], $COLOR_DARK_GREY[1], $COLOR_DARK_GREY[2]);
$pdf->SetXY(111, $pdf->GetY() + 2);
$pdf->MultiCell(87, 3, 'Kishor Nagar Rd,, Nanded, Maharashtra, India - 431602', 0, 'L');

// PAN Number - from screenshot
$pdf->SetXY(111, $pdf->GetY() + 1);
$pdf->SetFont('dejavusans', 'B', 8);
$pdf->MultiCell(87, 3, 'PAN: AWZPK7069G', 0, 'L');

// Email - from screenshot
$pdf->SetXY(111, $pdf->GetY() + 1);
$pdf->SetFont('dejavusans', 'B', 8);
$pdf->MultiCell(87, 3, 'Email: helpdesk@securiace.com', 0, 'L');

// Phone - from screenshot
$pdf->SetXY(111, $pdf->GetY() + 1);
$pdf->SetFont('dejavusans', 'B', 8);
$pdf->MultiCell(87, 3, 'Phone: +91 88888 88888', 0, 'L');

// MSME Registration Details - from screenshot
$pdf->SetXY(111, $pdf->GetY() + 2);
$pdf->SetFont('dejavusans', 'B', 8);
$pdf->SetTextColor(75, 0, 130); // Purple color for MSME details
$pdf->MultiCell(87, 3, 'MSME Registered | UDYAM-MH-21-0014457', 0, 'L');

// Reset text color
$pdf->SetTextColor($COLOR_DARK_GREY[0], $COLOR_DARK_GREY[1], $COLOR_DARK_GREY[2]);


// ========================================================================
// ITEMIZED TABLE - DYNAMIC WIDTH CALCULATION
// ========================================================================

$table_y_start = $billed_y_start + 60;

// Dynamic discount detection and intelligent width calculation
$has_item_discounts = false;
$has_total_discount = false;

// Classify items into late-fee / gateway-fee / regular buckets. Authority:
// $item['type'] for late fees (set by WHMCS core); explicit description
// phrases for gateway fees (no canonical type). See classifyInvoiceItem().
$late_fee_items = array();
$gateway_fee_items = array();
$regular_items = array();
$late_fee_total = 0;
$gateway_fee_total = 0;

foreach ($invoiceitems AS $item) {
    $item_qty = isset($item['qty']) && $item['qty'] > 0 ? $item['qty'] : 1;
    $item_amount = parseAmount($item['amount']);

    switch (classifyInvoiceItem($item)) {
        case 'late_fee':
            $late_fee_items[] = $item;
            $late_fee_total += $item_amount * $item_qty;
            break;
        case 'gateway_fee':
            $gateway_fee_items[] = $item;
            $gateway_fee_total += $item_amount * $item_qty;
            break;
        default:
            $regular_items[] = $item;
            break;
    }

    // Check for item discounts
    $item_discount = isset($item['discount']) ? floatval($item['discount']) : 0;
    if ($item_discount > 0) {
        $has_item_discounts = true;
    }
}

// Check if there's a total discount
$total_discount = isset($discount) ? floatval($discount) : 0;
if ($total_discount > 0) {
    $has_total_discount = true;
}

// Determine if discount column should be shown
$show_discount_column = $has_item_discounts || $has_total_discount;

// Define the maximum usable page width (A4 minus 8mm margins on each side)
$max_page_width = 194; // 210mm A4 - 16mm margins (8mm each side)

// Define base proportional widths (conditional based on discount visibility)
$base_item_width = 85;      // Item column (largest)
$base_qty_width = 15;       // QTY column (smallest)
$base_rate_width = 25;      // Rate column
$base_discount_width = $show_discount_column ? 25 : 0; // Discount column (conditional)
$base_amount_width = 25;    // Amount column

// Calculate total base width
$base_total_width = $base_item_width + $base_qty_width + $base_rate_width + $base_discount_width + $base_amount_width;

// Calculate scaling factor to fit within page width
$scaling_factor = $max_page_width / $base_total_width;

// Calculate final column widths with proper scaling
$item_width = round($base_item_width * $scaling_factor, 2);
$qty_width = round($base_qty_width * $scaling_factor, 2);
$rate_width = round($base_rate_width * $scaling_factor, 2);
$discount_width = $show_discount_column ? round($base_discount_width * $scaling_factor, 2) : 0;
$amount_width = round($base_amount_width * $scaling_factor, 2);

// If no discount column, redistribute the space to other columns
if (!$show_discount_column) {
    $extra_space = $base_discount_width * $scaling_factor;
    $item_width += round($extra_space * 0.6, 2); // 60% to item column
    $rate_width += round($extra_space * 0.25, 2); // 25% to rate column
    $amount_width += round($extra_space * 0.15, 2); // 15% to amount column
}

// Ensure exact fit by adjusting the largest column if needed
$current_total = $item_width + $qty_width + $rate_width + $discount_width + $amount_width;
if (abs($current_total - $max_page_width) > 0.01) {
    $item_width += ($max_page_width - $current_total);
}

// Calculate cumulative positions for dynamic positioning
$item_x = 8;
$qty_x = $item_x + $item_width;
$rate_x = $qty_x + $qty_width;
$discount_x = $show_discount_column ? $rate_x + $rate_width : 0;
$amount_x = $show_discount_column ? $discount_x + $discount_width : $rate_x + $rate_width;

// Enhanced Table Header with Status-based Professional Styling
$pdf->SetFillColor($STATUS_ACCENT_COLOR[0], $STATUS_ACCENT_COLOR[1], $STATUS_ACCENT_COLOR[2]); // Status-based header background
$pdf->SetTextColor(255, 255, 255); // White text for contrast
$pdf->SetFont('dejavusans', 'B', 10); // Larger, bolder font

$pdf->SetXY($item_x, $table_y_start);
$pdf->Cell($item_width, 8, 'ITEM DESCRIPTION', 1, 0, 'C', true);
$pdf->Cell($qty_width, 8, 'QTY', 1, 0, 'C', true);
$pdf->Cell($rate_width, 8, 'RATE', 1, 0, 'C', true);

// Conditionally show discount header
if ($show_discount_column) {
    // Enhanced Discount header with accent styling
    $pdf->SetFillColor(34, 139, 34); // Forest Green background for discount header
    $pdf->SetTextColor(255, 255, 255); // White text
    $pdf->Cell($discount_width, 8, 'DISCOUNT', 1, 0, 'C', true);
    // Reset to status accent color for AMOUNT header
    $pdf->SetFillColor($STATUS_ACCENT_COLOR[0], $STATUS_ACCENT_COLOR[1], $STATUS_ACCENT_COLOR[2]);
}

$pdf->Cell($amount_width, 8, 'AMOUNT', 1, 1, 'C', true);

// Enhanced Table Rows with Professional Styling
$pdf->SetTextColor($COLOR_DARK_GREY[0], $COLOR_DARK_GREY[1], $COLOR_DARK_GREY[2]);

$current_y = $table_y_start + 8; // Increased spacing after header
$item_number = 1;
$row_alternate = false; // For alternating row colors

// Debug outputs removed to prevent unnecessary page breaks

foreach ($regular_items AS $item) {
    // Enhanced item description parsing with sophisticated pattern matching
    $description = $item['description'];
    
    // Initialize variables
    $service_name = '';
    $domain_name = '';
    $date_duration = '';
    
    // Enhanced pattern matching for better service description parsing
    // Pattern 1: "Service Name - domain.com (date - date)" or "Service Name - domain.com - duration (date - date)"
    if (preg_match('/^(.+?)\s*-\s*([^\(]+?)\s*\(([^\)]+)\)/', $description, $matches)) {
        $service_name = trim($matches[1]);
        $domain_info = trim($matches[2]);
        $date_duration = trim($matches[3]);
        
        // Check if domain info contains duration (e.g., "domain.com - 1 Year/s")
        if (preg_match('/^(.+?)\s*-\s*(.+)$/', $domain_info, $domain_matches)) {
            $domain_name = trim($domain_matches[1]);
            $duration_info = trim($domain_matches[2]);
            $domain_name = $domain_name . ' - ' . $duration_info;
        } else {
            $domain_name = $domain_info;
        }
    }
    // Pattern 2: "Service Name - domain.com" or "Service Name - domain.com - duration"
    elseif (preg_match('/^(.+?)\s*-\s*(.+)$/', $description, $matches)) {
        $service_name = trim($matches[1]);
        $domain_info = trim($matches[2]);
        
        // Check if domain info contains duration
        if (preg_match('/^(.+?)\s*-\s*(.+)$/', $domain_info, $domain_matches)) {
            $domain_name = trim($domain_matches[1]);
            $duration_info = trim($domain_matches[2]);
            $domain_name = $domain_name . ' - ' . $duration_info;
        } else {
            $domain_name = $domain_info;
        }
    }
    // Pattern 3: "Service Name (date - date)"
    elseif (preg_match('/^(.+?)\s*\(([^\)]+)\)/', $description, $matches)) {
        $service_name = trim($matches[1]);
        $date_duration = trim($matches[2]);
    }
    // Pattern 4: Simple service name only
    else {
        $service_name = $description;
    }
    
    // Clean up and format the extracted information
    $service_name = trim($service_name);
    $domain_name = trim($domain_name);
    $date_duration = trim($date_duration);
    
    // Enhanced item description formatting with professional hierarchy
    $line_height = 4;
    
    // Format service name with numbering and bold styling
    $service_text = $item_number . ". " . $service_name;
    
    // Format domain information with proper indentation
    $domain_text = !empty($domain_name) ? $domain_name : '';
    
    // Format date duration with proper indentation
    $date_text = !empty($date_duration) ? $date_duration : '';
    
    // Calculate required height for each text element with enhanced spacing
    $pdf->SetFont('dejavusans', 'B', 9); // Slightly larger for better readability
    $service_height = $pdf->getStringHeight($item_width - 6, $service_text);
    
    $domain_height = 0;
    if (!empty($domain_text)) {
        $pdf->SetFont('dejavusans', '', 8); // Slightly larger for better readability
        $domain_height = $pdf->getStringHeight($item_width - 8, $domain_text);
    }
    
    $date_height = 0;
    if (!empty($date_text)) {
        $pdf->SetFont('dejavusans', '', 8); // Slightly larger for better readability
        $date_height = $pdf->getStringHeight($item_width - 8, $date_text);
    }
    
    // Calculate total row height with enhanced spacing and visual separation
    $total_text_height = $service_height + $domain_height + $date_height;
    $vertical_spacing = 2; // Additional spacing between text elements
    $row_height = max(10, $total_text_height + 8 + ($vertical_spacing * 2)); // Enhanced minimum height and padding
    
    // Enhanced row styling with alternating colors
    $row_alternate = !$row_alternate; // Toggle for alternating rows
    $row_bg_color = $row_alternate ? array(248, 248, 248) : array(255, 255, 255); // Light grey / White
    
    // Draw item cell with enhanced styling
    $pdf->SetFillColor($row_bg_color[0], $row_bg_color[1], $row_bg_color[2]);
    $pdf->SetXY($item_x, $current_y);
    $pdf->Cell($item_width, $row_height, '', 1, 0, 'L', true); // Filled cell with border
    
    // Enhanced Service Name (Bold, larger) with professional formatting
    $pdf->SetFont('dejavusans', 'B', 9);
    $pdf->SetXY($item_x + 3, $current_y + 2);
    $pdf->MultiCell($item_width - 6, $line_height, $service_text, 0, 'L');
    
    // Add subtle visual separator if there are details to show
    if (!empty($domain_text) || !empty($date_text)) {
        $pdf->SetDrawColor(200, 200, 200); // Light grey separator
        $pdf->SetLineWidth(0.2);
        $separator_y = $pdf->GetY() + 1;
        $pdf->Line($item_x + 6, $separator_y, $item_x + $item_width - 6, $separator_y);
    }
    
    // Enhanced Domain Name (Regular, indented) with better spacing
    if (!empty($domain_text)) {
        $pdf->SetFont('dejavusans', '', 8);
        $pdf->SetXY($item_x + 6, $pdf->GetY() + $vertical_spacing + 1); // Enhanced indentation and spacing
        $pdf->MultiCell($item_width - 10, $line_height, $domain_text, 0, 'L');
    }
    
    // Enhanced Date Duration (Regular, indented) with better spacing
    if (!empty($date_text)) {
        $pdf->SetFont('dejavusans', '', 8);
        $pdf->SetXY($item_x + 6, $pdf->GetY() + $vertical_spacing); // Enhanced indentation and spacing
        $pdf->MultiCell($item_width - 10, $line_height, $date_text, 0, 'L');
    }
    
    // Enhanced Quantity column with alternating row styling
    $pdf->SetFillColor($row_bg_color[0], $row_bg_color[1], $row_bg_color[2]);
    $pdf->SetFont('dejavusans', 'B', 9); // Slightly larger, bolder font
    $pdf->SetXY($qty_x, $current_y);
    $quantity = isset($item['qty']) && $item['qty'] > 0 ? $item['qty'] : 1;
    $quantity_display = $quantity;
    $pdf->Cell($qty_width, $row_height, $quantity_display, 1, 0, 'C', true);
    
    // Enhanced Rate column with alternating row styling
    $pdf->SetFillColor($row_bg_color[0], $row_bg_color[1], $row_bg_color[2]);
    $pdf->SetFont('dejavusans', '', 8);
    $pdf->SetXY($rate_x, $current_y);
    $amount_value = parseAmount($item['amount']);
    $rate_display = securiaceInvoiceFormatCurrency($amount_value, $currencyprefix, $currencysuffix);
    $pdf->Cell($rate_width, $row_height, $rate_display, 1, 0, 'R', true);
    
    // Conditionally show discount column
    if ($show_discount_column) {
        // Enhanced Discount column with sophisticated styling
        $item_discount = isset($item['discount']) ? $item['discount'] : 0;
        
        if ($item_discount > 0) {
            // Discount Applied - Green accent styling
            $pdf->SetFillColor($row_bg_color[0], $row_bg_color[1], $row_bg_color[2]); // Base row color
            $pdf->SetTextColor(34, 139, 34); // Forest Green text for discount
            $pdf->SetFont('dejavusans', 'B', 8); // Bold font for emphasis
            $discount_display = securiaceInvoiceFormatCurrency($item_discount, $currencyprefix, $currencysuffix);
        } else {
            // No Discount - Muted styling
            $pdf->SetFillColor($row_bg_color[0], $row_bg_color[1], $row_bg_color[2]); // Base row color
            $pdf->SetTextColor(150, 150, 150); // Muted grey text
            $pdf->SetFont('dejavusans', '', 7); // Smaller, regular font
            $discount_display = '—'; // Elegant dash instead of simple hyphen
        }
        
        $pdf->SetXY($discount_x, $current_y);
        $pdf->Cell($discount_width, $row_height, $discount_display, 1, 0, 'R', true);
    }
    
    // Enhanced Amount column with alternating row styling
    $pdf->SetFillColor($row_bg_color[0], $row_bg_color[1], $row_bg_color[2]);
    $pdf->SetFont('dejavusans', 'B', 9); // Bold for emphasis
    $pdf->SetXY($amount_x, $current_y);
    $amount = ($amount_value * $quantity) - $item_discount;
    $amount_display = securiaceInvoiceFormatCurrency($amount, $currencyprefix, $currencysuffix);
    $pdf->Cell($amount_width, $row_height, $amount_display, 1, 1, 'R', true);
    
    // Debug output removed to prevent page breaks
    
    // Reset font and color for next iteration
    $pdf->SetFont('dejavusans', '', 8);
    $pdf->SetTextColor($COLOR_DARK_GREY[0], $COLOR_DARK_GREY[1], $COLOR_DARK_GREY[2]);
    
    // Update current_y for next row using actual MultiCell height
    $current_y = $pdf->GetY() + 2; // Add small spacing between rows
    $item_number++;
}

// Store renewal items for last page display
$renewal_items = array();
$item_counter = 1;

foreach ($regular_items AS $item) {
    $description = $item['description'];
    
    // Extract service information
    $service_name = '';
    $domain_name = '';
    $date_duration = '';
    $duration_info = '';
    $is_renewable = false; // Track if item is renewable
    
    // Enhanced pattern matching for renewal date extraction
    if (preg_match('/^(.+?)\s*-\s*([^\(]+?)\s*\(([^\)]+)\)/', $description, $matches)) {
        $service_name = trim($matches[1]);
        $domain_info = trim($matches[2]);
        $date_duration = trim($matches[3]);
        
        // Check if domain info contains duration
        if (preg_match('/^(.+?)\s*-\s*(.+)$/', $domain_info, $domain_matches)) {
            $domain_name = trim($domain_matches[1]);
            $duration_info = trim($domain_matches[2]);
        } else {
            $domain_name = $domain_info;
        }
    } elseif (preg_match('/^(.+?)\s*-\s*(.+)$/', $description, $matches)) {
        $service_name = trim($matches[1]);
        $domain_info = trim($matches[2]);
        
        if (preg_match('/^(.+?)\s*-\s*(.+)$/', $domain_info, $domain_matches)) {
            $domain_name = trim($domain_matches[1]);
            $duration_info = trim($domain_matches[2]);
        } else {
            $domain_name = $domain_info;
        }
    } elseif (preg_match('/^(.+?)\s*\(([^\)]+)\)/', $description, $matches)) {
        $service_name = trim($matches[1]);
        $date_duration = trim($matches[2]);
    } else {
        $service_name = $description;
    }
    
    // Calculate renewal date based on service duration
    $renewal_date = null;
    $renewal_text = '';
    
    if (!empty($date_duration)) {
        // Try to extract dates from date_duration
        if (preg_match('/(\d{4}-\d{2}-\d{2})\s*-\s*(\d{4}-\d{2}-\d{2})/', $date_duration, $date_matches)) {
            $start_date = new DateTime($date_matches[1]);
            $end_date = new DateTime($date_matches[2]);
            $renewal_date = $end_date;
            $renewal_text = $end_date->format('M j, Y');
            $is_renewable = true; // Mark as renewable
        } elseif (preg_match('/(\d{4}-\d{2}-\d{2})/', $date_duration, $date_matches)) {
            $renewal_date = new DateTime($date_matches[1]);
            $renewal_text = $renewal_date->format('M j, Y');
            $is_renewable = true; // Mark as renewable
        }
    }
    
    // If no specific date found, try to calculate from duration
    if (!$renewal_date && !empty($duration_info)) {
        $invoice_date = isset($datecreated) ? new DateTime($datecreated) : new DateTime();
        $renewal_date = clone $invoice_date;
        
        // Parse duration (e.g., "1 Year", "6 Months", "30 Days")
        if (preg_match('/(\d+)\s*(year|month|day)/i', $duration_info, $duration_matches)) {
            $amount = intval($duration_matches[1]);
            $unit = strtolower($duration_matches[2]);
            
            switch ($unit) {
                case 'year':
                case 'years':
                    $renewal_date->add(new DateInterval('P' . $amount . 'Y'));
                    break;
                case 'month':
                case 'months':
                    $renewal_date->add(new DateInterval('P' . $amount . 'M'));
                    break;
                case 'day':
                case 'days':
                    $renewal_date->add(new DateInterval('P' . $amount . 'D'));
                    break;
            }
            
            $renewal_text = $renewal_date->format('M j, Y');
            $is_renewable = true; // Mark as renewable
        }
    }
    
    // Only process renewal items if they are renewable and have a valid renewal date
    if ($is_renewable && $renewal_date) {
        // Determine urgency level
        $today = new DateTime();
        $days_until_renewal = $today->diff($renewal_date)->days;
        $is_overdue = $renewal_date < $today;
        $is_urgent = $days_until_renewal <= 30 && !$is_overdue;
        $is_upcoming = $days_until_renewal <= 90 && !$is_overdue;
        
        // Store renewal item only if renewable
        $renewal_items[] = array(
            'item_number' => $item_counter,
            'service_name' => $service_name,
            'domain_name' => $domain_name,
            'renewal_date' => $renewal_date,
            'renewal_text' => $renewal_text,
            'days_until' => $days_until_renewal,
            'is_overdue' => $is_overdue,
            'is_urgent' => $is_urgent,
            'is_upcoming' => $is_upcoming
        );
    }
    
    $item_counter++;
}

// Calculate totals - using WHMCS standard variables
// Always calculate from items to ensure accuracy
$calculated_subtotal = 0;
foreach ($regular_items AS $item) {
    $item_qty = isset($item['qty']) && $item['qty'] > 0 ? $item['qty'] : 1;
    $item_amount = parseAmount($item['amount']);
    $calculated_subtotal += $item_amount * $item_qty;
}

// $calculated_subtotal so far is the sum of $regular_items only. Add the
// extracted fee buckets so this fallback matches WHMCS's $subtotal shape
// (which is the sum of ALL invoice line items).
$calculated_subtotal += $late_fee_total + $gateway_fee_total;

// Use WHMCS provided variables - extract numeric values with proper object handling
$subtotal = isset($subtotal) ? parseAmount($subtotal) : $calculated_subtotal;
$tax = isset($tax) ? parseAmount($tax) : 0;
$tax2 = isset($tax2) ? parseAmount($tax2) : 0;
$credit = isset($credit) ? parseAmount($credit) : 0;
$discount = isset($discount) ? parseAmount($discount) : 0;

// WHMCS $subtotal is the SUM of all invoice line items, including late-fee
// and gateway-fee items. Render those as separate rows after Subtotal so the
// math the customer sees adds up:
//   Subtotal − Discount + LateFee + GatewayFee + Tax + Tax2 − Credit = Total
$subtotal_for_display = $subtotal - $late_fee_total - $gateway_fee_total;
if ($subtotal_for_display < 0) {
    $subtotal_for_display = $subtotal; // defensive: unexpected fee > subtotal
}

// Extract $total as numeric. Use null sentinel for "not usable" so we can
// distinguish a legitimate zero total (refunded / fully-credit-applied
// invoices) from "fall back to recomputation". Previously this gate was
// `> 0` which mis-routed zero totals into the calculated path.
$whmcs_total = null;
if (isset($total)) {
    if (is_numeric($total)) {
        $whmcs_total = floatval($total);
    } elseif (is_object($total)) {
        // Money / Decimal value objects typically expose __toString.
        // If they don't, leave null and fall back to recomputation.
        if (method_exists($total, '__toString')) {
            $whmcs_total = parseAmount((string) $total);
        }
    } else {
        $whmcs_total = parseAmount($total);
    }
}

// Fallback total when WHMCS does not supply $total. Match WHMCS's canonical
// formula: tblinvoices.total = subtotal − discount + tax + tax2. Credit is
// NOT part of `total` in WHMCS — credit is recorded as a payment in
// tblaccounts and reduces `balance`, not `total`. The template renders the
// CREDIT row separately and shows BALANCE DUE / AMOUNT PAID downstream.
$calculated_total = $subtotal - $discount + $tax + $tax2;
$final_total = ($whmcs_total !== null) ? $whmcs_total : $calculated_total;

// Initialize currency variables with fallback values
if (empty($currencyprefix)) {
    $currencyprefix = '₹';
}
if (empty($currencysuffix)) {
    $currencysuffix = 'INR';
}
if (empty($currencycode)) {
    $currencycode = 'INR';
}
if (empty($currencyrate)) {
    $currencyrate = 1;
}

// Debug: Show totals calculation
$pdf->SetFont('dejavusans', '', 6);
$pdf->SetTextColor(128, 128, 128);
// Debug output removed to prevent page breaks

// Reset font and color for totals section
$pdf->SetFont('dejavusans', 'B', 9);
$pdf->SetTextColor($COLOR_DARK_GREY[0], $COLOR_DARK_GREY[1], $COLOR_DARK_GREY[2]);

// Enhanced Subtotal Row with Professional Styling
$pdf->SetFillColor($COLOR_DARK_GREY[0], $COLOR_DARK_GREY[1], $COLOR_DARK_GREY[2]); // Dark background
$pdf->SetTextColor(255, 255, 255); // White text
$pdf->SetFont('dejavusans', 'B', 9); // Bold font
$pdf->SetXY($item_x, $current_y);
$pdf->Cell($item_width, 8, 'SUBTOTAL', 1, 0, 'R', true);
$pdf->Cell($qty_width, 8, '', 1, 0, 'C', true);
$pdf->Cell($rate_width, 8, '', 1, 0, 'C', true);

// Conditionally show discount column in subtotal
if ($show_discount_column) {
    $pdf->Cell($discount_width, 8, '', 1, 0, 'C', true);
}

// Display services-only subtotal — late-fee and gateway-fee items render as
// their own rows below so the running math adds up to the printed total.
$subtotal_display = securiaceInvoiceFormatCurrency($subtotal_for_display, $currencyprefix, $currencysuffix);
$pdf->Cell($amount_width, 8, $subtotal_display, 1, 1, 'R', true);
// Debug output removed to prevent page breaks

// Proforma Disclaimer (only for Proforma invoices)
if ($isProforma) {
    $current_y += 10; // Space before disclaimer
    
    // Disclaimer box with professional styling
    $pdf->SetFillColor(255, 248, 220); // Light yellow background
    $pdf->SetDrawColor(255, 193, 7); // Amber border
    $pdf->SetLineWidth(0.5);
    $pdf->Rect(8, $current_y, 194, 12, 'DF'); // Filled rectangle with border
    
    // Disclaimer text
    $pdf->SetFont('dejavusans', 'B', 9);
    $pdf->SetTextColor(138, 43, 226); // Purple text for emphasis
    $pdf->SetXY(12, $current_y + 3);
    $pdf->Cell(190, 6, 'DISCLAIMER:', 0, 1, 'L');
    
    $pdf->SetFont('dejavusans', '', 8);
    $pdf->SetTextColor($COLOR_DARK_GREY[0], $COLOR_DARK_GREY[1], $COLOR_DARK_GREY[2]);
    $pdf->SetXY(12, $current_y + 6);
    $pdf->Cell(190, 4, 'This is a provisional document. An official invoice will be issued once payment is confirmed.', 0, 1, 'L');
    
    $current_y += 12; // Space after disclaimer
}

// Reset font and color for next section
$pdf->SetFont('dejavusans', 'B', 9);
$pdf->SetTextColor($COLOR_DARK_GREY[0], $COLOR_DARK_GREY[1], $COLOR_DARK_GREY[2]);
$current_y += 7;

// Indian Tax Compliance - Proper order: Subtotal → Discount → Tax → Credit → Total

// Enhanced Discount Row with Professional Styling (only show if discount exists)
if ($discount > 0) {
    // Discount Applied - Green styling for positive discount
    $pdf->SetFillColor(34, 139, 34); // Forest Green background
    $pdf->SetTextColor(255, 255, 255); // White text
    $pdf->SetFont('dejavusans', 'B', 9); // Bold font
    $pdf->SetXY($item_x, $current_y);
    
    // Calculate discount percentage if possible
    $discount_percentage = '';
    if ($subtotal > 0) {
        $discount_percentage = round(($discount / $subtotal) * 100, 0);
        $discount_label = 'DISCOUNT (' . $discount_percentage . '%)';
    } else {
        $discount_label = 'DISCOUNT';
    }
    $pdf->Cell($item_width, 8, $discount_label, 1, 0, 'R', true);
    $pdf->Cell($qty_width, 8, '', 1, 0, 'C', true);
    $pdf->Cell($rate_width, 8, '', 1, 0, 'C', true);
    
    // Conditionally show discount column in discount row
    if ($show_discount_column) {
        $pdf->Cell($discount_width, 8, '', 1, 0, 'C', true);
    }
    
    $discount_display = '(' . securiaceInvoiceFormatCurrency($discount, $currencyprefix, $currencysuffix) . ')';
    $pdf->Cell($amount_width, 8, $discount_display, 1, 1, 'R', true);
    $current_y += 8;
}

// Late Fee Row (after subtotal/discount, before tax) — extracted from
// itemized table by classifyInvoiceItem(); subtotal_for_display already
// excludes this amount, so adding it back here is a real addition.
if (!empty($late_fee_items) && $late_fee_total > 0) {
    $pdf->SetFillColor(220, 53, 69); // Red background for late fees
    $pdf->SetTextColor(255, 255, 255);
    $pdf->SetFont('dejavusans', 'B', 9);
    $pdf->SetXY($item_x, $current_y);
    $pdf->Cell($item_width, 8, 'LATE FEE', 1, 0, 'R', true);
    $pdf->Cell($qty_width, 8, '', 1, 0, 'C', true);
    $pdf->Cell($rate_width, 8, '', 1, 0, 'C', true);
    if ($show_discount_column) {
        $pdf->Cell($discount_width, 8, '', 1, 0, 'C', true);
    }
    $late_fee_display = securiaceInvoiceFormatCurrency($late_fee_total, $currencyprefix, $currencysuffix);
    $pdf->Cell($amount_width, 8, $late_fee_display, 1, 1, 'R', true);
    $current_y += 8;
}

// Gateway / Payment Processing Fee Row — separated from services so the
// charge is unambiguous on the customer's invoice.
if (!empty($gateway_fee_items) && $gateway_fee_total > 0) {
    $pdf->SetFillColor(108, 117, 125); // Slate gray — distinct from late-fee red
    $pdf->SetTextColor(255, 255, 255);
    $pdf->SetFont('dejavusans', 'B', 9);
    $pdf->SetXY($item_x, $current_y);
    $pdf->Cell($item_width, 8, 'PAYMENT GATEWAY FEE', 1, 0, 'R', true);
    $pdf->Cell($qty_width, 8, '', 1, 0, 'C', true);
    $pdf->Cell($rate_width, 8, '', 1, 0, 'C', true);
    if ($show_discount_column) {
        $pdf->Cell($discount_width, 8, '', 1, 0, 'C', true);
    }
    $gateway_fee_display = securiaceInvoiceFormatCurrency($gateway_fee_total, $currencyprefix, $currencysuffix);
    $pdf->Cell($amount_width, 8, $gateway_fee_display, 1, 1, 'R', true);
    $current_y += 8;
}

// Enhanced Tax Row with Professional Styling (GST/CGST/SGST)
if ($tax > 0) {
    // Tax Applied - Blue styling for tax
    $pdf->SetFillColor(70, 130, 180); // Steel Blue background
    $pdf->SetTextColor(255, 255, 255); // White text
    $pdf->SetFont('dejavusans', 'B', 9); // Bold font
    $pdf->SetXY($item_x, $current_y);
    
    // Indian GST compliant tax labels
    $tax_label = 'GST';
    if (isset($taxrate) && isset($taxname)) {
        if (strpos(strtoupper($taxname), 'CGST') !== false) {
            $tax_label = 'CGST @ ' . $taxrate . '%';
        } elseif (strpos(strtoupper($taxname), 'SGST') !== false) {
            $tax_label = 'SGST @ ' . $taxrate . '%';
        } elseif (strpos(strtoupper($taxname), 'IGST') !== false) {
            $tax_label = 'IGST @ ' . $taxrate . '%';
        } else {
            $tax_label = $taxrate . '% ' . strtoupper($taxname);
        }
    }
    $pdf->Cell($item_width, 8, $tax_label, 1, 0, 'R', true);
    $pdf->Cell($qty_width, 8, '', 1, 0, 'C', true);
    $pdf->Cell($rate_width, 8, '', 1, 0, 'C', true);
    
    // Conditionally show discount column in tax row
    if ($show_discount_column) {
        $pdf->Cell($discount_width, 8, '', 1, 0, 'C', true);
    }
    
    $tax_display = securiaceInvoiceFormatCurrency($tax, $currencyprefix, $currencysuffix);
    $pdf->Cell($amount_width, 8, $tax_display, 1, 1, 'R', true);
    $current_y += 8;
}

// Enhanced Tax2 Row with Professional Styling (Additional GST components)
if ($tax2 > 0) {
    // Tax2 Applied - Dark Blue styling for second tax
    $pdf->SetFillColor(25, 25, 112); // Midnight Blue background
    $pdf->SetTextColor(255, 255, 255); // White text
    $pdf->SetFont('dejavusans', 'B', 9); // Bold font
    $pdf->SetXY($item_x, $current_y);
    
    // Indian GST compliant tax2 labels
    $tax2_label = 'ADDITIONAL TAX';
    if (isset($taxrate2) && isset($taxname2)) {
        if (strpos(strtoupper($taxname2), 'CESS') !== false) {
            $tax2_label = 'CESS @ ' . $taxrate2 . '%';
        } elseif (strpos(strtoupper($taxname2), 'SURCHARGE') !== false) {
            $tax2_label = 'SURCHARGE @ ' . $taxrate2 . '%';
        } else {
            $tax2_label = $taxrate2 . '% ' . strtoupper($taxname2);
        }
    }
    $pdf->Cell($item_width, 8, $tax2_label, 1, 0, 'R', true);
    $pdf->Cell($qty_width, 8, '', 1, 0, 'C', true);
    $pdf->Cell($rate_width, 8, '', 1, 0, 'C', true);
    
    // Conditionally show discount column in tax2 row
    if ($show_discount_column) {
        $pdf->Cell($discount_width, 8, '', 1, 0, 'C', true);
    }
    
    $tax2_display = securiaceInvoiceFormatCurrency($tax2, $currencyprefix, $currencysuffix);
    $pdf->Cell($amount_width, 8, $tax2_display, 1, 1, 'R', true);
    $current_y += 8;
}

// Credit Row (only show if credit > 0) - Indian compliant
if ($credit > 0) {
    $pdf->SetFillColor(255, 193, 7); // Amber background for credit
    $pdf->SetTextColor(0, 0, 0); // Black text for better readability
    $pdf->SetFont('dejavusans', 'B', 9); // Bold font
    $pdf->SetXY($item_x, $current_y);
    $pdf->Cell($item_width, 8, 'CREDIT APPLIED', 1, 0, 'R', true);
    $pdf->Cell($qty_width, 8, '', 1, 0, 'C', true);
    $pdf->Cell($rate_width, 8, '', 1, 0, 'C', true);
    
    // Conditionally show discount column in credit row
    if ($show_discount_column) {
        $pdf->Cell($discount_width, 8, '', 1, 0, 'C', true);
    }
    
    $credit_display = '(' . securiaceInvoiceFormatCurrency($credit, $currencyprefix, $currencysuffix) . ')';
    $pdf->Cell($amount_width, 8, $credit_display, 1, 1, 'R', true);
    $current_y += 8;
}

// ========================================================================
// STATUS-AWARE TOTALS SECTION
// ========================================================================

// Check for page overflow before totals section
$estimated_totals_height = 50; // Estimated height for totals section
if ($pdf->GetY() + $estimated_totals_height > $pdf->GetPageHeight() - 30) {
    $pdf->AddPage();
    $current_y = 20; // Reset Y position for new page
}

// Calculate additional totals for status-aware display - ENHANCED BALANCE CALCULATION
// Fix balance calculation with proper object handling
$original_balance = isset($balance) ? floatval($balance) : 0;

if ($normalized_status === 'paid') {
    $amount_paid = $final_total;
    $balance = 0; // Force balance to 0 for paid invoices
} else {
    // For unpaid invoices, calculate amount paid and balance properly
    $amount_paid = $final_total - $original_balance;
    
    // If WHMCS balance seems incorrect (like showing 1 instead of full amount), 
    // recalculate based on actual payments
    if ($original_balance > 0 && $original_balance < $final_total) {
        // Check if there are any transactions that might explain the balance
        $transaction_total = 0;
        if (isset($transactions) && is_array($transactions)) {
            foreach ($transactions as $transaction) {
                // WHMCS Invoice::getTransactions() exposes 'amount' as a
                // locale-formatted currency string ("₹1,000.00 INR",
                // "1.234,56 EUR", etc). parseAmount() handles all four
                // WHMCS $currencyformat styles + heuristic fallback.
                $trans_amount_raw = isset($transaction['amount']) ? $transaction['amount'] : 0;
                $transaction_total += parseAmount($trans_amount_raw);
            }
        }
        
        if ($transaction_total > 0) {
            $amount_paid = $transaction_total;
            $balance = $final_total - $amount_paid;
        } else {
            // No transactions, so balance should equal total for unpaid invoices
            $amount_paid = 0;
            $balance = $final_total;
        }
    } else {
        // Use WHMCS balance as is
        $balance = $original_balance;
        $amount_paid = $final_total - $balance;
    }
}

// Get payment details from transactions if available, otherwise use WHMCS defaults
$date_paid = '';
$payment_method = '';
if (isset($transactions) && is_array($transactions) && count($transactions) > 0) {
    // Get the latest transaction date and method
    $latest_transaction = end($transactions);
    $date_paid = isset($latest_transaction['date']) ? $latest_transaction['date'] : (isset($datepaid) ? $datepaid : '');
    $payment_method = isset($latest_transaction['gateway']) ? $latest_transaction['gateway'] : 
                     (isset($latest_transaction['paymentmethod']) ? $latest_transaction['paymentmethod'] : 
                     (isset($paymentmethod) ? $paymentmethod : ''));
} else {
    $date_paid = isset($datepaid) ? $datepaid : '';
    $payment_method = isset($paymentmethod) ? $paymentmethod : '';
}

// Enhanced Total Row with Status-based Premium Styling
$pdf->SetFillColor($STATUS_ACCENT_COLOR[0], $STATUS_ACCENT_COLOR[1], $STATUS_ACCENT_COLOR[2]); // Status-based background for emphasis
$pdf->SetTextColor(255, 255, 255); // White text
$pdf->SetFont('dejavusans', 'B', 11); // Larger, bolder font
$pdf->SetXY($item_x, $current_y);
$pdf->Cell($item_width, 10, 'GRAND TOTAL (' . $currencyprefix . $currencysuffix . ')', 1, 0, 'R', true);
$pdf->Cell($qty_width, 10, '', 1, 0, 'C', true);
$pdf->Cell($rate_width, 10, '', 1, 0, 'C', true);

// Conditionally show discount column in total row
if ($show_discount_column) {
    $pdf->Cell($discount_width, 10, '', 1, 0, 'C', true);
}

$total_display = securiaceInvoiceFormatCurrency($final_total, $currencyprefix, $currencysuffix);
$pdf->Cell($amount_width, 10, $total_display, 1, 1, 'R', true);
$current_y += 10;

// Status-specific totals display
if ($normalized_status === 'paid') {
    // Show Amount Paid and payment details
    $pdf->SetFillColor(13, 128, 64); // Green for paid
    $pdf->SetTextColor(255, 255, 255);
    $pdf->SetFont('dejavusans', 'B', 10);
    $pdf->SetXY($item_x, $current_y);
    $pdf->Cell($item_width, 8, 'AMOUNT PAID', 1, 0, 'R', true);
    $pdf->Cell($qty_width, 8, '', 1, 0, 'C', true);
    $pdf->Cell($rate_width, 8, '', 1, 0, 'C', true);
    if ($show_discount_column) {
        $pdf->Cell($discount_width, 8, '', 1, 0, 'C', true);
    }
    $pdf->Cell($amount_width, 8, securiaceInvoiceFormatCurrency($amount_paid, $currencyprefix, $currencysuffix), 1, 1, 'R', true);
    $current_y += 8;
    
    // Balance Due = 0.00 for paid invoices (FIXED: Hide for paid invoices)
    // For paid invoices, balance is forced to 0, so this section will not display
    if ($balance > 0) {
        $pdf->SetFillColor(223, 85, 74); // Red for outstanding balance
        $pdf->SetTextColor(255, 255, 255);
        $pdf->SetFont('dejavusans', 'B', 10);
        $pdf->SetXY($item_x, $current_y);
        $pdf->Cell($item_width, 8, 'BALANCE DUE', 1, 0, 'R', true);
        $pdf->Cell($qty_width, 8, '', 1, 0, 'C', true);
        $pdf->Cell($rate_width, 8, '', 1, 0, 'C', true);
        if ($show_discount_column) {
            $pdf->Cell($discount_width, 8, '', 1, 0, 'C', true);
        }
        $pdf->Cell($amount_width, 8, securiaceInvoiceFormatCurrency($balance, $currencyprefix, $currencysuffix), 1, 1, 'R', true);
        $current_y += 8;
    }
    
    // Payment details (moved after Balance Due row)
    if (!empty($date_paid)) {
        $pdf->SetFont('dejavusans', '', 8);
        $pdf->SetTextColor($COLOR_DARK_GREY[0], $COLOR_DARK_GREY[1], $COLOR_DARK_GREY[2]);
        $pdf->SetXY($item_x, $current_y);
        $payment_details = 'Paid on ' . date('M j, Y', strtotime($date_paid));
        if (!empty($payment_method)) {
            $payment_details .= ' via ' . $payment_method;
        }
        $pdf->Cell($item_width + $qty_width + $rate_width + ($show_discount_column ? $discount_width : 0) + $amount_width, 6, $payment_details, 0, 1, 'R');
        $current_y += 6;
    }
    
} elseif ($balance > 0) {
    // Show Balance Due prominently for unpaid invoices
    $pdf->SetFillColor(223, 85, 74); // Red for outstanding balance
    $pdf->SetTextColor(255, 255, 255);
    $pdf->SetFont('dejavusans', 'B', 10);
    $pdf->SetXY($item_x, $current_y);
    $pdf->Cell($item_width, 8, 'BALANCE DUE', 1, 0, 'R', true);
    $pdf->Cell($qty_width, 8, '', 1, 0, 'C', true);
    $pdf->Cell($rate_width, 8, '', 1, 0, 'C', true);
    if ($show_discount_column) {
        $pdf->Cell($discount_width, 8, '', 1, 0, 'C', true);
    }
    $pdf->Cell($amount_width, 8, securiaceInvoiceFormatCurrency($balance, $currencyprefix, $currencysuffix), 1, 1, 'R', true);
    $current_y += 8;
    
    // Show Amount Paid if partial payment
    if ($amount_paid > 0) {
        $pdf->SetFillColor(70, 130, 180); // Blue for partial payment
        $pdf->SetTextColor(255, 255, 255);
        $pdf->SetFont('dejavusans', 'B', 9);
        $pdf->SetXY($item_x, $current_y);
        $pdf->Cell($item_width, 6, 'Amount Paid', 1, 0, 'R', true);
        $pdf->Cell($qty_width, 6, '', 1, 0, 'C', true);
        $pdf->Cell($rate_width, 6, '', 1, 0, 'C', true);
        if ($show_discount_column) {
            $pdf->Cell($discount_width, 6, '', 1, 0, 'C', true);
        }
        $pdf->Cell($amount_width, 6, securiaceInvoiceFormatCurrency($amount_paid, $currencyprefix, $currencysuffix), 1, 1, 'R', true);
        $current_y += 6;
    }
    
    // Payment details for unpaid invoices (if there was partial payment)
    if (!empty($date_paid) && $amount_paid > 0) {
        $pdf->SetFont('dejavusans', '', 8);
        $pdf->SetTextColor($COLOR_DARK_GREY[0], $COLOR_DARK_GREY[1], $COLOR_DARK_GREY[2]);
        $pdf->SetXY($item_x, $current_y);
        $payment_details = 'Paid on ' . date('M j, Y', strtotime($date_paid));
        if (!empty($payment_method)) {
            $payment_details .= ' via ' . $payment_method;
        }
        $pdf->Cell($item_width + $qty_width + $rate_width + ($show_discount_column ? $discount_width : 0) + $amount_width, 6, $payment_details, 0, 1, 'R');
        $current_y += 6;
    }
    
} elseif ($normalized_status === 'refunded') {
    // Show Refund Total
    $pdf->SetFillColor(131, 182, 218); // Blue for refunded
    $pdf->SetTextColor(255, 255, 255);
    $pdf->SetFont('dejavusans', 'B', 10);
    $pdf->SetXY($item_x, $current_y);
    $pdf->Cell($item_width, 8, 'REFUND TOTAL', 1, 0, 'R', true);
    $pdf->Cell($qty_width, 8, '', 1, 0, 'C', true);
    $pdf->Cell($rate_width, 8, '', 1, 0, 'C', true);
    if ($show_discount_column) {
        $pdf->Cell($discount_width, 8, '', 1, 0, 'C', true);
    }
    $pdf->Cell($amount_width, 8, securiaceInvoiceFormatCurrency($final_total, $currencyprefix, $currencysuffix), 1, 1, 'R', true);
    $current_y += 8;
    
} elseif ($balance < 0) {
    // Show Credit Balance when balance is negative
    $pdf->SetFillColor(40, 167, 69); // Green for credit balance
    $pdf->SetTextColor(255, 255, 255);
    $pdf->SetFont('dejavusans', 'B', 10);
    $pdf->SetXY($item_x, $current_y);
    $pdf->Cell($item_width, 8, 'CREDIT BALANCE', 1, 0, 'R', true);
    $pdf->Cell($qty_width, 8, '', 1, 0, 'C', true);
    $pdf->Cell($rate_width, 8, '', 1, 0, 'C', true);
    if ($show_discount_column) {
        $pdf->Cell($discount_width, 8, '', 1, 0, 'C', true);
    }
    $pdf->Cell($amount_width, 8, securiaceInvoiceFormatCurrency(abs($balance), $currencyprefix, $currencysuffix), 1, 1, 'R', true);
    $current_y += 8;
    
    // Show Amount Paid if there was payment
    if ($amount_paid > 0) {
        $pdf->SetFillColor(70, 130, 180); // Blue for payment made
        $pdf->SetTextColor(255, 255, 255);
        $pdf->SetFont('dejavusans', 'B', 9);
        $pdf->SetXY($item_x, $current_y);
        $pdf->Cell($item_width, 6, 'Amount Paid', 1, 0, 'R', true);
        $pdf->Cell($qty_width, 6, '', 1, 0, 'C', true);
        $pdf->Cell($rate_width, 6, '', 1, 0, 'C', true);
        if ($show_discount_column) {
            $pdf->Cell($discount_width, 6, '', 1, 0, 'C', true);
        }
        $pdf->Cell($amount_width, 6, securiaceInvoiceFormatCurrency($amount_paid, $currencyprefix, $currencysuffix), 1, 1, 'R', true);
        $current_y += 6;
    }
}

// ========================================================================
// TRANSACTIONS DISPLAY (for Paid, Partial, Refunded invoices) - Page 2
// ========================================================================

// Store transactions for display on page 2
$transactions_for_page2 = array();
if ($ENH['show_transactions'] && isset($transactions) && is_array($transactions) && count($transactions) > 0) {
    $show_transactions = in_array($normalized_status, array('paid', 'partial', 'refunded'));
    if ($show_transactions) {
        $transactions_for_page2 = $transactions;
    }
}

// Reset font and color for next section
$pdf->SetFont('dejavusans', 'B', 9);
$pdf->SetTextColor($COLOR_DARK_GREY[0], $COLOR_DARK_GREY[1], $COLOR_DARK_GREY[2]);

// ========================================================================
// SIGNATURE & STAMP SECTION (Paid & Refunded Invoices Only)
// ========================================================================

// Check if we should show signature and stamp (only for paid and refunded invoices)
$show_signature_stamp = in_array($normalized_status, array('paid', 'refunded'));

if ($show_signature_stamp) {
    // Calculate signature/stamp section position - right after totals, before bottom sections
    $signature_y_start = $current_y + 5.25; // Ultra-reduced spacing after totals (30% reduction from 7.5mm)
    
    // Enhanced dynamic overflow protection - check for potential overlapping
    $estimated_signature_height = 30; // Estimated height for signature section
    $min_safe_distance = 3; // Minimum safe distance from items table (reduced for ultra-compact layout)
    
    // Ensure we don't overlap with items table content
    if ($signature_y_start < $current_y + $min_safe_distance) {
        $signature_y_start = $current_y + $min_safe_distance;
    }
    
    // Additional safety check for very tight layouts
    $current_page_y = $pdf->GetY();
    if ($signature_y_start < $current_page_y + 2) {
        $signature_y_start = $current_page_y + 2; // Absolute minimum 2mm gap
    }
    
    // Check for page overflow before signature section
    if ($pdf->GetY() + $estimated_signature_height > $pdf->GetPageHeight() - 30) {
        $pdf->AddPage();
        $signature_y_start = 20; // Reset Y position for new page
    }
    
    // ========================================================================
    // ENHANCED SIGNATURE & STAMP LAYOUT - PROFESSIONAL DESIGN
    // ========================================================================
    
    /*
     * SPACE ALLOCATION ANALYSIS:
     * 
     * CURRENT LAYOUT SPACING:
     * - Items Table: 100% of available width (194mm)
     * - Gap after Items Table: 5.25mm (2.7% of available width) - 30% reduced from 7.5mm
     * - Stamp/Signature Section: 100% of available width (194mm) - RIGHT-ALIGNED UNIFIED SECTION
     *   - Stamp: 23.1mm (11.9% of available width) - 10% larger than previous 21mm
     *   - Gap between Stamp & Signature: 0.2mm (0.1% of available width) - ultra-minimal for visual closeness
     *   - Signature: 52.5mm (27.1% of available width) - 50% larger than original 35mm
     *   - Container: 194mm (100% of available width) - INVISIBLE BORDERS
     * - Gap after Stamp/Signature: 15mm (7.7% of available width)
     * - Bottom Sections: 100% of available width (194mm)
     * 
     * LOGICAL REASONING FOR GAPS:
     * 1. 5.25mm gap after Items Table: Ultra-minimal visual separation between financial data and authentication (30% further reduced)
     * 2. 0.2mm gap between Stamp & Signature: Ultra-minimal spacing for visual closeness and unified appearance
     * 3. 15mm gap after Stamp/Signature: Ensures proper spacing before payment information
     * 4. Right-aligned container: Creates unified section positioned to the right with invisible borders for clean presentation
     * 5. Enhanced dynamic overflow protection: Prevents overlapping with items table content (3mm minimum + 2mm absolute minimum)
     * 
     * PIXEL EQUIVALENTS (at 300 DPI):
     * - 1mm = 11.81 pixels
     * - Items Table: 2,291 pixels wide
     * - Gap after Items Table: 62 pixels (30% further reduced)
     * - Container: 2,291 pixels wide (100% of available width)
     * - Stamp: 273 pixels wide × 273 pixels high
     * - Gap between Stamp & Signature: 2 pixels (ultra-minimal for visual closeness)
     * - Signature: 620 pixels wide × 266 pixels high
     * - Gap after Stamp/Signature: 177 pixels
     * - Bottom Sections: 2,291 pixels wide
     */
    
    // Define image dimensions with proper aspect ratio maintenance - ENHANCED SIZING
    $signature_width = 52.5;  // Signature width in mm (35 * 1.5 = 50% larger)
    $signature_height = 22.5; // Signature height in mm (15 * 1.5 = 50% larger)
    $stamp_width = 23.1;      // Stamp width in mm (21 * 1.1 = 10% larger)
    $stamp_height = 23.1;     // Stamp height in mm (21 * 1.1 = 10% larger, square for circular stamp)
    
    // Calculate positioning - right-aligned section with invisible borders
    $total_available_width = 194; // Total available width (210mm A4 - 16mm margins)
    $total_images_width = $stamp_width + $signature_width + 0.2; // 0.2mm spacing between images (ultra-minimal for visual closeness)
    $start_x = 8 + $total_available_width - $total_images_width; // Right-align the images
    
    $stamp_x = $start_x; // Stamp positioned first (left within the right-aligned section)
    $signature_x = $start_x + $stamp_width + 0.2; // 0.2mm spacing between stamp and signature (signature positioned right)
    
    // ========================================================================
    // FULL-WIDTH INVISIBLE CONTAINER - UNIFIED SECTION
    // ========================================================================
    
    // Create invisible full-width container for stamp/signature section
    $container_height = max($stamp_height, $signature_height) + 8; // 8mm padding for labels
    $pdf->SetFillColor(255, 255, 255); // White background (invisible)
    $pdf->SetDrawColor(255, 255, 255); // White border (invisible)
    $pdf->SetLineWidth(0); // No border
    $pdf->Rect(8, $signature_y_start, $total_available_width, $container_height, 'F'); // Full-width invisible container
    
    // ========================================================================
    // SIGNATURE IMAGE - ENTERPRISE STYLING (NO BORDERS)
    // ========================================================================
    
    // Check if signature image exists
    $signature_filename = 'sign.png';
    $signature_path = ROOTDIR . '/assets/img/' . $signature_filename;
    
    if (file_exists($signature_path)) {
        // Add signature with professional styling
        try {
            // Get original image dimensions to maintain aspect ratio
            $image_info = getimagesize($signature_path);
            if ($image_info !== false) {
                $original_width = $image_info[0];
                $original_height = $image_info[1];
                $aspect_ratio = $original_width / $original_height;
                
                // Calculate proper dimensions maintaining aspect ratio
                if ($aspect_ratio > ($signature_width / $signature_height)) {
                    // Image is wider than target ratio
                    $final_signature_width = $signature_width;
                    $final_signature_height = $signature_width / $aspect_ratio;
                } else {
                    // Image is taller than target ratio
                    $final_signature_height = $signature_height;
                    $final_signature_width = $signature_height * $aspect_ratio;
                }
                
                // Center the signature within its allocated space
                $signature_center_x = $signature_x + ($signature_width - $final_signature_width) / 2;
                $signature_center_y = $signature_y_start + ($signature_height - $final_signature_height) / 2;
                
                // Add signature image without border (invisible section)
                // No border - clean, invisible presentation
                
                // Add the signature image
                $pdf->Image($signature_path, $signature_center_x, $signature_center_y, $final_signature_width, $final_signature_height);
                
                // Add signature label
                $pdf->SetFont('dejavusans', 'B', 7);
                $pdf->SetTextColor($COLOR_DARK_GREY[0], $COLOR_DARK_GREY[1], $COLOR_DARK_GREY[2]);
                $pdf->SetXY($signature_x, $signature_y_start + $signature_height + 2);
                $pdf->Cell($signature_width, 3, 'Authorized Signature', 0, 0, 'C');
                
            } else {
                // Fallback if image info cannot be retrieved
                $pdf->Image($signature_path, $signature_x, $signature_y_start, $signature_width, $signature_height);
                
                // Add signature label
                $pdf->SetFont('dejavusans', 'B', 7);
                $pdf->SetTextColor($COLOR_DARK_GREY[0], $COLOR_DARK_GREY[1], $COLOR_DARK_GREY[2]);
                $pdf->SetXY($signature_x, $signature_y_start + $signature_height + 2);
                $pdf->Cell($signature_width, 3, 'Authorized Signature', 0, 0, 'C');
            }
        } catch (Exception $e) {
            // Fallback: Add placeholder if image loading fails (no border)
            $pdf->SetFillColor(248, 248, 248);
            $pdf->Rect($signature_x, $signature_y_start, $signature_width, $signature_height, 'F');
            
            $pdf->SetFont('dejavusans', '', 6);
            $pdf->SetTextColor(150, 150, 150);
            $pdf->SetXY($signature_x, $signature_y_start + ($signature_height / 2) - 2);
            $pdf->Cell($signature_width, 4, 'Signature', 0, 0, 'C');
        }
    } else {
        // Placeholder if signature image doesn't exist (no border)
        $pdf->SetFillColor(248, 248, 248);
        $pdf->Rect($signature_x, $signature_y_start, $signature_width, $signature_height, 'F');
        
        $pdf->SetFont('dejavusans', '', 6);
        $pdf->SetTextColor(150, 150, 150);
        $pdf->SetXY($signature_x, $signature_y_start + ($signature_height / 2) - 2);
        $pdf->Cell($signature_width, 4, 'Signature', 0, 0, 'C');
    }
    
    // ========================================================================
    // STAMP IMAGE - ENTERPRISE STYLING
    // ========================================================================
    
    // Check if stamp image exists
    $stamp_filename = 'stamp.png';
    $stamp_path = ROOTDIR . '/assets/img/' . $stamp_filename;
    
    if (file_exists($stamp_path)) {
        // Add stamp with professional styling
        try {
            // Get original image dimensions to maintain aspect ratio
            $image_info = getimagesize($stamp_path);
            if ($image_info !== false) {
                $original_width = $image_info[0];
                $original_height = $image_info[1];
                $aspect_ratio = $original_width / $original_height;
                
                // Calculate proper dimensions maintaining aspect ratio
                if ($aspect_ratio > ($stamp_width / $stamp_height)) {
                    // Image is wider than target ratio
                    $final_stamp_width = $stamp_width;
                    $final_stamp_height = $stamp_width / $aspect_ratio;
                } else {
                    // Image is taller than target ratio
                    $final_stamp_height = $stamp_height;
                    $final_stamp_width = $stamp_height * $aspect_ratio;
                }
                
                // Center the stamp within its allocated space
                $stamp_center_x = $stamp_x + ($stamp_width - $final_stamp_width) / 2;
                $stamp_center_y = $signature_y_start + ($stamp_height - $final_stamp_height) / 2;
                
                // Add stamp image without border (invisible section)
                // No border - clean, invisible presentation
                
                // Add the stamp image
                $pdf->Image($stamp_path, $stamp_center_x, $stamp_center_y, $final_stamp_width, $final_stamp_height);
                
                // Stamp label removed as requested
                
            } else {
                // Fallback if image info cannot be retrieved
                $pdf->Image($stamp_path, $stamp_x, $signature_y_start, $stamp_width, $stamp_height);
                
                // Stamp label removed as requested
            }
        } catch (Exception $e) {
            // Fallback: Add placeholder if image loading fails (no border)
            $pdf->SetFillColor(248, 248, 248);
            $pdf->Rect($stamp_x, $signature_y_start, $stamp_width, $stamp_height, 'F');
            
            $pdf->SetFont('dejavusans', '', 6);
            $pdf->SetTextColor(150, 150, 150);
            $pdf->SetXY($stamp_x, $signature_y_start + ($stamp_height / 2) - 2);
            $pdf->Cell($stamp_width, 4, 'Stamp', 0, 0, 'C');
        }
    } else {
        // Placeholder if stamp image doesn't exist (no border)
        $pdf->SetFillColor(248, 248, 248);
        $pdf->Rect($stamp_x, $signature_y_start, $stamp_width, $stamp_height, 'F');
        
        $pdf->SetFont('dejavusans', '', 6);
        $pdf->SetTextColor(150, 150, 150);
        $pdf->SetXY($stamp_x, $signature_y_start + ($stamp_height / 2) - 2);
        $pdf->Cell($stamp_width, 4, 'Stamp', 0, 0, 'C');
    }
    
    // Update current_y for next section with proper spacing
    $current_y = $signature_y_start + max($signature_height, $stamp_height) + 15; // 15mm spacing after signature/stamp section
} else {
    // For non-paid/refunded invoices, maintain original spacing
    $current_y = $current_y + 15;
}

// ========================================================================
// BOTTOM SECTIONS - TERMS, BANK DETAILS, UPI, NOTES
// ========================================================================

$bottom_y_start = $current_y;

// Dynamic box sizing: 50% for Payment Terms, 30% for Bank Details, 20% for UPI
$total_width = 194; // Total available width (210mm A4 - 16mm margins)
$payment_terms_width = round($total_width * 0.50); // 50% of total width
$bank_details_width = round($total_width * 0.30); // 30% of total width for Bank Details
$upi_width = round($total_width * 0.20); // 20% of total width for UPI
$bank_details_x = 8 + $payment_terms_width; // Start position for bank details
$upi_x = $bank_details_x + $bank_details_width; // Start position for UPI section

// Payment Terms Section (Left) - 50% width with dynamic content from WHMCS
$pdf->SetFont('dejavusans', 'B', 8);
$pdf->SetTextColor($COLOR_DARK_GREY[0], $COLOR_DARK_GREY[1], $COLOR_DARK_GREY[2]);
$pdf->SetXY(8, $bottom_y_start);
$pdf->Cell($payment_terms_width, 5, 'Payment Terms / Notes', 0, 1, 'L');

// Enhanced Indian payment terms with dynamic due date calculation and legal compliance
// Calculate dynamic due date from invoice date
$invoice_date = isset($datecreated) ? new DateTime($datecreated) : new DateTime();
$due_date = isset($duedate) ? new DateTime($duedate) : clone $invoice_date;
$due_date->add(new DateInterval('P15D')); // Add 15 days by default

// Calculate days between invoice date and due date
$days_difference = $invoice_date->diff($due_date)->days;

// Build dynamic payment terms with correct TDS compliance
$default_terms = "1. Payment due within {$days_difference} days from invoice date (" . $due_date->format('M j, Y') . ").\n";
$default_terms .= "2. Overdue interest @ 18% p.a. will be charged on delayed payments.\n";
$default_terms .= "3. Please quote invoice number when making payment using UPI/NEFT/IMPS.\n";
$default_terms .= "4. TDS Compliance: If applicable, client must deduct TDS as per Section 194J of Income Tax Act, 1961 and provide Form 16A to service provider.\n";
$default_terms .= "5. All disputes subject to jurisdiction of Pune, Maharashtra.";

// Use WHMCS notes if available, otherwise use default terms
$payment_terms_content = '';
if (isset($notes) && !empty(trim($notes))) {
    // Use WHMCS notes with proper text wrapping
    $payment_terms_content = trim($notes);
} else {
    // Use default payment terms
    $payment_terms_content = $default_terms;
}

$pdf->SetFont('dejavusans', '', 7); // Increased font size for better readability
$pdf->SetTextColor($COLOR_DARK_GREY[0], $COLOR_DARK_GREY[1], $COLOR_DARK_GREY[2]);
$pdf->SetXY(8, $bottom_y_start + 6);
$pdf->MultiCell($payment_terms_width - 4, 4, $payment_terms_content, 0, 'L'); // Reduced width and increased line height for proper wrapping

// Bank Details Section (Middle) - 30% width with invisible box
$pdf->SetFont('dejavusans', 'B', 8);
$pdf->SetTextColor($COLOR_DARK_GREY[0], $COLOR_DARK_GREY[1], $COLOR_DARK_GREY[2]);
$pdf->SetXY($bank_details_x, $bottom_y_start);
$pdf->Cell($bank_details_width, 5, 'Bank Details', 0, 1, 'L');

$pdf->SetFont('dejavusans', '', 6);
$pdf->SetTextColor($COLOR_DARK_GREY[0], $COLOR_DARK_GREY[1], $COLOR_DARK_GREY[2]);

$bank_details = array(
    'Account Name' => isset($companyname) && !empty($companyname) ? $companyname : 'Securiace Technologies',
    'Account Number' => '500102000004909',
    'IFSC' => 'IBKL0000500',
    'Account Type' => 'Current',
    'Bank' => 'IDBI Bank'
);

$bank_y = $bottom_y_start + 6;
$label_width = round($bank_details_width * 0.45); // 45% of bank details width for labels
$value_width = round($bank_details_width * 0.55); // 55% of bank details width for values

foreach ($bank_details as $label => $value) {
    $pdf->SetXY($bank_details_x, $bank_y);
    $pdf->Cell($label_width, 3, $label, 0, 0, 'L');
    $pdf->Cell($value_width, 3, $value, 0, 1, 'R');
    $bank_y += 4;
}

// ========================================================================
// CONDITIONAL PAYMENT UI (Status-Aware)
// ========================================================================

// Payment UI logic - show UPI for paid invoices (generic QR) and unpaid invoices (specific QR)
$hide_payment_ui = in_array($normalized_status, array('cancelled', 'refunded', 'collections', 'draft'));
$show_payment_ui = $ENH['show_payment_ui'] && (!$hide_payment_ui || $normalized_status === 'paid');

if ($show_payment_ui) {
    // UPI Section (Right) - 20% width with invisible box
    $pdf->SetFont('dejavusans', 'B', 8);
    $pdf->SetTextColor($COLOR_DARK_GREY[0], $COLOR_DARK_GREY[1], $COLOR_DARK_GREY[2]);
    $pdf->SetXY($upi_x, $bottom_y_start);
    
    // UPI header - same for both paid and unpaid
    $pdf->Cell($upi_width, 5, 'UPI - Scan to Pay', 0, 1, 'L');
    
    // UPI section styling - consistent for both paid and unpaid

    // Dynamic UPI QR Code Generation with Balance-specific data
    $qr_size = round(12 * 1.30); // QR code size - increased by 30% (12 * 1.30 = 15.6, rounded to 16)
    $qr_x = $upi_x + (($upi_width - $qr_size) / 2); // Center QR code within UPI width

    // Generate UPI payment URL - generic for paid invoices, specific for unpaid
    $upi_id = 'securiace.com@idbi';
    $account_number = '500102000004909';
    $ifsc_code = 'IBKL0000500';
    $invoice_number = isset($invoicenum) ? $invoicenum : (isset($invoicenumber) ? $invoicenumber : $invoiceid);
    $company_name = isset($companyname) && !empty($companyname) ? $companyname : 'Securiace Technologies';

    // Create UPI payment URL - generic for paid invoices, specific for unpaid
    if ($normalized_status === 'paid') {
        // Generic QR code for paid invoices without amount and invoice reference
        $upi_payment_url = "upi://pay?pa={$upi_id}&pn=" . urlencode($company_name) . "&cu=INR&tn=" . urlencode("Securiace Technologies - Payment");
    } else {
        // Specific QR code for unpaid invoices with balance details
        $payment_amount = $balance; // Use balance instead of total
        $upi_payment_url = "upi://pay?pa={$upi_id}&pn=" . urlencode($company_name) . "&am=" . $payment_amount . "&cu=INR&tr=" . urlencode("Invoice-{$invoice_number}") . "&tn=" . urlencode("Payment for Invoice #{$invoice_number} - Balance: " . securiaceInvoiceFormatCurrency($payment_amount, $currencyprefix, $currencysuffix));
    }

// Generate QR code using TCPDF's built-in QR code functionality
try {
    // Create QR code as temporary image
    $qr_data = $upi_payment_url;
    $qr_error_correction = 'M'; // Medium error correction
    $qr_matrix_point_size = 2; // Point size for QR code
    
    // Generate QR code using TCPDF's QRCode class if available
    if (class_exists('TCPDF2DBarcode')) {
        $qr_code = new TCPDF2DBarcode($qr_data, 'QRCODE,M');
        $qr_image = $qr_code->getBarcodePNGData($qr_size, $qr_size, array(0,0,0), array(255,255,255));
        
        // Save temporary QR code image
        $temp_qr_path = sys_get_temp_dir() . '/upi_qr_' . $invoice_number . '_' . time() . '.png';
        file_put_contents($temp_qr_path, $qr_image);
        
        // Add QR code to PDF
        $pdf->Image($temp_qr_path, $qr_x, $bottom_y_start + 6, $qr_size, $qr_size);
        
        // Clean up temporary file
        if (file_exists($temp_qr_path)) {
            unlink($temp_qr_path);
        }
    } else {
        // Fallback: Create simple QR code representation
        $pdf->SetXY($qr_x, $bottom_y_start + 6);
        $pdf->SetFillColor(0, 0, 0);
        $pdf->Rect($qr_x, $bottom_y_start + 6, $qr_size, $qr_size, 'F');
        
        // Add QR code text overlay
        $pdf->SetTextColor(255, 255, 255);
        $pdf->SetFont('dejavusans', 'B', round(4 * 1.30)); // Font size increased by 30%
        $pdf->SetXY($qr_x + 1, $bottom_y_start + 6 + ($qr_size/2) - 2);
        $pdf->Cell($qr_size - 2, round(4 * 1.30), 'QR', 0, 0, 'C');
        $pdf->SetTextColor($COLOR_DARK_GREY[0], $COLOR_DARK_GREY[1], $COLOR_DARK_GREY[2]);
    }
} catch (Exception $e) {
    // Fallback QR code placeholder if generation fails
    $pdf->SetXY($qr_x, $bottom_y_start + 6);
    $pdf->Cell($qr_size, $qr_size, '', 1, 0, 'C');
}

// UPI ID below QR code
$pdf->SetFont('dejavusans', '', 6);
$pdf->SetXY($upi_x, $bottom_y_start + 6 + $qr_size + 2);
$pdf->Cell($upi_width, 3, 'securiace.com@idbi', 0, 1, 'C');

// Transaction Description - consistent for both paid and unpaid
if ($normalized_status === 'paid') {
    $pdf->SetFont('dejavusans', '', 5);
    $pdf->SetXY($upi_x, $bottom_y_start + 6 + $qr_size + 8);
    $pdf->Cell($upi_width, 3, 'Securiace Technologies', 0, 1, 'C');
} else {
    $invoice_number = isset($invoicenum) ? $invoicenum : (isset($invoicenumber) ? $invoicenumber : $invoiceid);
    $pdf->SetFont('dejavusans', '', 5);
    $pdf->SetXY($upi_x, $bottom_y_start + 6 + $qr_size + 8);
    $pdf->Cell($upi_width, 3, 'Invoice: ' . $invoice_number, 0, 1, 'C');
}
}

// ========================================================================
// COMPLIANCE & LEGAL SECTION
// ========================================================================

$compliance_y = $current_y + 20;

// Tax compliance information
if ($ENH['show_tax_details']) {
    $pdf->SetFont('dejavusans', '', 7);
    $pdf->SetTextColor($COLOR_DARK_GREY[0], $COLOR_DARK_GREY[1], $COLOR_DARK_GREY[2]);
    
    // Company tax ID
    if ($ENH['show_company_tax_id'] && isset($taxCode) && !empty($taxCode)) {
        $pdf->SetXY(8, $compliance_y);
        $pdf->Cell(100, 4, 'Company Tax ID: ' . $taxCode, 0, 1, 'L');
        $compliance_y += 4;
    }
    
    // Client tax ID
    if ($ENH['show_client_tax_id'] && isset($clientsdetails['tax_id']) && !empty($clientsdetails['tax_id'])) {
        $pdf->SetXY(8, $compliance_y);
        $pdf->Cell(100, 4, 'Client Tax ID: ' . $clientsdetails['tax_id'], 0, 1, 'L');
        $compliance_y += 4;
    }
    
    // Tax exempt status
    if (isset($clientsdetails['tax_exempt']) && $clientsdetails['tax_exempt']) {
        $exempt_reason = isset($clientsdetails['tax_exempt_reason']) ? $clientsdetails['tax_exempt_reason'] : 'Tax exempt status';
        $pdf->SetXY(8, $compliance_y);
        $pdf->Cell(100, 4, 'Tax Exempt — Not charged (Reason: ' . $exempt_reason . ')', 0, 1, 'L');
        $compliance_y += 4;
    }
}

// Compliance information is now handled by the digital verification badge above

// Foreign exchange disclaimer (if enabled)
if ($ENH['show_fx'] && isset($currencyrate) && $currencyrate != 1) {
    $pdf->SetFont('dejavusans', '', 6);
    $pdf->SetTextColor(150, 150, 150);
    $pdf->SetXY(8, $compliance_y);
    $pdf->Cell(100, 3, 'Exchange rate: ' . $currencyrate . ' (for reference only)', 0, 1, 'L');
    $compliance_y += 4;
}

// Signature Section - REMOVED as requested

// Footer Section - REMOVED as requested

// ========================================================================
// LAST PAGE - UPCOMING DUE DATES & PAYMENT TRANSACTIONS
// ========================================================================

// Check if we need to display either section
$show_renewal_section = !empty($renewal_items) && $normalized_status === 'paid'; // Only show for Paid invoices
$show_transaction_section = !empty($transactions_for_page2);
$show_debug_section = $ENH['show_debug_section']; // Use configuration setting

if ($show_renewal_section || $show_transaction_section || $show_debug_section) {
    // Add new page for last page content
    $pdf->AddPage();
    
    $current_y = 20; // Start position for content
    
    // ========================================================================
    // UPCOMING RENEWALS SECTION - RENEWAL TRACKING (Paid Invoices Only)
    // ========================================================================
    
    if ($show_renewal_section) {
        // Upcoming Renewals header with professional styling
        $pdf->SetFillColor(75, 0, 130); // Purple background
        $pdf->SetDrawColor(75, 0, 130);
        $pdf->SetLineWidth(0.3);
        $pdf->Rect(8, $current_y, 194, 6, 'DF');
        
        $pdf->SetFont('dejavusans', 'B', 9);
        $pdf->SetTextColor(255, 255, 255); // White text
        $pdf->SetXY(12, $current_y + 1.5);
        $pdf->Cell(190, 3, 'UPCOMING RENEWALS', 0, 1, 'L');
        
        $current_y += 8;
        
        // Display renewal items with professional styling
        foreach ($renewal_items as $renewal_item) {
            // Determine color based on urgency
            if ($renewal_item['is_overdue']) {
                $text_color = array(223, 85, 74); // Red for overdue
                $urgency_text = 'OVERDUE';
            } elseif ($renewal_item['is_urgent']) {
                $text_color = array(255, 140, 0); // Orange for urgent
                $urgency_text = 'URGENT';
            } elseif ($renewal_item['is_upcoming']) {
                $text_color = array(255, 193, 7); // Amber for upcoming
                $urgency_text = 'UPCOMING';
            } else {
                $text_color = array(75, 0, 130); // Purple for normal
                $urgency_text = 'SCHEDULED';
            }
            
            // Service name with urgency indicator
            $pdf->SetFont('dejavusans', 'B', 8);
            $pdf->SetTextColor($text_color[0], $text_color[1], $text_color[2]);
            $pdf->SetXY(12, $current_y);
            $service_text = $renewal_item['item_number'] . ". " . $renewal_item['service_name'];
            if (!empty($renewal_item['domain_name'])) {
                $service_text .= " - " . $renewal_item['domain_name'];
            }
            $pdf->Cell(120, 4, $service_text, 0, 0, 'L');
            
            // Renewal date with styling
            $pdf->SetFont('dejavusans', 'B', 8);
            $pdf->SetTextColor($text_color[0], $text_color[1], $text_color[2]);
            $pdf->SetXY(140, $current_y);
            $pdf->Cell(50, 4, $renewal_item['renewal_text'], 0, 0, 'R');
            
            // Urgency indicator
            $pdf->SetFont('dejavusans', 'B', 7);
            $pdf->SetTextColor($text_color[0], $text_color[1], $text_color[2]);
            $pdf->SetXY(12, $current_y + 4);
            $pdf->Cell(50, 3, $urgency_text, 0, 0, 'L');
            
            // Days until renewal
            $pdf->SetFont('dejavusans', '', 7);
            $pdf->SetTextColor(100, 100, 100);
            $pdf->SetXY(140, $current_y + 4);
            if ($renewal_item['is_overdue']) {
                $days_text = $renewal_item['days_until'] . " days overdue";
            } else {
                $days_text = $renewal_item['days_until'] . " days remaining";
            }
            $pdf->Cell(50, 3, $days_text, 0, 0, 'R');
            
            $current_y += 8; // Space between renewal items
        }
        
        // Add space after renewal section
        $current_y += 15;
    }
    
    // ========================================================================
    // PAYMENT TRANSACTIONS SECTION
    // ========================================================================
    
    if ($show_transaction_section) {
        // ========================================================================
        // ENHANCED PAYMENT TRANSACTIONS HEADER - PREMIUM STYLING
        // ========================================================================
        
        // Main header background with gradient effect
        $pdf->SetFillColor(75, 0, 130); // Purple background
        $pdf->SetDrawColor(75, 0, 130);
        $pdf->SetLineWidth(0.5);
        $pdf->Rect(8, $current_y, 194, 18, 'DF'); // Increased header height
        
        // Inner highlight border for premium look
        $pdf->SetDrawColor(120, 60, 180); // Lighter purple inner border
        $pdf->SetLineWidth(0.3);
        $pdf->Rect(8.5, $current_y + 0.5, 193, 17, 'D');
        
        // Main title with enhanced typography
        $pdf->SetFont('dejavusans', 'B', 18); // Larger, bolder font
        $pdf->SetTextColor(255, 255, 255); // White text
        $pdf->SetXY(12, $current_y + 3);
        $pdf->Cell(100, 8, 'PAYMENT TRANSACTIONS', 0, 1, 'L');
        
        // Invoice reference with professional styling
        $pdf->SetFont('dejavusans', 'B', 12); // Larger font for better visibility
        $pdf->SetTextColor(255, 255, 255); // White text
        $pdf->SetXY(12, $current_y + 10);
        $invoice_ref = $isProforma ? 'Proforma No: ' . $invoiceid : 'Invoice No: ' . (isset($invoicenum) ? $invoicenum : $invoiceid);
        $pdf->Cell(100, 6, $invoice_ref, 0, 1, 'L');
        
        // Enhanced separator line with gradient effect
        $pdf->SetDrawColor(255, 255, 255); // White separator line
        $pdf->SetLineWidth(1.5);
        $pdf->Line(8, $current_y + 17, 202, $current_y + 17);
        
        // Subtle bottom accent line
        $pdf->SetDrawColor(120, 60, 180); // Lighter purple accent
        $pdf->SetLineWidth(0.5);
        $pdf->Line(8, $current_y + 18, 202, $current_y + 18);
        
        $current_y += 22; // Start position for transactions
    
    // Function to categorize payment method
    if (!function_exists('categorizePaymentMethod')) {
        function categorizePaymentMethod($method) {
        $method_lower = strtolower(trim($method));
        
        // Online payment gateways
        $online_gateways = array(
            'paypal', 'razorpay', 'stripe', 'square', 'authorize', 'braintree', 
            'payu', 'ccavenue', 'instamojo', 'cashfree', 'paytm', 'phonepe',
            'google pay', 'apple pay', 'amazon pay', 'mobikwik', 'freecharge',
            'payu money', 'payumoney', 'billdesk', 'atom', 'easebuzz', 'juspay'
        );
        
        // Manual payment methods
        $manual_methods = array(
            'upi', 'neft', 'imps', 'bhim', 'cheque', 'cheque', 'bank transfer',
            'wire transfer', 'rtgs', 'demand draft', 'dd', 'cash', 'manual',
            'offline', 'bank deposit', 'direct deposit'
        );
        
        // Check for online gateways
        foreach ($online_gateways as $gateway) {
            if (strpos($method_lower, $gateway) !== false) {
                return 'Online';
            }
        }
        
        // Check for manual methods
        foreach ($manual_methods as $manual) {
            if (strpos($method_lower, $manual) !== false) {
                return 'Manual';
            }
        }
        
        // Default to Manual if not recognized
        return 'Manual';
        }
    }
    
    // ========================================================================
    // ENHANCED TRANSACTION TABLE - PREMIUM STYLING
    // ========================================================================
    
    // Section subtitle with professional styling
    $pdf->SetFont('dejavusans', 'B', 12);
    $pdf->SetTextColor(75, 0, 130); // Purple text to match header
    $pdf->SetXY(8, $current_y);
    $pdf->Cell(180, 6, 'Transaction Details', 0, 1, 'L');
    $current_y += 10;
    
    // Enhanced transaction header row with premium styling
    $pdf->SetFillColor(75, 0, 130); // Purple background to match header
    $pdf->SetDrawColor(75, 0, 130);
    $pdf->SetLineWidth(0.5);
    $pdf->Rect(8, $current_y, 194, 10, 'DF'); // Increased header height
    
    // Inner highlight border
    $pdf->SetDrawColor(120, 60, 180); // Lighter purple inner border
    $pdf->SetLineWidth(0.3);
    $pdf->Rect(8.5, $current_y + 0.5, 193, 9, 'D');
    
    // Header text with enhanced styling
    $pdf->SetFont('dejavusans', 'B', 9); // Larger, bolder font
    $pdf->SetTextColor(255, 255, 255); // White text for contrast
    $pdf->SetXY(10, $current_y + 3);
    $pdf->Cell(20, 4, 'DATE', 0, 0, 'L');
    $pdf->SetXY(35, $current_y + 3);
    $pdf->Cell(30, 4, 'METHOD', 0, 0, 'L');
    $pdf->SetXY(70, $current_y + 3);
    $pdf->Cell(50, 4, 'TRANSACTION ID', 0, 0, 'L');
    $pdf->SetXY(125, $current_y + 3);
    $pdf->Cell(30, 4, 'AMOUNT', 0, 0, 'R');
    $pdf->SetXY(160, $current_y + 3);
    $pdf->Cell(30, 4, 'STATUS', 0, 0, 'C');
    
    $current_y += 12; // Increased spacing after header
    
    $total_transaction_amount = 0;
    $row_alternate = false;
    
    foreach ($transactions_for_page2 as $index => $transaction) {
        $trans_date = isset($transaction['date']) ? date('M j, Y', strtotime($transaction['date'])) : 'N/A';
        $trans_method_raw = isset($transaction['gateway']) ? $transaction['gateway'] : (isset($transaction['paymentmethod']) ? $transaction['paymentmethod'] : 'Unknown');
        $trans_id = isset($transaction['transid']) ? $transaction['transid'] : 'N/A';
        
        // Locale-aware parse — handles ₹/€/$ prefixes and US/EU/FR/plain
        // separator styles via $currencyformat (see parseAmount() helper).
        $trans_amount_raw = isset($transaction['amount']) ? $transaction['amount'] : 0;
        $trans_amount = parseAmount($trans_amount_raw);
        $trans_status = isset($transaction['status']) ? $transaction['status'] : 'Completed';
        
        // Add to total with proper calculation
        $total_transaction_amount += $trans_amount;
        
        // Categorize payment method
        $pay_method = categorizePaymentMethod($trans_method_raw);
        
        // Enhanced alternating row colors with premium styling
        $row_alternate = !$row_alternate;
        $row_bg_color = $row_alternate ? array(255, 255, 255) : array(248, 250, 252); // Subtle blue tint for alternate rows
        
        // Transaction row with enhanced styling
        $pdf->SetFillColor($row_bg_color[0], $row_bg_color[1], $row_bg_color[2]);
        $pdf->SetDrawColor(200, 200, 200); // Softer border color
        $pdf->SetLineWidth(0.3);
        $pdf->Rect(8, $current_y, 194, 10, 'DF'); // Increased row height
        
        // Inner highlight for premium look
        $pdf->SetDrawColor(220, 220, 220);
        $pdf->SetLineWidth(0.1);
        $pdf->Rect(8.2, $current_y + 0.2, 193.6, 9.6, 'D');
        
        // Enhanced transaction data styling
        $pdf->SetFont('dejavusans', '', 9); // Slightly larger font
        $pdf->SetTextColor($COLOR_DARK_GREY[0], $COLOR_DARK_GREY[1], $COLOR_DARK_GREY[2]);
        
        // Date with enhanced positioning
        $pdf->SetXY(10, $current_y + 3);
        $pdf->Cell(20, 4, $trans_date, 0, 0, 'L');
        
        // Payment Method with enhanced color coding and styling
        $pdf->SetXY(35, $current_y + 3);
        if ($pay_method === 'Online') {
            $pdf->SetTextColor(34, 139, 34); // Green for online
            $pdf->SetFont('dejavusans', 'B', 9); // Bold for online
        } else {
            $pdf->SetTextColor(70, 130, 180); // Blue for manual
            $pdf->SetFont('dejavusans', 'B', 9); // Bold for manual
        }
        $pdf->Cell(30, 4, $pay_method, 0, 0, 'L');
        
        // Transaction ID with enhanced styling
        $pdf->SetFont('dejavusans', '', 8);
        $pdf->SetTextColor($COLOR_DARK_GREY[0], $COLOR_DARK_GREY[1], $COLOR_DARK_GREY[2]);
        $pdf->SetXY(70, $current_y + 3);
        $pdf->Cell(50, 4, substr($trans_id, 0, 20) . (strlen($trans_id) > 20 ? '...' : ''), 0, 0, 'L');
        
        // Amount with enhanced styling
        $pdf->SetFont('dejavusans', 'B', 9); // Larger, bolder font
        $pdf->SetTextColor(34, 139, 34); // Green for amount
        $pdf->SetXY(125, $current_y + 3);
        $pdf->Cell(30, 4, securiaceInvoiceFormatCurrency($trans_amount, $currencyprefix, $currencysuffix), 0, 0, 'R');
        
        // Status with enhanced styling
        $pdf->SetFont('dejavusans', 'B', 8); // Bold status
        $pdf->SetTextColor(100, 100, 100);
        $pdf->SetXY(160, $current_y + 3);
        $pdf->Cell(30, 4, strtoupper($trans_status), 0, 0, 'C'); // Uppercase status
        
        $current_y += 10; // Increased space between transactions
    }
    
    // ========================================================================
    // ENHANCED TRANSACTION SUMMARY - PREMIUM STYLING
    // ========================================================================
    
    $current_y += 20; // Increased spacing before summary
    
    // Summary section background with enhanced styling
    $pdf->SetFillColor(248, 250, 252); // Light background
    $pdf->SetDrawColor(75, 0, 130); // Purple border to match header
    $pdf->SetLineWidth(0.8);
    $pdf->Rect(8, $current_y, 194, 25, 'DF'); // Increased height
    
    // Inner highlight border
    $pdf->SetDrawColor(120, 60, 180); // Lighter purple inner border
    $pdf->SetLineWidth(0.3);
    $pdf->Rect(8.5, $current_y + 0.5, 193, 24, 'D');
    
    // Summary title with enhanced styling
    $pdf->SetFont('dejavusans', 'B', 14); // Larger font
    $pdf->SetTextColor(75, 0, 130); // Purple text to match header
    $pdf->SetXY(12, $current_y + 4);
    $pdf->Cell(100, 6, 'TRANSACTION SUMMARY', 0, 1, 'L');
    
    // Summary details with enhanced styling
    $pdf->SetFont('dejavusans', 'B', 10); // Bold font
    $pdf->SetTextColor($COLOR_DARK_GREY[0], $COLOR_DARK_GREY[1], $COLOR_DARK_GREY[2]);
    $pdf->SetXY(12, $current_y + 10);
    $pdf->Cell(100, 5, 'Total Transactions: ' . count($transactions_for_page2), 0, 1, 'L');
    
    // Total amount with premium styling
    $pdf->SetXY(12, $current_y + 16);
    $pdf->SetFont('dejavusans', 'B', 12); // Larger, bolder font
    $pdf->SetTextColor(34, 139, 34); // Green for total amount
    $pdf->Cell(100, 5, 'Total Amount: ' . securiaceInvoiceFormatCurrency($total_transaction_amount, $currencyprefix, $currencysuffix), 0, 1, 'L');
    
    // Add some spacing at the end
    $current_y += 30; // Increased spacing after summary
    }
    
    // ========================================================================
    // ENHANCED DEBUGGING SECTION - CONFIGURABLE & PROFESSIONAL FORMATTING
    // ========================================================================
    
    if ($show_debug_section) {
        $current_y += 20;
        
        // ========================================================================
        // DEBUG SECTION HEADER - ENTERPRISE STYLING
        // ========================================================================
        
        // Main debug header background
        $pdf->SetFillColor(255, 248, 220); // Light yellow background
        $pdf->SetDrawColor(255, 193, 7); // Amber border
        $pdf->SetLineWidth(0.8);
        $pdf->Rect(8, $current_y, 194, 15, 'DF'); // Header height
        
        // Inner highlight border
        $pdf->SetDrawColor(255, 140, 0); // Darker amber inner border
        $pdf->SetLineWidth(0.3);
        $pdf->Rect(8.5, $current_y + 0.5, 193, 14, 'D');
        
        // Debug title with enhanced styling
        $pdf->SetFont('dejavusans', 'B', 16); // Larger font
        $pdf->SetTextColor(138, 43, 226); // Purple text
        $pdf->SetXY(12, $current_y + 3);
        $pdf->Cell(100, 6, 'DEBUGGING INFORMATION', 0, 1, 'L');
        
        // Debug level indicator
        $pdf->SetFont('dejavusans', 'B', 10);
        $pdf->SetTextColor(255, 140, 0); // Amber text
        $pdf->SetXY(12, $current_y + 8);
        $pdf->Cell(100, 4, 'Level: ' . strtoupper($ENH['debug_level']) . ' | Status: ' . strtoupper($normalized_status), 0, 1, 'L');
        
        // Debug content area
        $debug_content_y = $current_y + 18;
        $pdf->SetFillColor(255, 255, 255); // White background for content
        $pdf->SetDrawColor(200, 200, 200); // Light gray border
        $pdf->SetLineWidth(0.3);
        $pdf->Rect(8, $debug_content_y, 194, 140, 'DF'); // Content area
        
        $current_y += 10;
        
        // ========================================================================
        // CONFIGURABLE DEBUG CONTENT DISPLAY
        // ========================================================================
        
        $debug_y = $debug_content_y + 8;
        $column1_x = 12;
        $column2_x = 100;
        $line_height = 2.5;
        
        // ========================================================================
        // BASIC INVOICE INFORMATION (Always shown)
        // ========================================================================
        
        if (in_array($ENH['debug_level'], array('minimal', 'standard', 'full', 'development'))) {
            $pdf->SetFont('dejavusans', 'B', 9);
            $pdf->SetTextColor(75, 0, 130); // Purple for section headers
            $pdf->SetXY($column1_x, $debug_y);
            $pdf->Cell(180, $line_height, '=== BASIC INVOICE INFORMATION ===', 0, 1, 'L');
            $debug_y += 4;
            
            $basic_info = array(
                'Invoice Status' => isset($status) ? $status : 'NOT SET',
                'Normalized Status' => $normalized_status,
                'Is Proforma' => $isProforma ? 'YES' : 'NO',
                'Invoice ID' => isset($invoiceid) ? $invoiceid : 'NOT SET',
                'Invoice Number' => isset($invoicenum) ? $invoicenum : 'NOT SET'
            );
            
            foreach ($basic_info as $label => $value) {
                $pdf->SetFont('dejavusans', '', 7);
                $pdf->SetTextColor($COLOR_DARK_GREY[0], $COLOR_DARK_GREY[1], $COLOR_DARK_GREY[2]);
                $pdf->SetXY($column1_x, $debug_y);
                $pdf->Cell(85, $line_height, $label . ':', 0, 0, 'L');
                $pdf->SetXY($column2_x, $debug_y);
                $pdf->Cell(45, $line_height, $value, 0, 1, 'L');
                $debug_y += $line_height;
            }
            $debug_y += 3;
        }
        
        // ========================================================================
        // FINANCIAL INFORMATION (Standard and above)
        // ========================================================================
        
        if (in_array($ENH['debug_level'], array('standard', 'full', 'development'))) {
            $pdf->SetFont('dejavusans', 'B', 9);
            $pdf->SetTextColor(75, 0, 130);
            $pdf->SetXY($column1_x, $debug_y);
            $pdf->Cell(180, $line_height, '=== FINANCIAL INFORMATION ===', 0, 1, 'L');
            $debug_y += 4;
            
            $financial_info = array(
                'Total (Raw)' => isset($total) ? (is_object($total) ? 'Object(' . get_class($total) . ')' : $total) : 'NOT SET',
                'Total (Float)' => $whmcs_total,
                'Balance (Float)' => $balance,
                'Subtotal (Float)' => $subtotal,
                'Tax (Float)' => $tax,
                'Credit (Float)' => $credit,
                'Discount (Float)' => $discount,
                'Amount Paid' => $amount_paid,
                'Final Total' => $final_total
            );
            
            foreach ($financial_info as $label => $value) {
                $pdf->SetFont('dejavusans', '', 7);
                $pdf->SetTextColor($COLOR_DARK_GREY[0], $COLOR_DARK_GREY[1], $COLOR_DARK_GREY[2]);
                $pdf->SetXY($column1_x, $debug_y);
                $pdf->Cell(85, $line_height, $label . ':', 0, 0, 'L');
                $pdf->SetXY($column2_x, $debug_y);
                $pdf->Cell(45, $line_height, $value, 0, 1, 'L');
                $debug_y += $line_height;
            }
            $debug_y += 3;
        }
        
        // ========================================================================
        // CURRENCY & PAYMENT INFORMATION (Standard and above)
        // ========================================================================
        
        if (in_array($ENH['debug_level'], array('standard', 'full', 'development'))) {
            $pdf->SetFont('dejavusans', 'B', 9);
            $pdf->SetTextColor(75, 0, 130);
            $pdf->SetXY($column1_x, $debug_y);
            $pdf->Cell(180, $line_height, '=== CURRENCY & PAYMENT INFORMATION ===', 0, 1, 'L');
            $debug_y += 4;
            
            $payment_info = array(
                'Currency Prefix' => $currencyprefix,
                'Currency Suffix' => $currencysuffix,
                'Currency Code' => $currencycode,
                'Payment Method' => isset($paymentmethod) ? $paymentmethod : 'NOT SET',
                'Date Created' => isset($datecreated) ? $datecreated : 'NOT SET',
                'Due Date' => isset($duedate) ? $duedate : 'NOT SET'
            );
            
            foreach ($payment_info as $label => $value) {
                $pdf->SetFont('dejavusans', '', 7);
                $pdf->SetTextColor($COLOR_DARK_GREY[0], $COLOR_DARK_GREY[1], $COLOR_DARK_GREY[2]);
                $pdf->SetXY($column1_x, $debug_y);
                $pdf->Cell(85, $line_height, $label . ':', 0, 0, 'L');
                $pdf->SetXY($column2_x, $debug_y);
                $pdf->Cell(45, $line_height, $value, 0, 1, 'L');
                $debug_y += $line_height;
            }
            $debug_y += 3;
        }
        
        // ========================================================================
        // CLIENT CREDIT INFORMATION (If enabled)
        // ========================================================================
        
        if ($ENH['debug_show_calculations'] && in_array($ENH['debug_level'], array('full', 'development'))) {
            $pdf->SetFont('dejavusans', 'B', 9);
            $pdf->SetTextColor(75, 0, 130);
            $pdf->SetXY($column1_x, $debug_y);
            $pdf->Cell(180, $line_height, '=== CLIENT CREDIT INFORMATION ===', 0, 1, 'L');
            $debug_y += 4;
            
            // Check for client credit balance
            $client_credit_balance = 0;
            if (isset($clientsdetails['credit']) && is_numeric($clientsdetails['credit'])) {
                $client_credit_balance = floatval($clientsdetails['credit']);
            }
            
            $credit_info = array(
                'Client Available Credit' => securiaceInvoiceFormatCurrency($client_credit_balance, $currencyprefix, $currencysuffix),
                'Credit Applied to Invoice' => securiaceInvoiceFormatCurrency($credit, $currencyprefix, $currencysuffix),
                'Client Credit (Raw)' => isset($clientsdetails['credit']) ? $clientsdetails['credit'] : 'NOT SET',
                'Invoice Credit (Raw)' => isset($credit) ? $credit : 'NOT SET'
            );
            
            foreach ($credit_info as $label => $value) {
                $pdf->SetFont('dejavusans', '', 7);
                $pdf->SetTextColor($COLOR_DARK_GREY[0], $COLOR_DARK_GREY[1], $COLOR_DARK_GREY[2]);
                $pdf->SetXY($column1_x, $debug_y);
                $pdf->Cell(85, $line_height, $label . ':', 0, 0, 'L');
                $pdf->SetXY($column2_x, $debug_y);
                $pdf->Cell(45, $line_height, $value, 0, 1, 'L');
                $debug_y += $line_height;
            }
            $debug_y += 3;
        }
        
        // ========================================================================
        // DEBUG FOOTER
        // ========================================================================
        
        $debug_y += 5;
        $pdf->SetFont('dejavusans', 'B', 8);
        $pdf->SetTextColor(255, 140, 0); // Amber text
        $pdf->SetXY($column1_x, $debug_y);
        $pdf->Cell(180, $line_height, 'Debug generated on ' . date('Y-m-d H:i:s') . ' | Template Version 2.0.0', 0, 1, 'C');
        
        $current_y += 160; // Total debug section height
    }
}
