Unlines ← ∾⟜(@+10)⊸∾´

# allocate 32KiB with the 'brk' syscall.
# TODO: make the amount of memory configurable.
header ← "section .text
global _start
_start:
    mov rax, 12
    mov rdi, 0
    syscall
    mov rdi, rax
    mov r8, rax
    add rdi, 0x8000
    mov rax, 12
    syscall
    mov rsi, rax
    mov rcx, 0x1000
    xor rdx, rdx
bf_memset:
    sub rsi, 8
    mov qword[rsi], rdx
    dec rcx
    jnz bf_memset"

footer ← "    mov rax, 60
    mov rdi, 0
    syscall
bf_infinite_loop:
    jmp bf_infinite_loop"

FwdJmp ← {
"b"∾𝕩∾":
    mov al, BYTE [rsi]
    test al, al
    jz f"∾𝕩
}∘•Fmt

BckJmp ← {
"    jmp b"∾𝕩∾"
f"∾𝕩∾":"
}∘•Fmt

Plus ← {
"    mov al, "∾𝕩∾"
    add al, BYTE [rsi]
    mov BYTE [rsi], al"
}∘(•Fmt 256⊸|)

Minus ← Plus∘-

Left ←  "    sub rsi, "∾•Fmt

Right ← "    add rsi, "∾•Fmt

read ← "    mov BYTE [rsi], dl
    mov rax, 0
    mov rdi, 0
    mov rdx, 1
    syscall"

write ← "    mov rax, 1
    mov rdi, 1
    mov rdx, 1
    syscall"

# we interpret the loop to find the increments and decrements on variables,
# then we find the modular pseudo-inverse of the loop counter's increment.
Unroll ← {t‿c‿i:
  off ← +`c×-˝"><"=⌜t
  sum ← 256|c×-˝"+-"=⌜t

  decrement ← -+´sum×0=off
  # the largest power of two dividing the increment.
  # we introduce an assertion that the initial value of the cell is
  # divisible by this value, otherwise we can just halt the program.
  pow2 ← ⊑(⌽2⋆↕9)(⊣/˜0=|)decrement
  modulus ← 256÷pow2
  inverse ← ⊑/pow2=○(256⊸|)decrement×↕modulus

  # discard all operations on the initial cell, as that will always be zeroed
  # after the guard.
  off‿sum ↩ off‿sum/˜¨<(sum≠0)∧off≠0

  # TODO: refactor logic
  result ← ((0<≠off)∨1≠pow2)/⟨
    "    mov cl, BYTE[rsi]"
    "    test cl, cl"
    "    jz u"∾•Fmt i
  ⟩
  result ∾↩ (1≠pow2)/⟨
    "    mov al, cl"
    "    and al, "∾(•Fmt pow2-1)
    "    jnz bf_infinite_loop"
    "    shr cl, "∾(•Fmt 2⋆⁼pow2)
  ⟩
  result ∾↩ ⟨
    "    mov BYTE[rsi], 0"
  ⟩

  result ∾↩ {
    ind ← "BYTE[rsi"∾("-+"⊏˜𝕨≥0)∾(•Fmt|𝕨)∾']'
    result ← ⟨"    mov al, cl"⟩
    result∾↩ (∨´1≠𝕩‿inverse)/⟨
      "    mov dl, "∾•Fmt 256|𝕩×inverse
      "    mul dl"
    ⟩
    result∾↩ ⟨
      "    add al, "∾ind
      "    mov "∾ind∾", al"
    ⟩
    Unlines result
  }¨´ off‿sum

  result ∾↩⟨ "u"∾(•Fmt i)∾":" ⟩

  Unlines result
}

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
wbegins‿wends ← /¨begins‿ends ← "[]"=¨<type
depth ← +`begins»⊸-ends

forward‿back ← (⊢⋈↕∘≠) ends ⊒○(/⟜depth) begins
wbegins ↩ back⊏wbegins
wends   ↩ forward⊏wends
metadata ← forward⌾(begins⊸/) back⌾(ends⊸/) count

###### Loop unrolling

# Find the deepest nested braces for loop unrolling. These are the ones where
# the closest opening brace on the left is the same as the matching brace.
inner_loop_indices ← /forward=wends∧⊸⍋wbegins
inner_loop_bodies ← wbegins {(1+𝕨)↓¨𝕩↑¨type‿count}¨○(inner_loop_indices⊸⊏) wends

unrollable ← {t‿c: (¬∨´⥊",."=⌜t) ∧ 0=+´c×-˝"><"=⌜t }¨inner_loop_bodies
unrolled ← Unroll¨ unrollable/inner_loop_bodies∾¨inner_loop_indices
unroll_begins‿unroll_ends ← (unrollable/inner_loop_indices)⊸⊏¨wbegins‿wends
unroll_mask ← ¬(≠type)↑/⁼∾unroll_ends(1+⊢+↕∘-)¨unroll_begins

metadata ↩ unrolled⌾(unroll_begins⊸⊏) metadata
type     ↩ 'u'¨⌾(unroll_begins⊸⊏) type
metadata‿type ↩ metadata‿type/˜¨< unroll_mask

###### Code generation

# Dispatch on the type of the instruction, calling the appropriate codegen
# function with additional arguments (run length or jump label) as 𝕩.
output ← ("+-<>,.[]u"⊐type){𝕨◶⟨
  Plus, Minus,
  Left, Right,
  read, write,
  FwdJmp, BckJmp,
  ⊢, !
⟩𝕩}¨metadata

•Out Unlines header<⊸∾output∾⟜<footer
