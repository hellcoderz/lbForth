refill   Copyright 2004, 2013 Lars Brinkhoff
drop

: immediate   latestxt dup c@ negate swap c! ;
: \   refill drop ; immediate

\ This is the first file to be loaded and compiled by the kernel.
\ Since the kernel only defines a bare minimum of words, we have to
\ build basic language constructs almost from scratch.

: >mark      here 0 , ;
: >resolve   here swap ! ;
: <mark      here ;
: <resolve   , ;

: char   parse-name drop c@ ;
: '   parse-name find-name 0= ?undef ;

: here!   here - allot ;
: >h      here >r here! ;
: h>      r> here! ;

: hide   latestxt >nextxt  current @ >body ! ;
: link   current @ >body @  latestxt >lfa ! ;
: compile-only   hide  current @  [ ' compiler-words ] literal current !
   link  reveal  current !  immediate ;

: code!     latestxt >code ! ;
: does!     latestxt >does ! ;
: does,     ;
: (does>)   r> does! ;
: does>     [ ' (does>) ] literal compile, does, ; compile-only
: create    parse-name header, [ ' dodoes >code @ ] literal ,  reveal (does>) ;

: postpone,   [ ' literal compile, ' compile, ] literal compile, ;
\ Same as:    postpone literal  postpone compile, ;

: finders   create ' , ' , ' ,   does> swap 1+ cells + @ execute ;

finders postpone-xt   postpone, abort compile,

: postpone   parse-name find-name postpone-xt ; compile-only

: unresolved   postpone postpone  postpone >mark ; immediate
: ahead   unresolved branch ; compile-only
: if   unresolved 0branch ; compile-only
: then   >resolve ; compile-only

: resolving   postpone postpone  postpone <resolve ; immediate
: begin   <mark ; compile-only
: again   resolving branch ; compile-only
: until   resolving 0branch ; compile-only

: else   postpone ahead swap postpone then ; compile-only
: while   postpone if swap ; compile-only
: repeat   postpone again postpone then ; compile-only

: recurse   latestxt compile, ; compile-only

: 1-   -1 + ;

: parse   >r  source drop >in @ +
   0 begin source? while <source r@ <> while 1+ repeat then r> drop ;

: [char]   char postpone literal ; compile-only

: (   begin [char] ) parse 2drop
      source drop >in @ 1- + c@ [char] ) <> while
      refill while repeat then ; immediate

create squote   128 allot

: s,   dup , string, ;
: s"   [char] " parse  >r squote r@ cmove  squote r> ;
: s"   postpone (sliteral) [char] " parse s, ; compile-only

: (abort")    cr type cr abort ;
: abort"   postpone if postpone s" postpone (abort") postpone then ;
   compile-only

: ?:   >in @ >r  parse-name find-name
   if r> 2drop  begin source 1- + c@ [char] ; = refill abort" ?" until
   else 2drop r> >in ! : then ;

?: and   nand invert ;
?: 2*    dup + ;

?: *   1 2>r 0 swap begin r@ while
          2r> 2dup 2* 2>r and if swap over + swap then 2*
       repeat 2r> 3drop ;

: under   postpone >r ' compile, postpone r> ; immediate

: bits/cell   0 1 begin ?dup while 2* under 1+ repeat
   postpone literal ; immediate

: rshift   >r 0 begin r> dup bits/cell < while 1+ >r
           2* over 0< if 1+ then under 2* repeat drop nip ;
\ Since "an ambiguous condition exists if u is greater than or equal
\ to the number of bits in a cell", this would be acceptable.
\ : rshift   0 bits/cell rot do 2* over 0< if 1+ then under 2* loop nip ;
: lshift   begin ?dup while 1- under 2* repeat ;

: u/mod ( n d -- r q )
    ?dup 0= abort" Division by zero"
    0 >r 2>r		\ R: q n
    0 1 begin ?dup while dup 2* repeat
    r> 0 begin		\ S: [...1<<i...] d r
      2*		\ r <<= 1
      r@ 0< if 1+ then	\ if n&msb then r++
      r> 2* >r		\ n <<= 1
      2dup > if rot drop else \ if r>=d
        over -		      \ r -= d
        rot r> r> rot + >r >r \ q += 1<<i
      then
      2>r ?dup 2r> rot 0= until
    nip r> drop r> ;

: +-   0< if negate then ;
: abs   dup 0< if negate then ;
: /mod   2dup xor >r abs under abs u/mod r> +- ;

: space   bl emit ;
: ?.-     dup 0< if [char] - emit negate then ;
: digit   dup 9 > if [ char A 10 - ] literal else [char] 0 then + ;
: (.)     base @ u/mod  ?dup if recurse then  digit emit ;
: u.      (.) space ;
: .       ?.- u. ;

: ."   [char] " parse type ;
: ."   postpone s"  postpone type ; compile-only

: postpone-number   undef ;
' postpone-number  ' postpone-xt >body cell+ !

: /     /mod nip ;
: mod   /mod drop ;
: 2/    dup [ 0 invert 1 rshift invert ] literal and swap 1 rshift or ;

: 2@      dup cell+ @ swap @ ;
: 2!      swap over ! cell+ ! ;
: 2over   >r >r 2dup r> rot rot r> rot rot ;
: 2swap   >r rot rot r> rot rot ;

: chars   ;
: char+   1 chars + ;

: constant   create , does> @ ;

: decimal   10 base ! ;

: depth   data_stack 100 cells +  sp@  - cell /  1- ;

: variable   create cell allot ;

variable leaves

\ TODO: merge with metacompiler forward reference resolution.
: >resolve@   @ begin ?dup while dup @ here rot ! repeat ;

: r+   r> r> rot + >r >r ;

: do   leaves @  0 leaves !  postpone 2>r  postpone begin  0 ; compile-only
: leave   postpone branch  here leaves chain, ; compile-only
: +loop   ?dup if swap postpone r+ postpone again postpone then
   else postpone (+loop) postpone until then
   leaves >resolve@  leaves !  postpone unloop ; compile-only
: loop   1 postpone literal postpone +loop ; compile-only

: j   rp@ 3 cells + @ ;

: environment?   2drop 0 ;

: fill   rot rot ?dup if bounds do dup i c! loop drop else 2drop then ;

: max   2dup > if drop else nip then ;

: s>d   dup 0< ;

: pad   here 1024 + ;

variable hld
: <#     pad hld ! ;
: hold   -1 hld +!  hld @ c! ;
: #      drop base @ u/mod swap digit hold 0 ;
: #s     begin # 2dup or 0= until ;
: sign   0< if [char] - hold then ;
: #>     2drop hld @  pad hld @ - ;

: spaces   ?dup 0 > if 0 do space loop then ;

: u<   2dup xor 0< if nip 0< else - 0< then ;
: u+d ( u1 u2 -- d )   dup rot + dup rot u< negate ;
: d+   >r rot u+d rot + r> + ;
: d+-   0< if invert swap invert 1 u+d rot + then ;
: um*   1 2>r 0 0 rot 0 begin r@ while
           2r> 2dup 2* 2>r and if 2swap 2over d+ 2swap then 2dup d+
        repeat 2drop 2r> 2drop ;
: m*   2dup xor >r abs swap abs um* r> d+- ;

\ TODO: implement these stubs
: um/mod   nip u/mod ;
: sm/rem   2dup xor >r ( under dabs ) abs um/mod r> +- ;
: fm/mod   drop ;
: */mod    under m* sm/rem ;
: */       */mod nip ;

\ : dum* ( ud u -- ud' )   dup >r um* drop swap r> um* rot + ;
\ : dum/mod ( ud1 u1 -- ud2 u2 )   dup under u/mod swap under um/mod ;

: [']   ' postpone literal ; compile-only

: string-refill   0 ;

create string-source   0 -1 ' string-refill ' nop source,

: string-input ( a u -- )   string-source input !  0 >in !
   #source !  'source ! ;

: evaluate   save-input n>r  string-input interpret
   nr> restore-input abort" Bad restore-input" ;

create tib   256 allot

: key   here dup 1 0 read-file abort" Read error"  0= if bye then  c@ ;

: terminal-refill   tib 256 bounds do
      key dup 10 = if drop leave then
      i c!  1 #source +!
   loop -1 ;

: ok   state @ 0= if ."  ok" cr then ;

create terminal-source   tib 0 ' terminal-refill ' ok source,

: terminal-input   terminal-source input ! ;

: rp!   postpone (literal) RP , postpone ! ; immediate

: (quit)   return_stack 256 cells + rp!  0 csp !  postpone [
   terminal-input interpreting  bye ;

' (quit) ' quit >body !

: accept   save-input n>r  terminal-input  refill 0= if 2drop 0 exit then
   2>r source r> min swap over r> swap cmove  nr> restore-input abort" ?" ;

: uncount   under 1- over c! ;
: skip   begin source? while <source over = while repeat -1 >in +! then drop ;
: word   dup skip parse uncount ;
: find   count find-name ?dup 0= if uncount 0 then ;

: base*+ ( d u -- d' )   >r >r base @ um* r> base @ * +  r> 0 d+ ;

: 1/string ( a u -- a' u' )   1- under 1+ ;

: c>number ( c -- u )   [char] 0 -
   dup 9 > if [ char A char 0 - 10 - ] literal - else exit then
   dup 10 < if drop 36 exit then
   dup 35 > if [ char a char A - ] literal - then
   dup 10 < if drop 36 exit then ;

: u>number ( d a u -- d' a' u' )
   2>r begin 2r> 2dup 2>r while
      c@ c>number dup -1 > while  dup base @ < while
      base*+  2r> 1/string 2>r
   repeat then then drop 2r> ;

: >number   dup 0= if exit then
   2dup 2>r
   over c@ [char] - = dup >r if 1/string then
   u>number 2swap r@ d+- 2swap
   dup r> r@ + = if 2drop 2r> else 2r> 2drop then ;

: (number) ( a u -- )   0 0 2swap >number  ?dup ?undef 2drop  ?literal ;

' (number) ' number >body !
