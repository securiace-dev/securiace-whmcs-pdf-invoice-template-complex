<?php

declare(strict_types=1);

$root = dirname(__DIR__);
$themeDirectory = $root . '/templates/securiace';
$manifestPath = $themeDirectory . '/theme.yaml';
$manifest = file_get_contents($manifestPath);

if ($manifest === false) {
    throw new RuntimeException('Unable to read the Securiace child-theme manifest.');
}

$requiredManifestContracts = array(
    'name: "Securiace"',
    'config:',
    '  parent: twenty-one',
);
foreach ($requiredManifestContracts as $contract) {
    if (strpos($manifest, $contract) === false) {
        throw new RuntimeException('Child-theme manifest contract is missing: ' . $contract);
    }
}

$templateContracts = array(
    'invoicepdf-modern.tpl' => 'invoicepdf.tpl',
    'quotepdf-modern.tpl' => 'quotepdf.tpl',
);
foreach ($templateContracts as $sourceName => $packagedName) {
    $sourcePath = $root . '/' . $sourceName;
    $packagedPath = $themeDirectory . '/' . $packagedName;
    $sourceHash = hash_file('sha256', $sourcePath);
    $packagedHash = hash_file('sha256', $packagedPath);
    if ($sourceHash === false || $packagedHash === false || !hash_equals($sourceHash, $packagedHash)) {
        throw new RuntimeException($packagedName . ' is not synchronized with ' . $sourceName . '.');
    }
}

$requiredPaths = array(
    'css/custom.css',
    'js/custom.js',
    'js/theme-mode.js',
    'img/logo-on-light.svg',
    'img/logo-on-dark.svg',
    'img/logo-icon.svg',
);
foreach ($requiredPaths as $relativePath) {
    $path = $themeDirectory . '/' . $relativePath;
    if (!is_readable($path)) {
        throw new RuntimeException('Child theme is missing required file: ' . $relativePath);
    }
}

$customCss = (string) file_get_contents($themeDirectory . '/css/custom.css');
foreach (array('--bg-canvas', '--accent', '[data-theme="light"]', '[data-theme="dark"]', 'securiace-theme-toggle') as $token) {
    if (strpos($customCss, $token) === false) {
        throw new RuntimeException('custom.css is missing dual-mode contract: ' . $token);
    }
}

$modeJs = (string) file_get_contents($themeDirectory . '/js/custom.js');
foreach (array('securiace-theme-mode', 'prefers-color-scheme', 'data-theme') as $token) {
    if (strpos($modeJs, $token) === false) {
        throw new RuntimeException('theme mode script is missing contract: ' . $token);
    }
}

$allowedTopLevel = array('css', 'img', 'invoicepdf.tpl', 'js', 'quotepdf.tpl', 'theme.yaml');
$packagedEntries = array_values(array_diff(scandir($themeDirectory) ?: array(), array('.', '..')));
sort($allowedTopLevel);
sort($packagedEntries);
if ($packagedEntries !== $allowedTopLevel) {
    throw new RuntimeException(
        'The child theme top-level entries must match the approved package surface. Found: '
        . implode(', ', $packagedEntries)
    );
}

$hookPath = $root . '/hooks/securiace-theme-mode.php';
if (!is_readable($hookPath) || strpos((string) file_get_contents($hookPath), 'ClientAreaHeadOutput') === false) {
    throw new RuntimeException('Theme mode hook is missing or incomplete.');
}

$brandTokens = $root . '/assets/brand/tokens.json';
if (!is_readable($brandTokens)) {
    throw new RuntimeException('Brand tokens.json is missing.');
}

fwrite(STDOUT, "Child-theme package contract tests passed.\n");
