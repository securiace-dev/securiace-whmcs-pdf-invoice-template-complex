<?php

declare(strict_types=1);

$root = dirname(__DIR__);
$paths = array(
    'handoff' => $root . '/docs/HANDOFF.md',
    'readme' => $root . '/README.md',
    'pull_request_template' => $root . '/.github/pull_request_template.md',
    'workflow' => $root . '/.github/workflows/validate.yml',
    'addon' => $root . '/modules/addons/securiace_pdf_profile/securiace_pdf_profile.php',
    'snapshot_service' => $root . '/modules/addons/securiace_pdf_profile/lib/SnapshotService.php',
);

$sources = array();
foreach ($paths as $name => $path) {
    $source = file_get_contents($path);
    if ($source === false || trim($source) === '') {
        throw new RuntimeException('Unable to read living handoff contract source: ' . $name);
    }
    $sources[$name] = $source;
}

$requiredHandoffContracts = array(
    '# Living handoff',
    '## Current environment handoff',
    '## Invoice download incident contract',
    'securiace-pdf-profile.php` copied into the WHMCS `includes` area',
    'Securiace PDF Profile Snapshots',
    '## Sources of truth',
    '## Stable behavior that must not regress',
    '## Update triggers',
    '## Required handoff payload',
    '## Pull-request maintenance',
    '## Deployment handoff',
    '## Rollback handoff',
    '## Future GST transition',
    '## Staleness safeguards',
    'Handoff-Impact: none - <specific reason>',
    'must never be frozen',
    'after a snapshot row exists',
);
foreach ($requiredHandoffContracts as $contract) {
    if (strpos($sources['handoff'], $contract) === false) {
        throw new RuntimeException('Living handoff is missing contract: ' . $contract);
    }
}

if (!preg_match("/'version'\\s*=>\\s*'([^']+)'/", $sources['addon'], $addonVersion)) {
    throw new RuntimeException('Unable to resolve addon version from source.');
}
if (!preg_match('/Addon module version:\s*`([^`]+)`/', $sources['handoff'], $handoffAddonVersion)) {
    throw new RuntimeException('Unable to resolve addon version from handoff.');
}
if ($addonVersion[1] !== $handoffAddonVersion[1]) {
    throw new RuntimeException('Handoff addon version is stale.');
}

if (!preg_match('/public const SCHEMA_VERSION\s*=\s*([0-9]+);/', $sources['snapshot_service'], $schemaVersion)) {
    throw new RuntimeException('Unable to resolve snapshot schema version from source.');
}
if (!preg_match('/Snapshot schema version:\s*`([0-9]+)`/', $sources['handoff'], $handoffSchemaVersion)) {
    throw new RuntimeException('Unable to resolve snapshot schema version from handoff.');
}
if ($schemaVersion[1] !== $handoffSchemaVersion[1]) {
    throw new RuntimeException('Handoff snapshot schema version is stale.');
}

$helperHash = hash_file('sha256', $root . '/securiace-pdf-profile.php');
if (!is_string($helperHash)) {
    throw new RuntimeException('Unable to hash shared profile helper.');
}
if (!preg_match('/Shared profile helper SHA-256:\s*`([a-f0-9]{64})`/', $sources['handoff'], $handoffHelperHash)) {
    throw new RuntimeException('Unable to resolve shared profile helper hash from handoff.');
}
if (!hash_equals($helperHash, $handoffHelperHash[1])) {
    throw new RuntimeException('Handoff shared profile helper hash is stale.');
}

$requiredRepositoryContracts = array(
    array('readme', '[`docs/HANDOFF.md`](docs/HANDOFF.md)'),
    array('pull_request_template', '## Living handoff'),
    array('pull_request_template', 'Handoff-Impact: updated'),
    array('pull_request_template', 'Handoff-Impact: none - <specific reason'),
    array('workflow', 'tests/handoff_contract_test.php'),
    array('workflow', 'Enforce living handoff freshness'),
    array('workflow', 'Handoff-Impact: none -'),
);
foreach ($requiredRepositoryContracts as $contract) {
    list($sourceName, $needle) = $contract;
    if (strpos($sources[$sourceName], $needle) === false) {
        throw new RuntimeException($sourceName . ' is missing living handoff integration: ' . $needle);
    }
}

fwrite(STDOUT, "Living handoff contract tests passed.\n");
