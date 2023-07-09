Unlines ← ∾⟜(@+10)⊸∾´

# allocate 32KiB with the 'brk' syscall.
# TODO: make the amount of memory configurable.
# TODO: write a more efficient version of memset
#       to zero the initial memory.
header ← Unlines⟨
  "section .text"
  "global _start"
  "_start:"
  "    mov rax, 12"
  "    mov rdi, 0"
  "    syscall"
  "    mov rdi, rax"
  "    mov r8, rax"
  "    add rdi, 0x8000"
  "    mov rax, 12"
  "    syscall"
  "    mov rsi, rax"
  "    mov rcx, 0x8000"
  "    mov dl, 0"
  "bf_memset:"
  "    dec rsi"
  "    mov BYTE [rsi], dl"
  "    dec rcx"
  "    jnz bf_memset"
⟩

footer ← Unlines⟨
  "    mov rax, 60"
  "    mov rdi, 0"
  "    syscall"
⟩

FwdJmp ← {
  Unlines⟨
    "b"∾(•Fmt𝕨)∾":"
    "    mov al, BYTE [rsi]"
    "    test al, al"
    "    jz e"∾•Fmt𝕨
  ⟩
}¨

BackJmp ← {
  Unlines⟨
    "    jmp b"∾•Fmt𝕨,
    "e"∾(•Fmt𝕨)∾":",
  ⟩
}¨

Plus ← {
  Unlines⟨
    "    mov al, "∾•Fmt 256|𝕩
    "    add al, BYTE [rsi]"
    "    mov BYTE [rsi], al"
  ⟩
}

Minus ← Plus∘-

Left ←  {"    sub rsi, "∾•Fmt𝕩}

Right ← {"    add rsi, "∾•Fmt𝕩}

read ← Unlines⟨
  "    mov rax, 0"
  "    mov rdi, 0"
  "    mov rdx, 1"
  "    syscall"
⟩

write ← Unlines⟨
  "    mov rax, 1"
  "    mov rdi, 1"
  "    mov rdx, 1"
  "    syscall"
⟩

# Discard any characters that are not supported by the language.
input ← ∊⟜"+-,.<>[]"⊸/•file.Bytes⊑•args

# Run-length encoding of the instructions: "+-<>" are joined.
split ← (≠⟜» ∨ ¬∘∊⟜"+-<>")input
type  ← split/input
count ← 1↓/⁼+`split

# To generate matching IDs for the forward and backward jumps, we first compute
# a depth vector. For any given depth, the closing brace of a pair always
# occurs before any other closing brace at the same depth. This means that the
# '⊒' primitive gives the index in 'begins' of the brace each element in 'ends'
# closes.
# TODO: validate that the brackets are balanced.
begins‿ends ← "[]"=¨<type
depth ← +`begins-»ends
forward‿back ← (↕∘≠⋈⊢) begins ⊒○(/⟜depth) ends

# Dispatch on the type of the instruction, calling the appropriate codegen
# function with the run-length as 𝕩. The jumps will result in "" and are
# patched later.
output ← ("+-<>,."⊐type){𝕨◶⟨Plus, Minus, Left, Right, read, write, ""⟩𝕩}¨count

# patch the jump locations by generating appropriate labels from 'forward' and
# 'back'.
output ↩ forward⊸FwdJmp⌾(begins⊸/)output
output ↩ back⊸BackJmp⌾(ends⊸/)output

•Out Unlines header<⊸∾output∾⟜<footer
