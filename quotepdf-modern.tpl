<?php

/**
 * Securiace Modern WHMCS PDF Quote Template
 *
 * Target: WHMCS 8.x and 9.x, PHP 7.4 through 8.3, TCPDF.
 * Install as quotepdf.tpl in the active WHMCS system theme.
 *
 * The template intentionally presents the validity date instead of the WHMCS
 * stage. On first email delivery WHMCS 8.x generates the attachment before it
 * updates the quote to Delivered, so a stage badge can be factually stale.
 */

$securiaceQuoteDefaults = array(
    'company_email' => '',
    'company_phone' => '',
    'company_pan' => '',
    'company_msme' => '',
    'jurisdiction' => 'Pune, Maharashtra',
    'acceptance_note' => 'Acceptance confirms the scope and commercial terms shown in this quote.',
);
$securiaceQuoteConfig = $securiaceQuoteDefaults;
$securiaceQuoteConfigPath = defined('ROOTDIR')
    ? ROOTDIR . '/includes/securiace-invoice-config.php'
    : '';
if ($securiaceQuoteConfigPath !== '' && is_readable($securiaceQuoteConfigPath)) {
    $securiaceQuoteLoadedConfig = include $securiaceQuoteConfigPath;
    if (is_array($securiaceQuoteLoadedConfig)) {
        $securiaceQuoteConfig = array_replace($securiaceQuoteConfig, $securiaceQuoteLoadedConfig);
    }
}
if (isset($securiaceQuoteTemplateConfig) && is_array($securiaceQuoteTemplateConfig)) {
    $securiaceQuoteConfig = array_replace($securiaceQuoteConfig, $securiaceQuoteTemplateConfig);
}
foreach (array_keys($securiaceQuoteDefaults) as $securiaceQuoteConfigKey) {
    $securiaceQuoteConfigValue = isset($securiaceQuoteConfig[$securiaceQuoteConfigKey])
        ? $securiaceQuoteConfig[$securiaceQuoteConfigKey]
        : '';
    if (!is_scalar($securiaceQuoteConfigValue)
        && !(is_object($securiaceQuoteConfigValue) && method_exists($securiaceQuoteConfigValue, '__toString'))
    ) {
        $securiaceQuoteConfigValue = '';
    }
    $securiaceQuoteConfig[$securiaceQuoteConfigKey] = trim((string) $securiaceQuoteConfigValue);
}

