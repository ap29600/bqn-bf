⟨Compile⟩⇐

Merge ← {(⍋⍋𝕨)⊏∾((≠𝕩)↑/⁼𝕨)⥊¨𝕩}

GenHeader ← {
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
Add ← {"    add BYTE [rsi], "⊸∾¨(•Fmt¨ 256|𝕩)∾¨@+10}
Move ← {((𝕩≥0)⊏⟨"    sub rsi, ","    add rsi, "⟩)∾¨(•Fmt¨|𝕩)∾¨@+10}
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
"    call funcbegin"⊸∾¨f∾¨(@+10)
}

Mul ← {id‿[offset, increment]:
  decrement ← -(offset⊐0)⊏increment∾0
  offset‿increment (0≠offset)⊸/¨↩
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
    (0=≠offset)⊑⟨
"    mov cl, BYTE[rsi]
    test cl, cl
    jz multiply"∾(•Fmt id)∾"
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
  }¨´ offset‿increment
  result∾"multiply"∾(•Fmt id)∾":
"
}

Compile ⇐ { memory‿use_mul‿deinline 𝕊 𝕩:
  # Run-length encoding of the instructions: "+-<>" are joined.
  input ← ∊⟜"+-<>,.[]"⊸/𝕩
  split ← (≠⟜» ∨ ¬∘∊⟜"+-<>")input
  type  ← split/input
  info  ← 1↓/⁼+`split
	# normalize -1 to +256
  info (256|-)⌾((type='-')⊸/) ↩
  type '+'¨⌾((type='-')⊸/) ↩
	# normalize <1 to >¯1
  info -⌾((type='<')⊸/) ↩
  type '>'¨⌾((type='<')⊸/) ↩

  # match brackets
  {
    begins‿ends ← /¨begin_mask‿end_mask ← "[]"=¨<type
    depth ← +`begin_mask»⊸-end_mask
    "Unmatched braces in source file"! (begins =○≠ ends) ∧ 0=⌊´depth
    matching ← begins ⍋⊸⊏○(⍋⊏⟜depth) ends
    info {𝕩⌾((begins∾matching⊏ends)⊸⊏)𝕨}↩ ∾˜↕≠begins
  }

  {𝕩⋄# Lift loops to functions
     # a call is denoted by ⟨'c', function_id⟩
    begins‿ends ← /¨"[]"=¨<type
    ends↩(⍋ begins ⍋○(⊏⟜info) ends)⊏ends

		ti ← type⋈info×¬type∊"[]"
    loop_id ← ⊐˜begins {(1+𝕨)↓¨𝕩↑¨ti}¨ ends
    candidates ← (↕∘≠⊸≠¯1+begins⍋ends)∧(1=⊒loop_id)∧5<ends-begins
    first ← (≠begins)↑/⁼candidates/loop_id
    call ← first<loop_id⊏first>begins⊏+`-´(≠type)↑¨/⁼¨(loop_id⊏first)⊸/¨1+begins⋈ends
    del_mask ← 0<+`⥊-´(≠type)↑¨/⁼¨call⊸/¨1+begins⋈ends
    pos ← (⥊first/begins∾˘ends)∾call/begins
    new_type ← ("fr"⥊˜2×+´first)∾'c'⥊˜+´call
    new_info ← (2/first/loop_id)∾call/loop_id
    type‿info {𝕩⌾(pos⊸⊏)𝕨}¨↩ new_type‿new_info
    type‿info (¬del_mask)⊸/¨↩
  }⍟deinline @

  {𝕩⋄# Unroll loops to multiplication
     # an unrolled loop is denoted by ⟨'u', [positions, increments] ⟩
    begins‿ends ← /¨"[]"=¨<type
    ends↩(⍋ begins ⍋○(⊏⟜info) ends)⊏ends

    indices ← /↕∘≠⊸=¯1+begins⍋ends
		ti ← type‿info
    loop_types‿loop_infos ← (⊣´¨⋈⊢´¨)begins {(1+𝕨)↓¨𝕩↑¨ti}¨○(indices⊸⊏) ends
    pure   ← ∧´∘∊⟜"+>"¨loop_types              # loops that don't perform IO or call functions
    static ← 0=+´¨loop_infos/¨˜'>'=¨loop_types # loops that start and end on the same cell
    indices‿loop_types‿loop_infos (pure∧static)⊸/¨↩

    del_mask ← 0<+`⥊-´(≠type)↑¨/⁼¨indices⊸⊏¨1+begins⋈ends
    pos ← indices⊏begins
    new_type ← '*'⥊˜≠indices
    new_info ← indices⋈¨loop_types {(w/j)≍˜(⌊´c)+/w←0≠j←256|+´¨(i⊏𝕩)⊔˜c-⌊´c←(i←/'+'=𝕨)⊏+`𝕩×'>'=𝕨}¨ loop_infos
    type‿info {𝕩⌾(pos⊸⊏)𝕨}¨↩ new_type‿new_info
    type‿info (¬del_mask)⊸/¨↩
  }⍟use_mul @

  # Code generation
  d ← ⟨Add,Move,<read,<write,FwdJmp,BckJmp,Call,Func,Return,Mul¨,<""⟩
  t ← "+>,.[]cfr*"
  instructions ← d {𝕎 𝕩}¨(1+≠t)↑info⊔˜t⊐type
  output ← ∾(t⊐type) Merge instructions
  (GenHeader memory)∾output∾footer
}

filenames‿options ← 2↑(('-'=⊑¨)⊔⊢) •args
keys‿values ← (⊐⟜':'¨(↑¨⋈+⟜1⊸↓¨)⊢) 1↓¨options
GetStr   ← {⊑(keys⊐<𝕩)⊏values∾<𝕨}
ParseInt ← 0 10⊸×⊸+˜´⌽-'0'˙
GetInt   ← {
  o←(•Fmt𝕨) GetStr 𝕩
  ("Expected number argument for option `"∾𝕩∾"`")!(×≠o)∧∧´1="0:"⍋o
  ParseInt o
}
GetBool  ← {
  i←⊑⟨"no","off","0","yes","on","1"⟩⊐<o←(•Fmt𝕨)GetStr 𝕩
  ("Expected boolean argument for option `"∾𝕩∾"`")!6≥i
  i>3
}

"Exactly one source file should be provided" ! 1=≠filenames
out_file ← "/dev/stdout" GetStr "out"
memory   ← 30000 GetInt  "memory"
use_mul  ← 1     GetBool "use-mul"
deinline ← 1     GetBool "deinline"
out_file •file.Bytes memory‿use_mul‿deinline Compile •file.Bytes ⊑ filenames
