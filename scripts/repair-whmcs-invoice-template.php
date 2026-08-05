#!/usr/bin/env php
<?php

declare(strict_types=1);

/**
 * Apply the minimal PHP 8 runtime repair to the WHMCS invoice PDF template
 * without changing its established layout or verification behavior.
 *
 * @return array{color_references:int,currency_references:int,trailing_artifact:int}
 */
function repairWhmcsInvoiceTemplate(string $path): array
{
    $directory = dirname($path);
    if (!is_file($path) || !is_readable($path) || !is_writable($path) || !is_writable($directory)) {
        throw new RuntimeException('Template and its parent directory must be readable and writable.');
    }

    $source = file_get_contents($path);
    if ($source === false) {
        throw new RuntimeException('Unable to read template.');
    }
    $originalSource = $source;

    $colorCount = 0;
    $source = preg_replace_callback(
        '/(?<!\\$)\\b((?:COLOR_(?:DARK_GREY|LIGHT_GREY|PURPLE|WHITE|BLACK)|STATUS_(?:ACCENT|BORDER)_COLOR))(?=\\s*\\[)/',
        static function (array $match) use (&$colorCount): string {
            ++$colorCount;
            return '$' . $match[1];
        },
        $source
    );
    if ($source === null) {
        throw new RuntimeException('Unable to repair color references.');
    }

    $currencyCount = 0;
    $source = preg_replace_callback(
        '/\\bformatCurrency\\b/',
        static function (array $match) use (&$currencyCount): string {
            ++$currencyCount;
            return 'securiaceInvoiceFormatCurrency';
        },
        $source
    );
    if ($source === null) {
        throw new RuntimeException('Unable to isolate the currency helper.');
    }

    $trailingCount = 0;
    $source = preg_replace('/\\?>\\s*invoicepdf\\.tpl\\s*\\z/', '', $source, 1, $trailingCount);
    if ($source === null) {
        throw new RuntimeException('Unable to remove the trailing template artifact.');
    }

    if ($source !== $originalSource) {
        $temporaryPath = tempnam($directory, '.invoicepdf-repair-');
        if ($temporaryPath === false) {
            throw new RuntimeException('Unable to create an atomic repair file.');
        }

        try {
            if (file_put_contents($temporaryPath, $source, LOCK_EX) === false) {
                throw new RuntimeException('Unable to write the atomic repair file.');
            }

            $permissions = fileperms($path);
            if ($permissions !== false && !chmod($temporaryPath, $permissions & 0777)) {
                throw new RuntimeException('Unable to preserve template permissions.');
            }

            if (!rename($temporaryPath, $path)) {
                throw new RuntimeException('Unable to atomically replace the template.');
            }
        } finally {
            if (is_file($temporaryPath)) {
                @unlink($temporaryPath);
            }
        }
    }

    return array(
        'color_references' => $colorCount,
        'currency_references' => $currencyCount,
        'trailing_artifact' => $trailingCount,
    );
}

function assertWhmcsInvoiceTemplateRepaired(string $path): void
{
    $source = file_get_contents($path);
    if ($source === false) {
        throw new RuntimeException('Unable to read repaired template.');
    }

    if (preg_match('/(?<!\\$)\\b(?:COLOR_[A-Z_]+|STATUS_(?:ACCENT|BORDER)_COLOR)(?=\\s*\\[)/', $source)) {
        throw new RuntimeException('Bare PHP 8 color/status reference remains.');
    }
    if (preg_match('/\\bformatCurrency\\b/', $source)) {
        throw new RuntimeException('Conflicting WHMCS currency helper reference remains.');
    }
    if (preg_match('/\\?>\\s*invoicepdf\\.tpl\\s*\\z/', $source)) {
        throw new RuntimeException('Trailing response-corrupting artifact remains.');
    }
    if (strpos($source, 'DIGITALLY VERIFIED') === false) {
        throw new RuntimeException('Verified invoice badge was not preserved.');
    }
    if (strpos($source, "'show_verification_badge'    => true") === false) {
        throw new RuntimeException('Verified invoice badge configuration was not preserved.');
    }
}

function backupWhmcsInvoiceTemplate(string $path): string
{
    $suffix = gmdate('YmdHis') . '-' . bin2hex(random_bytes(3));
    $backupPath = $path . '.bak.' . $suffix;
    if (!copy($path, $backupPath)) {
        throw new RuntimeException('Unable to create the rollback copy.');
    }

    $permissions = fileperms($path);
    if ($permissions !== false && !chmod($backupPath, $permissions & 0777)) {
        @unlink($backupPath);
        throw new RuntimeException('Unable to preserve rollback-copy permissions.');
    }

    return $backupPath;
}

function main(array $arguments): int
{
    if (count($arguments) !== 2) {
        fwrite(STDERR, "Usage: repair-whmcs-invoice-template.php /absolute/path/invoicepdf.tpl\n");
        return 64;
    }

    $backupPath = null;
    try {
        $backupPath = backupWhmcsInvoiceTemplate($arguments[1]);
        $result = repairWhmcsInvoiceTemplate($arguments[1]);
        assertWhmcsInvoiceTemplateRepaired($arguments[1]);
        $result['backup'] = $backupPath;
        fwrite(STDOUT, json_encode($result, JSON_UNESCAPED_SLASHES) . PHP_EOL);
        return 0;
    } catch (Throwable $error) {
        $message = $error->getMessage();
        if ($backupPath !== null) {
            $message .= ' Rollback copy: ' . $backupPath;
        }
        fwrite(STDERR, $message . PHP_EOL);
        return 1;
    }
}

if (realpath($_SERVER['SCRIPT_FILENAME'] ?? '') === __FILE__) {
    exit(main($argv));
}
