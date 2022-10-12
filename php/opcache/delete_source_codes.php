<?php

$parentPath = realpath(__DIR__);

function getFiles(string $dir): Generator
{
    $files = [];
    foreach (glob("$dir/*") as $file) {
        if (is_dir($file)) {
            foreach (getFiles($file) as $f) {
                yield $f;
            }
        } else {
            yield $file;
        }
    }

    return $files;
}

$files = array_map(
    function (string $file) use ($parentPath) {
        preg_match("#($parentPath.+)\.bin#", $file, $matches);
        return $matches[1];
    },
    iterator_to_array(getFiles(ini_get('opcache.file_cache') . '/*/*'))
);

var_dump($files);

foreach ($files as $file) {
    file_put_contents($file, '');
}
