#!/usr/bin/sh
set -e

BASENAME=${1%\.bf}

BQN bf.bqn "$1" > $BASENAME.asm
nasm -o $BASENAME.o -felf64 $BASENAME.asm
ld   -o $BASENAME $BASENAME.o

./$BASENAME
