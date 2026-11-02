#!/bin/bash
export PATH=/usr/bin:$PATH
pacman -Q | grep -E 'switch-(expat|zstd|zlib|libdrm|elfutils|libelf)' 
pacman -Ss '^switch-(expat|zstd|zlib|libelf)' 2>&1 | grep '^dkp' 