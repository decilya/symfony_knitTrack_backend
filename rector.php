<?php
declare(strict_types=1);
use Rector\Config\RectorConfig;
use Rector\Set\ValueObject\SetList;
use Rector\Symfony\Set\SymfonySetList;
return RectorConfig::configure()
    ->withPaths([__DIR__ . '/src'])
    ->withSets([SetList::PHP_84, SymfonySetList::SYMFONY_74]);