$securiaceQuotePlainMultiline = static function ($value) {
    $text = (string) $value;
    $text = preg_replace('/<\s*br\s*\/?>/iu', "\n", $text);
    $text = preg_replace('/<\/?(p|div|li|h[1-6])\b[^>]*>/iu', "\n", $text);
    $text = strip_tags($text);
    $text = html_entity_decode($text, ENT_QUOTES | ENT_HTML5, 'UTF-8');
    $text = str_replace(array("\r\n", "\r"), "\n", $text);
    $lines = array();
    foreach (explode("\n", $text) as $line) {
        $line = preg_replace('/[\t ]+/u', ' ', $line);
        $line = trim($line === null ? '' : $line);
        if ($line !== '' || (!empty($lines) && end($lines) !== '')) {
            $lines[] = $line;
        }
    }
    return trim(implode("\n", $lines));
};
$securiaceQuotePlainText = static function ($value) use ($securiaceQuotePlainMultiline) {
    $text = $securiaceQuotePlainMultiline($value);
    $text = preg_replace('/\s+/u', ' ', $text);
    return trim($text === null ? '' : $text);
};
$securiaceQuoteEscape = static function ($value) {
    return htmlspecialchars((string) $value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
};
$securiaceQuoteRichHtml = static function ($value) {
    $html = (string) $value;
    $html = preg_replace('/<!--.*?-->/su', '', $html);
    do {
        $previous = $html;
        $html = preg_replace(
            '#<\s*(script|style|iframe|object|embed|svg|math|form|button|textarea|select|video|audio)\b[^>]*>.*?<\s*/\s*\1\s*>#isu',
            '',
            $html
        );
    } while ($html !== $previous);
    $html = preg_replace(
        '#<\s*(script|style|iframe|object|embed|svg|math|form|input|button|textarea|select|video|audio)\b[^>]*/?\s*>#isu',
        '',
        $html
    );
    $html = strip_tags($html, '<p><br><strong><b><em><i><u><ul><ol><li><h1><h2><h3>');
    $html = preg_replace_callback(
        '/<\s*(\/?)\s*(p|br|strong|b|em|i|u|ul|ol|li|h1|h2|h3)\b[^>]*>/iu',
        static function ($match) {
            $slash = $match[1] === '/' ? '/' : '';
            $tag = strtolower($match[2]);
            if ($tag === 'br') {
                return '<br />';
            }
            return '<' . $slash . $tag . '>';
        },
        $html
    );
    return trim($html === null ? '' : $html);
};
$securiaceQuoteTruncate = static function ($value, $maxLength) {
    $value = (string) $value;
    if (function_exists('mb_strlen') && function_exists('mb_substr')) {
        return mb_strlen($value, 'UTF-8') > $maxLength
            ? mb_substr($value, 0, $maxLength - 1, 'UTF-8') . '…'
            : $value;
    }
    return strlen($value) > $maxLength
        ? substr($value, 0, $maxLength - 3) . '...'
        : $value;
};
$securiaceQuoteIsUsableImage = static function ($path) {
    return is_string($path) && $path !== '' && is_readable($path) && @getimagesize($path) !== false;
};

$securiaceQuoteCurrency = isset($GLOBALS['currency']) && is_array($GLOBALS['currency'])
    ? $GLOBALS['currency']
    : array();
$securiaceQuoteCurrencyCode = !empty($securiaceQuoteCurrency['code'])
    ? strtoupper(trim((string) $securiaceQuoteCurrency['code']))
    : '';
$securiaceQuoteFormatMoney = static function ($value) use ($securiaceQuoteCurrency) {
    if (is_object($value) && method_exists($value, '__toString')) {
        $value = (string) $value;
    }
    if (is_string($value) && preg_match('/[^0-9\s.,()\-]/u', $value)) {
        return trim($value);
    }
    $numeric = is_numeric($value) ? (float) $value : 0.0;
    if (function_exists('formatCurrency')) {
        try {
            return (string) formatCurrency($numeric);
        } catch (Throwable $exception) {
            // Fall through to a deterministic local formatter for fixtures.
        }
    }
    $prefix = isset($securiaceQuoteCurrency['prefix']) ? trim((string) $securiaceQuoteCurrency['prefix']) : '';
    $suffix = isset($securiaceQuoteCurrency['suffix']) ? trim((string) $securiaceQuoteCurrency['suffix']) : '';
    return ($prefix !== '' ? $prefix . ' ' : '')
        . number_format($numeric, 2, '.', ',')
        . ($suffix !== '' ? ' ' . $suffix : '');
};

$securiaceQuoteFont = isset($pdfFont) && trim((string) $pdfFont) !== ''
    ? trim((string) $pdfFont)
    : 'dejavusans';
$securiaceQuoteNumber = isset($quotenumber) && trim((string) $quotenumber) !== ''
    ? trim((string) $quotenumber)
    : '—';
$securiaceQuoteSubject = isset($subject) && trim((string) $subject) !== ''
    ? $securiaceQuotePlainText($subject)
    : 'Commercial proposal';
$securiaceQuoteProposalHtml = isset($proposal) ? $securiaceQuoteRichHtml($proposal) : '';
$securiaceQuoteProposalPlain = isset($proposal) ? $securiaceQuotePlainMultiline($proposal) : '';
$securiaceQuoteItems = isset($lineitems) && is_array($lineitems) ? $lineitems : array();
if (!isset($clientsdetails) || !is_array($clientsdetails)) {
    $clientsdetails = array();
}

$securiaceQuoteCompanyName = isset($companyname) && trim((string) $companyname) !== ''
    ? trim((string) $companyname)
    : 'Securiace Technologies';
$securiaceQuoteCompanyLines = array();
if (isset($companyaddress) && is_array($companyaddress)) {
    foreach ($companyaddress as $addressLine) {
        if (is_scalar($addressLine)
            || (is_object($addressLine) && method_exists($addressLine, '__toString'))
        ) {
            $addressLine = trim((string) $addressLine);
            if ($addressLine !== '') {
                $securiaceQuoteCompanyLines[] = $addressLine;
            }
        }
    }
}
foreach (array('company_email', 'company_phone') as $companyConfigKey) {
    if ($securiaceQuoteConfig[$companyConfigKey] !== '') {
        $securiaceQuoteCompanyLines[] = $securiaceQuoteConfig[$companyConfigKey];
    }
}
if ($securiaceQuoteConfig['company_pan'] !== '') {
    $securiaceQuoteCompanyLines[] = 'PAN: ' . $securiaceQuoteConfig['company_pan'];
}
if ($securiaceQuoteConfig['company_msme'] !== '') {
    $securiaceQuoteCompanyLines[] = 'MSME: ' . $securiaceQuoteConfig['company_msme'];
}

$securiaceQuoteClientName = !empty($clientsdetails['companyname'])
    ? trim((string) $clientsdetails['companyname'])
    : trim(
        (isset($clientsdetails['firstname']) ? $clientsdetails['firstname'] : '')
        . ' '
        . (isset($clientsdetails['lastname']) ? $clientsdetails['lastname'] : '')
    );
if ($securiaceQuoteClientName === '') {
    $securiaceQuoteClientName = 'Prospective client';
}
$securiaceQuoteClientLines = array();
if (!empty($clientsdetails['companyname'])) {
    $contactName = trim(
        (isset($clientsdetails['firstname']) ? $clientsdetails['firstname'] : '')
        . ' '
        . (isset($clientsdetails['lastname']) ? $clientsdetails['lastname'] : '')
    );
    if ($contactName !== '') {
        $securiaceQuoteClientLines[] = 'Attn: ' . $contactName;
    }
}
foreach (array('address1', 'address2') as $addressKey) {
    if (!empty($clientsdetails[$addressKey])) {
        $securiaceQuoteClientLines[] = trim((string) $clientsdetails[$addressKey]);
    }
}
$clientCity = array();
foreach (array('city', 'state', 'postcode') as $cityKey) {
    if (!empty($clientsdetails[$cityKey])) {
        $clientCity[] = trim((string) $clientsdetails[$cityKey]);
    }
}
if (!empty($clientCity)) {
    $securiaceQuoteClientLines[] = implode(', ', $clientCity);
}
foreach (array('country', 'email', 'phonenumber') as $clientKey) {
    if (!empty($clientsdetails[$clientKey])) {
        $securiaceQuoteClientLines[] = trim((string) $clientsdetails[$clientKey]);
    }
}

$securiaceQuoteBrand = array(79, 11, 112);
$securiaceQuoteBrandDark = array(50, 16, 68);
$securiaceQuoteBrandSoft = array(245, 240, 247);
$securiaceQuoteInk = array(32, 28, 36);
$securiaceQuoteMuted = array(109, 102, 114);
$securiaceQuoteLine = array(221, 215, 225);
$securiaceQuoteSurface = array(248, 246, 248);
$securiaceQuotePaper = array(255, 254, 253);

$securiaceQuoteStartPage = $pdf->getPage();
$securiaceQuoteMargin = 14.0;
$securiaceQuoteTopMargin = 20.0;
$securiaceQuoteBottomMargin = 15.0;
$pdf->SetMargins($securiaceQuoteMargin, $securiaceQuoteTopMargin, $securiaceQuoteMargin);
$pdf->SetAutoPageBreak(true, $securiaceQuoteBottomMargin);
$pdf->SetFont($securiaceQuoteFont, '', 8);
$securiaceQuotePageWidth = $pdf->getPageWidth();
$securiaceQuotePageHeight = $pdf->getPageHeight();
$securiaceQuoteUsableWidth = $securiaceQuotePageWidth - ($securiaceQuoteMargin * 2);

$securiaceQuotePaintPage = static function () use (
    $pdf,
    $securiaceQuotePaper,
    $securiaceQuotePageWidth,
    $securiaceQuotePageHeight
) {
    $pdf->SetFillColor($securiaceQuotePaper[0], $securiaceQuotePaper[1], $securiaceQuotePaper[2]);
    $pdf->Rect(0, 0, $securiaceQuotePageWidth, $securiaceQuotePageHeight, 'F');
};
$securiaceQuotePaintPage();
$securiaceQuoteDrawCard = static function ($x, $y, $width, $height, $fill, $line, $radius = 2.65, $corners = '1111') use ($pdf) {
    $pdf->SetFillColor($fill[0], $fill[1], $fill[2]);
    $pdf->SetDrawColor($line[0], $line[1], $line[2]);
    $pdf->SetLineWidth(0.25);
    if (method_exists($pdf, 'RoundedRect')) {
        $pdf->RoundedRect($x, $y, $width, $height, min($radius, $height / 2), $corners, 'DF');
    } else {
        $pdf->Rect($x, $y, $width, $height, 'DF');
    }
};
$securiaceQuoteDrawLabel = static function ($label, $x, $y, $width) use ($pdf, $securiaceQuoteFont, $securiaceQuoteBrand) {
    $pdf->SetFont($securiaceQuoteFont, 'B', 6.5);
    $pdf->SetTextColor($securiaceQuoteBrand[0], $securiaceQuoteBrand[1], $securiaceQuoteBrand[2]);
    $pdf->SetXY($x, $y);
    $pdf->Cell($width, 3.5, strtoupper((string) $label), 0, 0, 'L');
};
$securiaceQuoteEnsureSpace = static function ($height) use (
    $pdf,
    $securiaceQuotePageHeight,
    $securiaceQuoteBottomMargin,
    $securiaceQuoteTopMargin,
    $securiaceQuotePaintPage
) {
    if ($pdf->GetY() + $height > $securiaceQuotePageHeight - $securiaceQuoteBottomMargin) {
        $pdf->AddPage();
        $securiaceQuotePaintPage();
        $pdf->SetY($securiaceQuoteTopMargin);
        return true;
    }
    return false;
};

// Header and quote identity.
$securiaceQuoteHeaderY = $securiaceQuoteTopMargin;
$securiaceQuoteLogoPath = '';
if (defined('ROOTDIR')) {
    foreach (array('logo.png', 'logo.jpg', 'logo.jpeg') as $logoFile) {
        $candidateLogo = ROOTDIR . '/assets/img/' . $logoFile;
        if ($securiaceQuoteIsUsableImage($candidateLogo)) {
            $securiaceQuoteLogoPath = $candidateLogo;
            break;
        }
    }
}
if ($securiaceQuoteLogoPath !== '') {
    $pdf->Image($securiaceQuoteLogoPath, $securiaceQuoteMargin, $securiaceQuoteHeaderY, 42, 0, '', '', '', false, 300);
} else {
    $pdf->SetFont($securiaceQuoteFont, 'B', 17);
    $pdf->SetTextColor($securiaceQuoteInk[0], $securiaceQuoteInk[1], $securiaceQuoteInk[2]);
    $pdf->SetXY($securiaceQuoteMargin, $securiaceQuoteHeaderY + 1);
    $pdf->Cell(100, 7, $securiaceQuoteCompanyName, 0, 1, 'L');
}
$pdf->SetFont($securiaceQuoteFont, 'B', 6.5);
$pdf->SetTextColor($securiaceQuoteBrand[0], $securiaceQuoteBrand[1], $securiaceQuoteBrand[2]);
$pdf->SetXY($securiaceQuotePageWidth - $securiaceQuoteMargin - 68, $securiaceQuoteHeaderY);
$pdf->Cell(68, 4, 'COMMERCIAL PROPOSAL', 0, 1, 'R');
$pdf->SetFont($securiaceQuoteFont, 'B', 22);
$pdf->SetTextColor($securiaceQuoteInk[0], $securiaceQuoteInk[1], $securiaceQuoteInk[2]);
$pdf->SetX($securiaceQuotePageWidth - $securiaceQuoteMargin - 68);
$pdf->Cell(68, 8, 'Quote', 0, 1, 'R');
$validityLabel = 'VALID UNTIL ' . (isset($validuntil) && trim((string) $validuntil) !== '' ? trim((string) $validuntil) : '—');
$validityWidth = max(38, min(68, strlen($validityLabel) * 1.55 + 10));
$validityX = $securiaceQuotePageWidth - $securiaceQuoteMargin - $validityWidth;
$securiaceQuoteDrawCard($validityX, $securiaceQuoteHeaderY + 14, $validityWidth, 7, $securiaceQuoteBrandSoft, $securiaceQuoteLine, 3.5);
$pdf->SetFont($securiaceQuoteFont, 'B', 6.5);
$pdf->SetTextColor($securiaceQuoteBrand[0], $securiaceQuoteBrand[1], $securiaceQuoteBrand[2]);
$pdf->SetXY($validityX, $securiaceQuoteHeaderY + 15.3);
$pdf->Cell($validityWidth, 4, $validityLabel, 0, 1, 'C');
$ruleY = $securiaceQuoteHeaderY + 26;
$pdf->SetDrawColor($securiaceQuoteBrand[0], $securiaceQuoteBrand[1], $securiaceQuoteBrand[2]);
$pdf->SetLineWidth(0.35);
$pdf->Line($securiaceQuoteMargin, $ruleY, $securiaceQuotePageWidth - $securiaceQuoteMargin, $ruleY);

$metaY = $ruleY + 5;
$metaWidth = ($securiaceQuoteUsableWidth - 72) / 2;
$quoteMeta = array(
    array('Quote number', $securiaceQuoteNumber),
    array('Issued', isset($datecreated) ? $datecreated : '—'),
);
foreach ($quoteMeta as $metaIndex => $metaItem) {
    $metaX = $securiaceQuoteMargin + ($metaIndex * $metaWidth);
    $pdf->SetFont($securiaceQuoteFont, '', 6.5);
    $pdf->SetTextColor($securiaceQuoteMuted[0], $securiaceQuoteMuted[1], $securiaceQuoteMuted[2]);
    $pdf->SetXY($metaX, $metaY);
    $pdf->Cell($metaWidth - 3, 3.5, $metaItem[0], 0, 1, 'L');
    $pdf->SetFont($securiaceQuoteFont, 'B', 8);
    $pdf->SetTextColor($securiaceQuoteInk[0], $securiaceQuoteInk[1], $securiaceQuoteInk[2]);
    $pdf->SetX($metaX);
    $pdf->Cell($metaWidth - 3, 4.5, (string) $metaItem[1], 0, 1, 'L');
}
$summaryX = $securiaceQuotePageWidth - $securiaceQuoteMargin - 68;
$securiaceQuoteDrawCard($summaryX, $metaY - 1, 68, 16, $securiaceQuoteBrandSoft, $securiaceQuoteLine);
$securiaceQuoteDrawLabel('Prepared proposal', $summaryX + 4, $metaY + 1.5, 60);
$pdf->SetFont($securiaceQuoteFont, 'B', 7.3);
$pdf->SetTextColor($securiaceQuoteBrandDark[0], $securiaceQuoteBrandDark[1], $securiaceQuoteBrandDark[2]);
$pdf->SetXY($summaryX + 4, $metaY + 6);
$pdf->MultiCell(60, 3.6, $securiaceQuoteTruncate($securiaceQuoteSubject, 64), 0, 'L');
$pdf->SetY($metaY + 20);

// Recipient and issuer cards.
$partyGap = 4;
$partyWidth = ($securiaceQuoteUsableWidth - $partyGap) / 2;
$partyY = $pdf->GetY();
$clientText = implode("\n", $securiaceQuoteClientLines);
$companyText = implode("\n", $securiaceQuoteCompanyLines);
$pdf->SetFont($securiaceQuoteFont, '', 7);
$partyHeight = max(
    35,
    16 + max(
        $pdf->getStringHeight($partyWidth - 8, $clientText),
        $pdf->getStringHeight($partyWidth - 8, $companyText)
    )
);
$securiaceQuoteDrawCard($securiaceQuoteMargin, $partyY, $partyWidth, $partyHeight, $securiaceQuotePaper, $securiaceQuoteLine);
$issuerX = $securiaceQuoteMargin + $partyWidth + $partyGap;
$securiaceQuoteDrawCard($issuerX, $partyY, $partyWidth, $partyHeight, $securiaceQuotePaper, $securiaceQuoteLine);
$pdf->SetDrawColor($securiaceQuoteBrand[0], $securiaceQuoteBrand[1], $securiaceQuoteBrand[2]);
$pdf->SetLineWidth(0.8);
$pdf->Line($securiaceQuoteMargin + 2.65, $partyY, $securiaceQuoteMargin + $partyWidth - 2.65, $partyY);
$partyColumns = array(
    array('Prepared for', $securiaceQuoteClientName, $clientText, $securiaceQuoteMargin),
    array('Prepared by', $securiaceQuoteCompanyName, $companyText, $issuerX),
);
foreach ($partyColumns as $partyColumn) {
    $partyX = $partyColumn[3];
    $securiaceQuoteDrawLabel($partyColumn[0], $partyX + 4, $partyY + 4, $partyWidth - 8);
    $pdf->SetFont($securiaceQuoteFont, 'B', 9);
    $pdf->SetTextColor($securiaceQuoteInk[0], $securiaceQuoteInk[1], $securiaceQuoteInk[2]);
    $pdf->SetXY($partyX + 4, $partyY + 8);
    $pdf->MultiCell($partyWidth - 8, 4, $partyColumn[1], 0, 'L');
    $pdf->SetFont($securiaceQuoteFont, '', 7);
    $pdf->SetTextColor($securiaceQuoteMuted[0], $securiaceQuoteMuted[1], $securiaceQuoteMuted[2]);
    $pdf->SetXY($partyX + 4, $pdf->GetY() + 1);
    $pdf->MultiCell($partyWidth - 8, 3.5, $partyColumn[2], 0, 'L');
}
$pdf->SetY($partyY + $partyHeight + 5);

// Rich proposal content. Only a conservative TCPDF-compatible tag set survives.
if ($securiaceQuoteProposalHtml !== '') {
    $securiaceQuoteDrawLabel('Proposal', $securiaceQuoteMargin, $pdf->GetY(), $securiaceQuoteUsableWidth);
    $pdf->SetFont($securiaceQuoteFont, 'B', 11);
    $pdf->SetTextColor($securiaceQuoteInk[0], $securiaceQuoteInk[1], $securiaceQuoteInk[2]);
    $pdf->SetXY($securiaceQuoteMargin, $pdf->GetY() + 3.5);
    $pdf->MultiCell($securiaceQuoteUsableWidth, 5, $securiaceQuoteSubject, 0, 'L');
    $proposalMarkup = '<div style="color:#403943;font-size:8px;line-height:1.45;">'
        . $securiaceQuoteProposalHtml
        . '</div>';
    $pdf->SetFont($securiaceQuoteFont, '', 8);
    $pdf->SetTextColor($securiaceQuoteMuted[0], $securiaceQuoteMuted[1], $securiaceQuoteMuted[2]);
    $pdf->writeHTML($proposalMarkup, true, false, true, false, '');
    $pdf->Ln(2);
}

// Quote items use their real qty, unit price, discount, and line total fields.
$securiaceQuoteEnsureSpace(24);
$securiaceQuoteDrawLabel('Commercials', $securiaceQuoteMargin, $pdf->GetY(), $securiaceQuoteUsableWidth);
$pdf->SetFont($securiaceQuoteFont, 'B', 9.5);
$pdf->SetTextColor($securiaceQuoteInk[0], $securiaceQuoteInk[1], $securiaceQuoteInk[2]);
$pdf->SetXY($securiaceQuoteMargin, $pdf->GetY() + 3.5);
$pdf->Cell($securiaceQuoteUsableWidth - 40, 4.5, 'Scope and pricing', 0, 0, 'L');
$pdf->SetFont($securiaceQuoteFont, 'B', 6);
$pdf->SetTextColor($securiaceQuoteMuted[0], $securiaceQuoteMuted[1], $securiaceQuoteMuted[2]);
$pdf->Cell(40, 4.5, 'Currency · ' . ($securiaceQuoteCurrencyCode !== '' ? $securiaceQuoteCurrencyCode : '—'), 0, 1, 'R');
$pdf->Ln(1.5);

$itemWidths = array(
    $securiaceQuoteUsableWidth * 0.46,
    $securiaceQuoteUsableWidth * 0.08,
    $securiaceQuoteUsableWidth * 0.17,
    $securiaceQuoteUsableWidth * 0.12,
    $securiaceQuoteUsableWidth * 0.17,
);
$drawItemHeader = static function () use (
    $pdf,
    $securiaceQuoteFont,
    $securiaceQuoteMargin,
    $securiaceQuoteUsableWidth,
    $securiaceQuoteBrand,
    $securiaceQuoteDrawCard,
    $itemWidths
) {
    $headerY = $pdf->GetY();
    $securiaceQuoteDrawCard($securiaceQuoteMargin, $headerY, $securiaceQuoteUsableWidth, 7, $securiaceQuoteBrand, $securiaceQuoteBrand, 2.65, '1001');
    $headers = array('DESCRIPTION', 'QTY', 'UNIT PRICE', 'DISCOUNT', 'AMOUNT');
    $pdf->SetFont($securiaceQuoteFont, 'B', 6.2);
    $pdf->SetTextColor(255, 255, 255);
    $pdf->SetXY($securiaceQuoteMargin + 3, $headerY + 1.4);
    foreach ($headers as $headerIndex => $header) {
        $width = $itemWidths[$headerIndex] - ($headerIndex === 0 || $headerIndex === 4 ? 3 : 0);
        $pdf->Cell($width, 4, $header, 0, $headerIndex === 4 ? 1 : 0, $headerIndex === 0 ? 'L' : 'R');
    }
    $pdf->SetY($headerY + 7);
};
$drawItemsContinuation = static function () use (
    $pdf,
    $securiaceQuotePaintPage,
    $securiaceQuoteTopMargin,
    $securiaceQuoteDrawLabel,
    $securiaceQuoteMargin,
    $securiaceQuoteUsableWidth,
    $securiaceQuoteFont,
    $securiaceQuoteInk,
    $securiaceQuoteMuted,
    $securiaceQuoteCurrencyCode,
    $drawItemHeader
) {
    $pdf->AddPage();
    $securiaceQuotePaintPage();
    $pdf->SetY($securiaceQuoteTopMargin);
    $securiaceQuoteDrawLabel('Commercials · continued', $securiaceQuoteMargin, $pdf->GetY(), $securiaceQuoteUsableWidth);
    $pdf->SetFont($securiaceQuoteFont, 'B', 9);
    $pdf->SetTextColor($securiaceQuoteInk[0], $securiaceQuoteInk[1], $securiaceQuoteInk[2]);
    $pdf->SetXY($securiaceQuoteMargin, $pdf->GetY() + 3.5);
    $pdf->Cell($securiaceQuoteUsableWidth - 40, 4.5, 'Scope and pricing', 0, 0, 'L');
    $pdf->SetFont($securiaceQuoteFont, 'B', 6);
    $pdf->SetTextColor($securiaceQuoteMuted[0], $securiaceQuoteMuted[1], $securiaceQuoteMuted[2]);
    $pdf->Cell(40, 4.5, 'Currency · ' . ($securiaceQuoteCurrencyCode !== '' ? $securiaceQuoteCurrencyCode : '—'), 0, 1, 'R');
    $pdf->Ln(1.5);
    $drawItemHeader();
};

$securiaceQuoteNormalizedDescriptions = array();
$preparedQuoteItems = array();
foreach ($securiaceQuoteItems as $item) {
    if (!is_array($item)) {
        continue;
    }
    $description = isset($item['description']) ? $securiaceQuotePlainMultiline($item['description']) : 'Quote item';
    $securiaceQuoteNormalizedDescriptions[] = $description;
    $parts = explode("\n", $description, 2);
    $discountValue = isset($item['discount']) && is_numeric($item['discount']) ? (float) $item['discount'] : 0.0;
    $preparedQuoteItems[] = array(
        'title' => $parts[0] !== '' ? $parts[0] : 'Quote item',
        'detail' => isset($parts[1]) ? $parts[1] : '',
        'qty' => isset($item['qty']) ? (string) $item['qty'] : '—',
        'unitprice' => $securiaceQuoteFormatMoney(isset($item['unitprice']) ? $item['unitprice'] : 0),
        'discount' => rtrim(rtrim(number_format($discountValue, 2, '.', ''), '0'), '.') . '%',
        'total' => $securiaceQuoteFormatMoney(isset($item['total']) ? $item['total'] : 0),
    );
}
$drawItemHeader();
if (empty($preparedQuoteItems)) {
    $rowY = $pdf->GetY();
    $securiaceQuoteDrawCard($securiaceQuoteMargin, $rowY, $securiaceQuoteUsableWidth, 10, $securiaceQuotePaper, $securiaceQuoteLine, 2.65, '0110');
    $pdf->SetFont($securiaceQuoteFont, '', 7);
    $pdf->SetTextColor($securiaceQuoteMuted[0], $securiaceQuoteMuted[1], $securiaceQuoteMuted[2]);
    $pdf->SetXY($securiaceQuoteMargin, $rowY + 2.4);
    $pdf->Cell($securiaceQuoteUsableWidth, 4, 'No quote items found.', 0, 1, 'C');
    $pdf->SetY($rowY + 10);
} else {
    foreach ($preparedQuoteItems as $itemIndex => $preparedItem) {
        $pdf->SetFont($securiaceQuoteFont, 'B', 7.1);
        $titleHeight = $pdf->getStringHeight($itemWidths[0] - 6, $preparedItem['title']);
        $pdf->SetFont($securiaceQuoteFont, '', 6.4);
        $detailHeight = $preparedItem['detail'] !== '' ? $pdf->getStringHeight($itemWidths[0] - 6, $preparedItem['detail']) : 0;
        $rowHeight = max(10, $titleHeight + $detailHeight + 4);
        if ($pdf->GetY() + $rowHeight > $securiaceQuotePageHeight - $securiaceQuoteBottomMargin) {
            $drawItemsContinuation();
        }
        $rowY = $pdf->GetY();
        $rowFill = $itemIndex % 2 === 0 ? $securiaceQuotePaper : $securiaceQuoteSurface;
        $corners = $itemIndex === count($preparedQuoteItems) - 1 ? '0110' : '0000';
        $securiaceQuoteDrawCard($securiaceQuoteMargin, $rowY, $securiaceQuoteUsableWidth, $rowHeight, $rowFill, $securiaceQuoteLine, 2.65, $corners);
        $pdf->SetFont($securiaceQuoteFont, 'B', 7.1);
        $pdf->SetTextColor($securiaceQuoteInk[0], $securiaceQuoteInk[1], $securiaceQuoteInk[2]);
        $pdf->SetXY($securiaceQuoteMargin + 3, $rowY + 2);
        $pdf->MultiCell($itemWidths[0] - 6, 3.5, $preparedItem['title'], 0, 'L');
        if ($preparedItem['detail'] !== '') {
            $pdf->SetFont($securiaceQuoteFont, '', 6.4);
            $pdf->SetTextColor($securiaceQuoteMuted[0], $securiaceQuoteMuted[1], $securiaceQuoteMuted[2]);
            $pdf->SetXY($securiaceQuoteMargin + 3, $rowY + 2 + $titleHeight);
            $pdf->MultiCell($itemWidths[0] - 6, 3.3, $preparedItem['detail'], 0, 'L');
        }
        $values = array($preparedItem['qty'], $preparedItem['unitprice'], $preparedItem['discount'], $preparedItem['total']);
        $pdf->SetFont($securiaceQuoteFont, '', 6.5);
        $pdf->SetTextColor($securiaceQuoteInk[0], $securiaceQuoteInk[1], $securiaceQuoteInk[2]);
        $pdf->SetXY($securiaceQuoteMargin + $itemWidths[0], $rowY + 2.3);
        foreach ($values as $valueIndex => $value) {
            $columnIndex = $valueIndex + 1;
            $width = $itemWidths[$columnIndex] - ($columnIndex === 4 ? 3 : 0);
            $pdf->SetFont($securiaceQuoteFont, $columnIndex === 4 ? 'B' : '', 6.5);
            $pdf->Cell($width, 4, $securiaceQuoteTruncate($value, $columnIndex === 1 ? 8 : 22), 0, $columnIndex === 4 ? 1 : 0, 'R');
        }
        $pdf->SetY($rowY + $rowHeight);
    }
}
$pdf->Ln(3);

// Totals and acceptance context; quotes never show payment or transaction UI.
$totalRows = array(array('Subtotal', isset($subtotal) ? $subtotal : $securiaceQuoteFormatMoney(0), false));
if (isset($taxlevel1['rate']) && (float) $taxlevel1['rate'] > 0) {
    $totalRows[] = array(
        (!empty($taxlevel1['name']) ? $taxlevel1['name'] : 'Tax') . ' · ' . $taxlevel1['rate'] . '%',
        isset($tax1) ? $tax1 : $securiaceQuoteFormatMoney(0),
        false
    );
}
if (isset($taxlevel2['rate']) && (float) $taxlevel2['rate'] > 0) {
    $totalRows[] = array(
        (!empty($taxlevel2['name']) ? $taxlevel2['name'] : 'Additional tax') . ' · ' . $taxlevel2['rate'] . '%',
        isset($tax2) ? $tax2 : $securiaceQuoteFormatMoney(0),
        false
    );
}
$totalRows[] = array('Grand total', isset($total) ? $total : $securiaceQuoteFormatMoney(0), true);
$totalsHeight = max(31, 8 + (count($totalRows) * 6));
$securiaceQuoteEnsureSpace($totalsHeight + 4);
$totalsY = $pdf->GetY();
$totalsWidth = min(82, $securiaceQuoteUsableWidth * 0.42);
$acceptanceWidth = $securiaceQuoteUsableWidth - $totalsWidth - 4;
$securiaceQuoteDrawCard($securiaceQuoteMargin, $totalsY, $acceptanceWidth, $totalsHeight, $securiaceQuoteBrandSoft, $securiaceQuoteLine);
$securiaceQuoteDrawLabel('Validity and acceptance', $securiaceQuoteMargin + 4, $totalsY + 3, $acceptanceWidth - 8);
$pdf->SetFont($securiaceQuoteFont, 'B', 10);
$pdf->SetTextColor($securiaceQuoteBrandDark[0], $securiaceQuoteBrandDark[1], $securiaceQuoteBrandDark[2]);
$pdf->SetXY($securiaceQuoteMargin + 4, $totalsY + 8);
$pdf->MultiCell(
    $acceptanceWidth - 8,
    5,
    'Valid until ' . (isset($validuntil) && trim((string) $validuntil) !== '' ? trim((string) $validuntil) : 'the stated validity date'),
    0,
    'L'
);
$pdf->SetFont($securiaceQuoteFont, '', 6.7);
$pdf->SetTextColor($securiaceQuoteMuted[0], $securiaceQuoteMuted[1], $securiaceQuoteMuted[2]);
$pdf->SetX($securiaceQuoteMargin + 4);
$acceptanceText = $securiaceQuoteConfig['acceptance_note'];
if ($securiaceQuoteConfig['jurisdiction'] !== '') {
    $acceptanceText .= ' Jurisdiction: ' . $securiaceQuoteConfig['jurisdiction'] . '.';
}
$pdf->MultiCell($acceptanceWidth - 8, 3.5, trim($acceptanceText), 0, 'L');

$totalsX = $securiaceQuoteMargin + $acceptanceWidth + 4;
$securiaceQuoteDrawCard($totalsX, $totalsY, $totalsWidth, $totalsHeight, $securiaceQuoteSurface, $securiaceQuoteLine);
$totalRowY = $totalsY + 4;
foreach ($totalRows as $totalRow) {
    if ($totalRow[2]) {
        $pdf->SetDrawColor($securiaceQuoteLine[0], $securiaceQuoteLine[1], $securiaceQuoteLine[2]);
        $pdf->Line($totalsX + 3, $totalRowY, $totalsX + $totalsWidth - 3, $totalRowY);
        $totalRowY += 1.5;
    }
    $pdf->SetFont($securiaceQuoteFont, $totalRow[2] ? 'B' : '', $totalRow[2] ? 8 : 7);
    $pdf->SetTextColor($totalRow[2] ? $securiaceQuoteInk[0] : $securiaceQuoteMuted[0], $totalRow[2] ? $securiaceQuoteInk[1] : $securiaceQuoteMuted[1], $totalRow[2] ? $securiaceQuoteInk[2] : $securiaceQuoteMuted[2]);
    $pdf->SetXY($totalsX + 3, $totalRowY);
    $pdf->Cell($totalsWidth * 0.48, 4, $totalRow[0], 0, 0, 'L');
    $pdf->SetFont($securiaceQuoteFont, 'B', $totalRow[2] ? 8 : 7);
    $pdf->SetTextColor($securiaceQuoteInk[0], $securiaceQuoteInk[1], $securiaceQuoteInk[2]);
    $pdf->Cell($totalsWidth * 0.46, 4, $totalRow[1], 0, 1, 'R');
    $totalRowY += 5.5;
}
$pdf->SetY($totalsY + $totalsHeight + 4);

$securiaceQuoteRenderedNotes = false;

// Batch-safe repeated context and footer.
$securiaceQuoteGeneratedAt = function_exists('getTodaysDate') ? getTodaysDate(1) : date('j M Y');
$securiaceQuoteFinalPage = $pdf->getPage();
$securiaceQuotePageCount = $securiaceQuoteFinalPage - $securiaceQuoteStartPage + 1;
$securiaceQuotePreviousAutoPageBreak = $pdf->getAutoPageBreak();
$securiaceQuotePreviousBreakMargin = $pdf->getBreakMargin();
$pdf->SetAutoPageBreak(false, 0);
$securiaceQuoteStampedPages = array();
for ($page = $securiaceQuoteStartPage; $page <= $securiaceQuoteFinalPage; ++$page) {
    $securiaceQuoteStampedPages[] = $page;
    $pdf->setPage($page);
    $pdf->SetAutoPageBreak(false, 0);
    if ($page > $securiaceQuoteStartPage) {
        $pdf->SetFont($securiaceQuoteFont, 'B', 7);
        $pdf->SetTextColor($securiaceQuoteBrand[0], $securiaceQuoteBrand[1], $securiaceQuoteBrand[2]);
        $pdf->SetXY($securiaceQuoteMargin, 8);
        $pdf->Cell($securiaceQuoteUsableWidth * 0.6, 4, $securiaceQuoteCompanyName, 0, 0, 'L');
        $pdf->SetTextColor($securiaceQuoteInk[0], $securiaceQuoteInk[1], $securiaceQuoteInk[2]);
        $pdf->Cell($securiaceQuoteUsableWidth * 0.4, 4, 'Quote · ' . $securiaceQuoteNumber, 0, 1, 'R');
        $pdf->SetDrawColor($securiaceQuoteBrand[0], $securiaceQuoteBrand[1], $securiaceQuoteBrand[2]);
        $pdf->Line($securiaceQuoteMargin, 13, $securiaceQuotePageWidth - $securiaceQuoteMargin, 13);
    }
    $pdf->SetFont($securiaceQuoteFont, '', 5.8);
    $pdf->SetTextColor($securiaceQuoteMuted[0], $securiaceQuoteMuted[1], $securiaceQuoteMuted[2]);
    $pdf->SetXY($securiaceQuoteMargin, $securiaceQuotePageHeight - 10);
    $pdf->Cell($securiaceQuoteUsableWidth * 0.7, 4, 'Generated ' . $securiaceQuoteGeneratedAt . ' · ' . $securiaceQuoteCompanyName, 0, 0, 'L');
    $relativePage = $page - $securiaceQuoteStartPage + 1;
    $pdf->Cell($securiaceQuoteUsableWidth * 0.3, 4, 'Page ' . $relativePage . ' of ' . $securiaceQuotePageCount, 0, 1, 'R');
}
$pdf->SetAutoPageBreak($securiaceQuotePreviousAutoPageBreak, $securiaceQuotePreviousBreakMargin);
$pdf->setPage($securiaceQuoteFinalPage);
