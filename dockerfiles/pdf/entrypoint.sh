#!/bin/sh
set -euox pipefail

node /decktape/decktape.js --chrome-path chromium-browser --chrome-arg=--no-sandbox /slides/index.html /slides/fat_slides.pdf --size='2048x1536' --pause 0
gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 -dPDFSETTINGS=/screen -dNOPAUSE -dQUIET -dBATCH -sOutputFile=/slides/slides.pdf /slides/fat_slides.pdf
rm -fvr /slides/fat_slides.pdf
