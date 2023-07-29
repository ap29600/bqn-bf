⟨Compile⟩⇐

Merge ← {(⍋⍋𝕨)⊏∾(/⁼𝕨)⥊¨𝕩}

Header ← {
  𝕊size:
  n‿s ← •Fmt¨8‿1×⌈size÷8
"
section .text
global _start
_start:
    mov rax, 12
    mov rdi, 0
    syscall
    mov rdi, rax
    mov r8, rax
    add rdi, "∾n∾"
    mov rax, 12
    syscall
    mov rsi, rax
    mov rcx, "∾s∾"
    xor rdx, rdx
bf_memset:
    sub rsi, 8
    mov qword[rsi], rdx
    dec rcx
    jnz bf_memset
"
}

footer ← "
    mov rax, 60
    mov rdi, 0
    syscall
bf_infinite_loop:
    jmp bf_infinite_loop
"

FwdJmp ← {
  f ← •Fmt¨𝕩
"b"⊸∾¨f∾¨":
    mov al, BYTE [rsi]
    test al, al
    jz f"⊸∾¨f∾¨(@+10)
}

BckJmp ← {
  f←•Fmt¨𝕩
"    jmp b"⊸∾¨f∾¨"
f"⊸∾¨f∾¨<":
"
}

Plus ← {
"    mov al, "⊸∾¨(•Fmt¨ 256|𝕩)∾¨<"
    add al, BYTE [rsi]
    mov BYTE[rsi], al
"
}

Left ←  ("    sub rsi, "∾•Fmt∾(@+10)˙)¨

Right ← ("    add rsi, "∾•Fmt∾(@+10)˙)¨

read ← "    mov BYTE [rsi], dl
    mov rax, 0
    mov rdi, 0
    mov rdx, 1
    syscall
"

write ← "    mov rax, 1
    mov rdi, 1
    mov rdx, 1
    syscall
"

# we interpret the loop to find the increments and decrements on variables,
# then we find the modular pseudo-inverse of the loop counter's increment.
Unroll ← {t‿c‿i:

  off ← +`c×-˝"><"=⌜t
  sum ← 256|c×-˝"+-"=⌜t

  # normalize increments. 0 will come first.
  uoff←⍷0∾(sum≠0)/off
  usum←(uoff=⌜off) +´∘/⎉1 sum

  decrement ← -⊏usum
  uoff 1⊸↓↩
  usum 1⊸↓↩

  # the largest power of two dividing the increment.
  # we introduce an assertion that the initial value of the cell is
  # divisible by this value, otherwise we can just halt the program.

  pow2    ← ⊑(⌽2⋆↕9)(⊣/˜0=|)decrement
  # TODO: test that this is correct!
  # pow2 ← 2÷˜1+ ⊑decrement 8‿8•bit._xor○(⥊256⊸|) ¯1+decrement

  modulus ← 256÷pow2
  # TODO: make this more efficient
  inverse ← ⊑/pow2=○(256⊸|)decrement×↕modulus

  result ← (1=pow2)⊑⟨
"    mov cl, BYTE[rsi]
    test cl, cl
    jz u"∾(•Fmt i)∾"
    mov al, cl
    and al, "∾(•Fmt pow2-1)∾"
    jnz bf_infinite_loop
    shr cl, "∾(•Fmt 2⋆⁼pow2)∾"
    mov BYTE[rsi], 0
"
    (0=≠off)⊑⟨
"    mov cl, BYTE[rsi]
    test cl, cl
    jz u"∾(•Fmt i)∾"
    mov BYTE[rsi], 0
",
"    mov BYTE[rsi], 0
"
    ⟩
  ⟩

  result ∾↩ ∾{
    mem ← "BYTE[rsi"∾("-+"⊏˜𝕨≥0)∾(•Fmt|𝕨)∾']'
    (1=256|inverse×𝕩)⊑⟨
"    mov al, cl
    mov dl, "∾(•Fmt 256|𝕩×inverse)∾"
    mul dl
    add al, "∾mem∾"
    mov "∾mem∾", al
",
"    mov al, cl
    add al, "∾mem∾"
    mov "∾mem∾", al
"
    ⟩
  }¨´ uoff‿usum

  result ∾↩ "u"∾(•Fmt i)∾":
"
  result
}

Compile ⇐ {
  ###### Parsing
  # Run-length encoding of the instructions: "+-<>" are joined.
  input ← ∊⟜"+-<>,.[]"⊸/𝕩
  split ← (≠⟜» ∨ ¬∘∊⟜"+-<>")input
  type  ← split/input
  count ← 1↓/⁼+`split

  # To generate matching IDs for the forward and backward jumps, we first compute
  # a depth vector. For any given depth, the closing brace of a pair always
  # occurs before any other closing brace at the same depth. This means that the
  # '⊒' primitive gives the index in 'ends' of the brace that closes the scope which
  # each element in 'begin' opens.
  begins‿ends ← /¨begin_mask‿end_mask ← "[]"=¨<type
  depth ← +`begin_mask»⊸-end_mask
  "Unmatched braces in source file"! (begins =○≠ ends) ∧ 0=⌊´depth
  matching ← begins ⍋⊸⊏○(⍋⊏⟜depth) ends

  ###### Loop unrolling
  # Find the deepest nested braces for loop unrolling. These are the ones where
  # the closest closing brace on the right is the same as the matching brace.
  leaf_indices ← /matching=ends⍋begins
  leaf_bodies ← begins {(1+𝕨)↓¨𝕩↑¨type‿count}¨○(leaf_indices⊸⊏) matching⊏ends

  unrollable ← {t‿c: (¬∨´⥊",."=⌜t) ∧ 0=+´c×-˝"><"=⌜t }¨leaf_bodies
  unroll_begins‿unroll_ends ← (unrollable/leaf_indices)⊸⊏¨begins‿(matching⊏ends)
  unroll_mask ← ¬(≠type)↑/⁼∾1+unroll_begins+↕¨unroll_ends-unroll_begins

  leftover_loop_starts ← ¬∘unrollable⌾(leaf_indices⊸⊏)(≠begins)⥊1
  leftover_loop_ends   ← (⍋matching)⊏leftover_loop_starts

  type ↩ 'u'¨⌾(unroll_begins⊸⊏) type
  count‿type ↩ count‿type/˜¨< unroll_mask

  ###### Code generation
  instructions ← ⟨
    Plus  ('+'=type)/count
    Plus∘-('-'=type)/count
    Left  ('<'=type)/count
    Right ('>'=type)/count
    <read
    <write
    FwdJmp leftover_loop_starts/matching
    BckJmp leftover_loop_ends/↕≠begins
    Unroll¨ unrollable/leaf_bodies∾¨leaf_indices
  ⟩

  output ← ∾("+-<>,.[]u"⊐type) Merge instructions
  (Header 𝕨)∾output∾footer
}

•Out 30000 Compile •file.Bytes ⊑ •args
