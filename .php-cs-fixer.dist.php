<?php
declare(strict_types=1);
$finder = (new PhpCsFixer\Finder())->in(__DIR__ . '/src')->in(__DIR__ . '/tests');
return (new PhpCsFixer\Config())
    ->setRules(['@Symfony' => true, '@PHP84Migration' => true, 'declare_strict_types' => true])
    ->setFinder($finder);
