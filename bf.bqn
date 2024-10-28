⟨Compile⟩⇐

Merge ← {(⍋⍋𝕨)⊏∾((≠𝕩)↑/⁼𝕨)⥊¨𝕩}

Header ← {
  𝕊size:
  n‿s ← •Fmt¨8‿1×⌈size÷8
"section .text
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
    jmp bf_infinite_loop"
FwdJmp ← {
  f ← •Fmt¨𝕩
"loopbegin"⊸∾¨f∾¨":
    mov al, BYTE [rsi]
    test al, al
    jz loopend"⊸∾¨f∾¨(@+10)
}
BckJmp ← {
  f←•Fmt¨𝕩
"    jmp loopbegin"⊸∾¨f∾¨"
loopend"⊸∾¨f∾¨<":
"
}
Plus ← {
"    add BYTE[rsi], "⊸∾¨(•Fmt¨ 256|𝕩)∾¨<"
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
Func ← {
  f←•Fmt¨𝕩
"    call funcbegin"⊸∾¨f∾¨"
    jmp  funcend"⊸∾¨f∾¨"
funcbegin"⊸∾¨f∾¨":
    mov al, BYTE[rsi]
    test al,al
    jz funcret"⊸∾¨f∾¨<"
"
}
Return ← {
  f←•Fmt¨𝕩
"    mov al, BYTE[rsi]
    test al, al
    jnz funcbegin"⊸∾¨f∾¨"
funcret"⊸∾¨f∾¨":
    ret
funcend"⊸∾¨f∾¨<":
"
}
Call ← {
f ← •Fmt¨𝕩
"    call funcbegin"⊸∾¨f∾¨<"
"
}

# we interpret the loop to find the increments and decrements on variables,
# then we find the modular pseudo-inverse of the loop counter's increment.
# TODO: make this operate on `type` to disentangle from
#       begins and ends.
Unroll ← {type‿info‿label:
  off ← +`info×-˝"><"=⌜type
  sum ← 256|info×-˝"+-"=⌜type
  # normalize increments. 0 will come first.
  uoff←⍷0∾(sum≠0)/off
  usum←(uoff=⌜off) +´∘/⎉1 sum
  decrement ← -⊏usum
  uoff 1⊸↓↩
  usum 1⊸↓↩
  # the largest power of two dividing the increment.
  # we introduce an assertion that the initial value of the cell is
  # divisible by this value, otherwise we can just halt the program.

  pow2 ← ⊑(⌽2⋆↕9)(⊣/˜0=|)decrement
  modulus ← 256÷pow2
  inverse ← ⊑/pow2=○(256⊸|)decrement×↕modulus

  result ← (1=pow2)⊑⟨
"    mov cl, BYTE[rsi]
    test cl, "∾(•Fmt pow2-1)∾"
    jnz bf_infinite_loop
    shr cl, "∾(•Fmt 2⋆⁼pow2)∾"
    mov BYTE[rsi], 0
"
    (0=≠off)⊑⟨
"    mov cl, BYTE[rsi]
    test cl, cl
    jz unroll"∾(•Fmt label)∾"
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
    add "∾mem∾", al
",
"    mov al, cl
    add "∾mem∾", al
"
    ⟩
  }¨´ uoff‿usum

  result ∾↩ "unroll"∾(•Fmt label)∾":
"
  result
}

Compile ⇐ {
  ###### Parsing
  # Run-length encoding of the instructions: "+-<>" are joined.
  input ← ∊⟜"+-<>,.[]"⊸/𝕩
  split ← (≠⟜» ∨ ¬∘∊⟜"+-<>")input
  type  ← split/input
  info ← 1↓/⁼+`split

  # To generate matching IDs for the forward and backward jumps, we first compute
  # a depth vector. For any given depth, the closing brace of a pair always
  # occurs before any other closing brace at the same depth. This means that the
  # '⊒' primitive gives the index in 'ends' of the brace that closes the scope which
  # each element in 'begin' opens.
  begins‿ends ← /¨begin_mask‿end_mask ← "[]"=¨<type
  depth ← +`begin_mask»⊸-end_mask
  "Unmatched braces in source file"! (begins =○≠ ends) ∧ 0=⌊´depth
  matching ← begins ⍋⊸⊏○(⍋⊏⟜depth) ends

  #### Lift loops to function
  {
    loop_id ← ⊐˜begins {𝕨↓¨𝕩↑¨type‿info}¨ 1+matching⊏ends
    candidates ← (¬matching=ends⍋begins)∧(2=⊒loop_id)∧0<begins-˜matching⊏ends
    first ← (≠begins)↑/⁼candidates/loop_id
    call ← first<loop_id⊏first>begins⊏+`-´(≠type)↑¨/⁼¨(loop_id⊏first)⊸/¨1+begins⋈matching⊏ends
    move_mask ← 0<+`-´(≠type)↑¨/⁼¨call⊸/¨1+begins⋈matching⊏ends
    _r ← {𝕩⌾(𝕗⊸⊏)𝕨}
    type‿info (first/begins)_r¨↩ ⟨'f'¨, first/loop_id⟩
    type‿info (first/matching⊏ends)_r¨↩ ⟨'r'¨, first/loop_id⟩
    type‿info (call/begins)_r¨↩ ⟨'c'¨, call/loop_id⟩
    type‿info (/move_mask)_r¨↩ ⟨' '¨,0¨⟩

    kill ← first∨call∨begins⊏«move_mask
    begins (¬kill)⊸/↩
    ends ((⍋matching)⊏¬kill)⊸/↩
    matching ↩ matching ⊏ ¯1+`(⍋matching)⊏¬kill
    matching (¬kill)⊸/↩
  }

  ###### Loop unrolling
  # Find the deepest nested braces for loop unrolling. These are the ones where
  # the closest closing brace on the right is the same as the matching brace.
  leaf_indices ← /matching=ends⍋begins
  leaf_bodies ← begins {(1+𝕨)↓¨𝕩↑¨type‿info}¨○(leaf_indices⊸⊏) matching⊏ends

  unrollable ← {t‿c: (¬∨´⥊",."=⌜t) ∧ 0=+´c×-˝"><"=⌜t }¨leaf_bodies
  unroll_begins‿unroll_ends ← (unrollable/leaf_indices)⊸⊏¨begins‿(matching⊏ends)
  unroll_mask ← ¬(≠type)↑/⁼∾1+unroll_begins+↕¨unroll_ends-unroll_begins

  leftover_loop_starts ← ¬∘unrollable⌾(leaf_indices⊸⊏)(≠begins)⥊1
  leftover_loop_ends   ← (⍋matching)⊏leftover_loop_starts

  type ↩ 'u'¨⌾(unroll_begins⊸⊏) type
  info‿type ↩ info‿type/˜¨< unroll_mask
  ###### Code generation
  instructions ← ⟨
    Plus  ('+'=type)/info
    Plus∘-('-'=type)/info
    Left  ('<'=type)/info
    Right ('>'=type)/info
    <read
    <write
    FwdJmp leftover_loop_starts/matching
    BckJmp leftover_loop_ends/↕≠begins
    Call  ('c'=type)/info
    Func  ('f'=type)/info
    Return('r'=type)/info
    Unroll¨ unrollable/leaf_bodies∾¨leaf_indices
    <""
  ⟩

  output ← ∾("+-<>,.[]cfru "⊐type) Merge instructions
  (Header 𝕨)∾output∾footer
}

filenames‿options ← 2↑(('-'=⊑¨)⊔⊢) •args
keys‿values ← (⊐⟜':'¨(↑¨⋈+⟜1⊸↓¨)⊢) 1↓¨options
GetOpt ← {⊑(keys⊐<𝕩)⊏(<𝕨)∾˜values}
ParseInt←0 10⊸×⊸+˜´⌽-'0'˙
"Exactly one source file should be provided" ! 1=≠filenames
("/dev/stdout" GetOpt "out") •file.Bytes (ParseInt "30000" GetOpt "memory") Compile •file.Bytes ⊑ filenames
