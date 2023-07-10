# BQN-bf
## a frainfuck to assembly compiler written in BQN.

### Usage
The script `bf.bqn` generates a nasm-syntax assembly file compatible with x86_64 linux.

In a shell, run the following commands:
```sh
BQN ./bf.bqn hello.bf > hello.asm
nasm -felf64 -o hello.o hello.asm
ld -o hello hello.o

./hello
```

or, with the provided helper `run.sh`:
```sh
./run.sh hello.bf
```

### Features

`bf.bqn` implements the minimal functionality of the brainfuck language.

- 32KiB of memory is available to the brainfuck program.
- There is no wraparound functionality, moving the pointer to the left of the starting cell
  and reading or writing will result in memory corruption or access violations.
- the output is optimized: 
  - long sequences of `+`, `-`, `<` and `>` are collapsed to add/subtract
    instructions instead of repeated increment/decrement.
  - terminal loops that begin and end on the same cell, and don't perform any
    output are replaced by a closed-form expression by finding the modular inverse
    of the loop's increment.
