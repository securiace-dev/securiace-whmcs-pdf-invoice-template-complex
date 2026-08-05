<?php

declare(strict_types=1);

/**
 * Inventory theme-controlled WHMCS PDF templates and explicit pdfAddPage calls.
 * Unknown template names fail closed so a WHMCS upgrade cannot add an unreviewed
 * document surface without updating this repository's compatibility decision.
 *
 * @return array<string, mixed>
 */
function auditWhmcsPdfSurface(string $whmcsRoot): array
{
    $resolvedRoot = realpath($whmcsRoot);
    if ($resolvedRoot === false || !is_dir($resolvedRoot)) {
        throw new InvalidArgumentException('WHMCS root does not exist: ' . $whmcsRoot);
    }

    $expectedTemplates = array('invoicepdf.tpl', 'quotepdf.tpl');
    $templatePaths = glob($resolvedRoot . '/templates/*/*pdf.tpl');
    if ($templatePaths === false) {
        $templatePaths = array();
    }
    sort($templatePaths);
    $templateNames = array_values(array_unique(array_map('basename', $templatePaths)));
    sort($templateNames);

    $invokedTemplates = array();
    $scanRoots = array(
        $resolvedRoot . '/admin',
        $resolvedRoot . '/includes',
        $resolvedRoot . '/vendor/whmcs',
    );
    foreach ($scanRoots as $scanRoot) {
        if (!is_dir($scanRoot)) {
            continue;
        }
        $iterator = new RecursiveIteratorIterator(
            new RecursiveDirectoryIterator($scanRoot, FilesystemIterator::SKIP_DOTS)
        );
        foreach ($iterator as $file) {
            if (!$file instanceof SplFileInfo || !$file->isFile() || strtolower($file->getExtension()) !== 'php') {
                continue;
            }
            $contents = file_get_contents($file->getPathname());
            if ($contents === false || strpos($contents, 'pdfAddPage') === false) {
                continue;
            }
            if (preg_match_all('/->pdfAddPage\s*\(\s*([\'\"])([^\'\"]+pdf\.tpl)\1/', $contents, $matches)) {
                foreach ($matches[2] as $templateName) {
                    $invokedTemplates[] = basename($templateName);
                }
            }
        }
    }
    $invokedTemplates = array_values(array_unique($invokedTemplates));
    sort($invokedTemplates);

    $observedTemplates = array_values(array_unique(array_merge($templateNames, $invokedTemplates)));
    sort($observedTemplates);
    $unknownTemplates = array_values(array_diff($observedTemplates, $expectedTemplates));
    $missingTemplates = array_values(array_diff($expectedTemplates, $observedTemplates));

    return array(
        'whmcs_root' => $resolvedRoot,
        'expected_templates' => $expectedTemplates,
        'theme_template_names' => $templateNames,
        'theme_template_paths' => $templatePaths,
        'pdf_add_page_templates' => $invokedTemplates,
        'unknown_templates' => $unknownTemplates,
        'missing_templates' => $missingTemplates,
        'ok' => empty($unknownTemplates) && empty($missingTemplates),
    );
}

if (realpath(isset($_SERVER['SCRIPT_FILENAME']) ? $_SERVER['SCRIPT_FILENAME'] : '') === __FILE__) {
    if ($argc !== 2) {
        fwrite(STDERR, "Usage: php scripts/audit-whmcs-pdf-surface.php /absolute/path/to/WHMCS\n");
        exit(64);
    }
    try {
        $result = auditWhmcsPdfSurface($argv[1]);
        fwrite(STDOUT, json_encode($result, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . "\n");
        exit($result['ok'] ? 0 : 1);
    } catch (Throwable $exception) {
        fwrite(STDERR, $exception->getMessage() . "\n");
        exit(1);
    }
}
