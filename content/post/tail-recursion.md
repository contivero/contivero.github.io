---
title: "Tail recursion"
date: 2022-08-12T13:25:02+02:00
draft: false
---

When a function's last action is calling itself, we say it's _tail recursive_.

The interest in these functions is that they can be optimized easily by
compilers, which can replace the recursive implementation by a more performant
iterative one. A tail-recursive implementation is able to execute an iterative
process in constant space, even if the process is described by a recursive
procedure.

Guy L. Steele popularized the automatic optimization of tail
recursions,(although replacing a JSR+RET with JMP was possibly known earlier).

If there is a tail-recursive implementation of a function, then special
iteration constructs (e.g. while and for loops in languages such as C) are
useful only as syntactic sugar, since the iteration can otherwise be expressed
by the usual function call.

## Examples:
```haskell
length :: [a] -> Int
length []     = 0
length (x:xs) = 1 + length xs
```
This is not tail-recursive. Given that when asking for the length of a list, we
know that we will need to go to the end of it, it makes sense to define length
in a tail-recursive way:
```haskell
length :: [a] -> Int
length xs = lenAcc xs 0
  where lenAcc []     n = n
        lenAcc (_:ys) n = lenAcc ys (n+1)
```
This definition is (with exception of `where`) verbatim from Haskell's prelude.

The standard definition of filter is also not tail-recursive:
```haskell
filter _ []     = []
filter p (x:xs)
    | p x       = x : filter p xs
    | otherwise =     filter p xs
```
We can define a tail-recursive version as follows:
```haskell
filter f xs = filter' xs []
  where filter' [] rs = reverse rs
        filter' x:xs rs
            | f x       = filter xs (x :xs)
            | otherwise = filter' xs rs
```
However, tail recursion imposes strictness, since only the very last call can
return something. This implementation thus fails for infinite lists (e.g. we
can't `take 10 (filter even [1..])`), which is generally undesirable.

The same happens with the standard map:
```haskell
map f []     = []
map f (x:xs) = f x : map f xs
```
which may be defined tail-recursively as follows: 
```haskell
map f (x:xs) = map' xs []
  where map' [] rs     = reverse rs
        map' (x:xs) rs = map' xs (f x : rs)
```
The second equation for `map'` is clearly tail-recursive, and since reverse is
tail-recursive, the whole of `map` is. This has, however, the same problem as
any tail-recursive function has: it prevents returning a partial result under
lazy evaluation.

Note that foldl is tail-recursive:
```haskell
foldl f e []     = e                  
foldl f e (x:xs) = foldl f (f e x) xs
```
However, foldl is discouraged in Haskell because even though it is
tail-recursive, its accumulating parameter isn't evaluated before the recursive
call due to Haskell's normal-order evaluation, for example:
```haskell
  foldl (+) 0 [1,2,3,4]
  foldl (+) (0 + 1) [2,3,4]
  foldl (+) ((0 + 1) + 2) [3,4]
  foldl (+) (((0 + 1) + 2) + 3) [4]
  foldl (+) ((((0 + 1) + 2) + 3) + 4) []
  ((((0 + 1) + 2) + 3) + 4)
  (((1 + 2) + 3) + 4)
  ((3 + 3) + 4)
  (6 + 4)
  10
```
As can be seen, thunks are created and kept in memory until the end of the list
is reached, and they can start to be evaluated. This is unnecessarily costly,
can lead to stack overflows, and is contrary to what we would normally expect of a
tail-recursive call. That's why there is `foldl'`, a strict variant of `foldl`
which forces evaluation of each thunk before recursing:
```haskell
  foldl' (+) 0 [1,2,3,4]
  foldl' (+) (0 + 1) [2,3,4]
  foldl' (+) (1 + 2) [3,4]
  foldl' (+) (3 + 3) [4]
  foldl' (+) (6 + 4) []
  10
```

## Comparison using C

Given the two following simple definitions of a factorial function in C:
```C
/* tail-recursive-factorial.c */

unsigned 
fact(unsigned n, unsigned acc) {
    if (n == 0)
        return acc;
    return fact(n - 1, n * acc);
}
```
```C
/* iterative-factorial.c */

unsigned 
fact(unsigned n) {
    unsigned ret = 1;

    while (n != 0) {
        ret *= n--;
    }
    return ret;
}
```
Both are equivalent, provided we pass `1` as the accumulating parameter when
calling the first one (that is, $5!$ would be `fact(5, 1)`). The first function
is defined recursively, while the second one iteratively. One might mistakenly
assume the iterative one to be more efficient, but that doesn't need to be the
case. As an example, after calling GCC (version 7.3.1) with `-O2 -S` (to enable
optimizations, and generate assembly output), I get the following definitions of
`fact`:

```asm
# iterative-factorial.s

fact:
.LFB11:
	.cfi_startproc
	test	edi, edi  # Test whether n == 0.
	mov	eax, 1        # ret = 1;
	je	.L4           # Go to .L4 if edi was 0
	.p2align 4,,10
	.p2align 3
.L3:
	imul	eax, edi  # ret *= n;
	sub	edi, 1        # n--;
	jne	.L3           # if n != 0, loop once more.
	rep ret
	.p2align 4,,10
	.p2align 3
.L4:
	rep ret
	.cfi_endproc
```
```asm
# tail-recursive-factorial.s

.LFB0:
	.cfi_startproc
	test	edi, edi
	mov	eax, esi      # store in eax the value of acc.
	je	.L5
	.p2align 4,,10
	.p2align 3
.L2:
	imul	eax, edi
	sub	edi, 1
	jne	.L2
.L5:
	rep ret
	.cfi_endproc
```
Aside from label differences, and some alignment instructions, both codes are
doing exactly the same: multiply eax and edi, decrease edi, and loop until edi
is 0.

## Final remarks
A downside of tail-recursion is that, since the code is compiled into a loop,
there is no stack trace, which can be counterintuitive when debugging. This is
why python (purposely) doesn't optimize tail-recursive calls.


References: 

1. History of tail-call optimization (https://erlang.org/pipermail/erlang-questions/2006-August/022055.html)
2. Structure and Interpretation of Computer Programs, p.35-36.
3. https://wiki.haskell.org/Fold
4. https://mail.haskell.org/pipermail/haskell-cafe/2011-March/090237.html
5. http://neopythonic.blogspot.com.ar/2009/04/tail-recursion-elimination.html
