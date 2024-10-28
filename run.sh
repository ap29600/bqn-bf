#!/usr/bin/sh
set -e

BASENAME=$(basename $1 .bf)

echo "compile..."
BQN bf.bqn "$1" > $BASENAME.asm

echo "assemble..."
nasm -o $BASENAME.o -felf64 $BASENAME.asm -O0

echo "link..."
ld   -o $BASENAME $BASENAME.o

if [[ $2 == "--run" ]] then
echo "execute..."
	./$BASENAME
fi
