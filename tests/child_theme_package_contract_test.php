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
    'name: "Securiace PDF Documents"',
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

$allowedFiles = array('invoicepdf.tpl', 'quotepdf.tpl', 'theme.yaml');
$packagedFiles = array_values(array_diff(scandir($themeDirectory) ?: array(), array('.', '..')));
sort($allowedFiles);
sort($packagedFiles);
if ($packagedFiles !== $allowedFiles) {
    throw new RuntimeException('The child theme must contain only the approved PDF overrides and theme.yaml.');
}

fwrite(STDOUT, "Child-theme package contract tests passed.\n");
