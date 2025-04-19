# `OpenCloud Desktop for ARM64`

## Introduction

`OpenCloud Desktop` is a tool to synchronize files from `OpenCloud`
with your computer.

## Download

### Binary packages

- For the official releases please have a look at https://github.com/opencloud-eu/desktop/releases first

- the rest can be found here https://github.com/handtrixx/opencloud-eu-desktop-arm64/releases 

## Compile on your own

### Build packages 
docker build -t opencloud-desktop-client .

### Copy packages to a directory of your choice
docker run -it -v ./output:/output opencloud-desktop-client

## How to generate libre-graph-api

It comes already generated ready for compilation, but if you want you can also do this on your own.

1. Clone repo from ...

2. Run docker command inside the repos directory
docker run --rm -v "${PWD}:/local" openapitools/openapi-generator-cli generate --enable-post-process-file  -t local/templates/cpp-qt-client  -i local/api/openapi-spec/v1.0.yaml -g cpp-qt-client -o /local/out/cpp

3. replace the cpp folder in in src by the newly generated one.

## Reporting issues and contributing

If you find any bugs or have any suggestion for improvement, please
file an issue at https://github.com/opencloud-eu/desktop/issues. Do not
contact the authors directly by mail, as this increases the chance
of your report being lost.

If you created a patch, please submit a [Pull
Request](https://github.com/opencloud-eu/desktop/pulls).

## License

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
    or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
    for more details.
