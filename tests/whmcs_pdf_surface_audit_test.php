<?php

declare(strict_types=1);

require_once __DIR__ . '/../scripts/audit-whmcs-pdf-surface.php';

/** @param array<string, string> $files */
function createPdfSurfaceFixture(array $files): string
{
    $root = sys_get_temp_dir() . '/whmcs-pdf-surface-' . bin2hex(random_bytes(8));
    foreach ($files as $relativePath => $contents) {
        $path = $root . '/' . $relativePath;
        $directory = dirname($path);
        if (!is_dir($directory) && !mkdir($directory, 0775, true) && !is_dir($directory)) {
            throw new RuntimeException('Unable to create PDF surface fixture directory.');
        }
        if (file_put_contents($path, $contents) === false) {
            throw new RuntimeException('Unable to write PDF surface fixture file.');
        }
    }
    return $root;
}

function removePdfSurfaceFixture(string $root): void
{
    $iterator = new RecursiveIteratorIterator(
        new RecursiveDirectoryIterator($root, FilesystemIterator::SKIP_DOTS),
        RecursiveIteratorIterator::CHILD_FIRST
    );
    foreach ($iterator as $path) {
        if ($path->isDir()) {
            rmdir($path->getPathname());
        } else {
            unlink($path->getPathname());
        }
    }
    rmdir($root);
}

$validRoot = createPdfSurfaceFixture(array(
    'templates/twenty-one/invoicepdf.tpl' => '<?php // invoice ?>',
    'templates/twenty-one/quotepdf.tpl' => '<?php // quote ?>',
    'includes/quotefunctions.php' => '<?php $pdf->pdfAddPage("quotepdf.tpl", array());',
    'vendor/whmcs/whmcs-foundation/lib/Invoice.php' => '<?php $this->pdfAddPage("invoicepdf.tpl", array());',
));
$unknownRoot = createPdfSurfaceFixture(array(
    'templates/twenty-one/invoicepdf.tpl' => '<?php // invoice ?>',
    'templates/twenty-one/quotepdf.tpl' => '<?php // quote ?>',
    'templates/twenty-one/orderpdf.tpl' => '<?php // unexpected ?>',
));

try {
    $valid = auditWhmcsPdfSurface($validRoot);
    if (!$valid['ok']) {
        throw new RuntimeException('Expected invoice/quote PDF surface did not pass: ' . json_encode($valid));
    }
    if ($valid['pdf_add_page_templates'] !== array('invoicepdf.tpl', 'quotepdf.tpl')) {
        throw new RuntimeException('Explicit PDF invocations were not inventoried.');
    }

    $unknown = auditWhmcsPdfSurface($unknownRoot);
    if ($unknown['ok'] || $unknown['unknown_templates'] !== array('orderpdf.tpl')) {
        throw new RuntimeException('Unknown PDF surface did not fail closed.');
    }

    fwrite(STDOUT, "WHMCS PDF surface audit tests passed.\n");
} finally {
    removePdfSurfaceFixture($validRoot);
    removePdfSurfaceFixture($unknownRoot);
}
