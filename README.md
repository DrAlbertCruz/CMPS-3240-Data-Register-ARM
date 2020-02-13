# CMPS 3240 Lab: Registers and Memory

## Objectives

During this lab you will:

1. Learn the difference between registers and memory
2. Understand the concept of load-store architecture
3. Become familiar with register addressing format

## Prerequisites

* Conversion to/from hexadecimals
* Strong familiarity with `gdb` from previous lab
* 2's compliment
* Some idea of how memory is structure in a program: data, stack, heap, etc.

## Requirements

The following is a list of requirements to complete the lab. Some labs can completed on any machine, whereas some require you to use a specific departmental teaching server. You will find this information here.

### Software

We will use the following programs:

* `as`
* `ld`
* `git`
* `gdb`

### Compatability

This lab requires the departmental ARM server, `fenrir.cs.csubak.edu`. It will not work on `odin.cs.csubak.edu`, `sleipnir.cs.csubak.edu`, other PCs, etc. that have x86 processors. It may work on a Raspberry Pi or similar system on chip with ARM, but it must be ARMv8-a.

| Linux | Mac | Windows |
| :--- | :--- | :--- |
| Limited | No | No |

## Background

### Part 1 - Register Operations

This first part focuses on registers. The version of ARM we are using has 31 64-bit general-purpose registers, called `r0`-`r30` formally, but not in practice. You must specify if you are addressing 64 bits or 32 bits. `x0`-`x30` are 64-bit addressing and `w0`-`w30` are 32-bit addressing. `wt` refers to the same register as `xt`, but only the lower half--bits 0 to 31:

| 64-bit register `xt` |

| Upper half of 64-bit register | Lower half of 64-bit register - `wt` |

Register `r31` is a special register, referred to as `wxr` or `xzr` depending on size. *Do not use `w31` or `z31` in your code*. If used as a source register, it will supply a reference value of 0. If used a destination, the result will be discarded.

There are also various stack pointer registers, exception link registers, and program status registers which we will cover later on. There is also the `pc`, which is the address of the current instruction. There is also a flag register `cpsr` used for branching and exceptions/interrupts. Register 31 is a special register that, depending on the instruction, is used as a stack register or a zero-reference value.

Before proceeding you should have two terminals open. One for viewing `hello.s` and another for running the program with `gdb`. Go ahead and open up `hello.s` with your favorite text editor:

```bash
$ git clone https://github.com/DrAlbertCruz/CMPS-3240-Data-Register-ARM.git
...
$ cd CMPS-3240-Data-Register-ARM
$ vim hello.s
```

In the following, we go line-by-line. The file starts as in the previous lab:

```ARM
.text
.global _start
```

These directives indicate the start of instructions and the location of `_start` for the linker, respectively.

#### `w` vs. `x`

Consider the first few non-directive lines:

```ARM
start:
        mov x0, 0xffffffffffffffff
        mov w1, 0xffffffff
_a1:
```

The `mov` instruction used in this way loads a literal value into a register with a right-to-left assignment. `mov x0, 0xffffffffffffffff` places `0xffffffffffffffff` into `x0`. Note that this is the largest unsigned value possible that one can place in a 64-bit register. `mov w1, 0xffffffff` is similar, except note that it refers to `w1`. Verify this with `gdb`. Go ahead and `make`, then run `gdb`:

```shell
$ gdb ./hello.out
```

and set a breakpoint to `_start` and `_a1`, then run the program.

```gdb
(gdb) br _start
...
(gdb) br _a1
...
(gdb) run
```

It should stop at `_start`, which means no instructions from the program are executed. Check the initial values of the two registers:

```gdb
(gdb) info register x0 x1
x0             0x0	0
x1             0x0	0
```

So the registers start with value 0. Continue, to the next breakpoint and view the same registers, and take a look at the new values:

```gdb
(gdb) info register x0 x1
x0             0xffffffffffffffff	-1
x1             0xffffffff	4294967295
```

Indeed, `x1` was loaded with the smaller value. `gdb` is displaying the value of the register contents as 2's compliment numbers. However, this is only being displayed as such. The register is not intrinsically a signed integer. It could very well mean unsigned 0xffffffffffffffff or -1. It is up to you to keep track.<sup>a</sup>

#### Types and Signedness

If you're following along, there should be no need to quit `gdb` and set new breakpoints (unless you did the optional content in the footnote). We will now investigate the following code:

```ARM
_a1:
        mov x3, #12
        mov x4, 0xfffffffffffffffe
        add x5, x3, x4
_a2:
```

Assuming you did not quit `gdb`, continue to `_a2`. This is two `gdb` commands:

```gdb
(gdb) br _a2
...
(gdb) continue
```

The code snippet should load the literal 12 into `x3`. It should also load -2 into `x4`. You should quickly verify on a piece of paper that the two's compliment representation of -2 comes out to 0xfe. The third instruction should carry out 12 + (-2) and store the result in `x5`. Generally, three-argument arithmetic operations are left-to-right assignment with the first argument being the result and the second and third arguments being the operands. Now, check the values of `x3` thru `x5`:

```gdb
(gdb) info registers x3 x4 x5
x3             0xc	12
x4             0xfffffffffffffffe	-2
x5             0xa	10
```

As expected. The next section will cover the other type of data storage, memory.

### Part 2 - Instruction and Data Memory

In this section we cover how your assembly code can interact with the memory. In this lab we cover static memory, later labs will cover how to use the stack, and how to use the heap.

The name of memory your process interacts with is called virtual memory, or memory for short. Memory is a single-indexed segment of data. It holds instructions, data, the stack and the heap. It also holds reserved space for the supervisor process. Thus, your user process cannot access some parts of memory. To reiterate,  this memory holds machine instructions and data in the same structure. To place code in a specific place you use directives, such as `.text`. Like registers, type is not specified in the memory itself. It is up to you to note the length and type of your data. If it is an array, you also need to note the number of elements in the array.

For this lab, the environment you are using is byte-addressable. That is, an address refers to a specific byte. Note that this is less than the size of a word, which is four bytes.

When translating a high-level language, the assembler/linker places variables in memory. Unlike registers, these locations are named with identifiers. In practice, it is difficult to determine where variables are placed at compile-time. For this lab, `gbd` provides instructions to tell us the address of variables.

The most important concept of today's lab is the idea of a load-store architecture. The processor cannot perform arithmetic on memory. The general idea for load-store operations is:

1. Load the value from memory with an `ldr` or `ldp` instruction. The value is placed in a register.
2. Interact with the data as needed.
3. Store the value back into memory `str` or `stp`. This instruction transfers register values into memory.

As a 0-th step, the pointer (address of the memory to be loaded) should be located in a register. This often requires an `ldr` operation.

#### Static Memory

Scroll all the way down to the bottom of `hello.s`:

```arm
.data
.global badger
badger:
        .word   7

.global eagle
eagle:
        .word 0

.global coyote
coyote:
        .word   0
        .word   2
        .word   4
        .word   6
        .word   8
        .word   10

.global fox
.comm fox, 200, 4
```

This section is distinct from the `.text` section. The `.data` directive indicates that whatever follows should be placed in data memory. There are four variables in this program: `badger`, `eagle`, `coyote`, and `fox`. The `.global` directive helps the linker identify global variables.<sup>b</sup> This code is roughly equivalent to:

```c
int badger = 7;
int eagle = 0;
int coyote[] = { 0, 2, 4, 6, 8, 10 };
int fox[200];
```

First consider the snippet pertaining to `badger`. The chunk of data is requisitioned with `.word 7`, and the statement `badger:` associates this word with the identifier `badger`. Word length in ARM is 4 bytes, despite us working in 64-bit ARM. Recall from above that the `int` is not specified in the assembly code, only the length (32-bits for `int`, which means word length). It is up to you to remember that this holds an `int` because there is no notion of typing at this level.

The initialization of `coyote` is interesting because you requisition the data chunks piece by piece. Recall from CMPS 2010 that the variable `*coyote` merely points to the start of the array. Indeed, the first element here is the only labelled element. Everything else has to be indexed relative to `*coyote` if you want to access it.

`.comm fox, 200, 4` is unique from the others. We do not initialize the values. Instead, we use the `.comm` directive, which requisitions uninitialized array space. The first argument is the name, the second argument is the length, and the third argument is the length of each element in bytes. Again, `int` is 4-bytes, so that's why we enter 4 here.

If you have `gdb` open still, there are two commands that will help you peek at the variables in memory. Note that it does not matter which breakpoint you're at, because these are static values that start up with the process and we haven't modified them yet. Just make sure `gdb` is running the process. The first is to resolve the address:

```gdb
(gdb) p &badger
$1 = (<data variable, no debug info> *) 0x4100e8
```

The command is `p`. To view our static memory elements pass it the label identifier with an ampersand. `gdb` would have provided more information if you used `gcc` because it is more verbose with directives. The key here is the last item, which indicates that the variable `badger` is place at 0x4100e8. With this operation you can confirm that the variables are placed in consecutive locations.

The output of `gdb` can be formatted by appending characters to the command like so:

```gdb
(gdb) p/x &badger
$2 = 0x4100e8
(gdb) p/t &badger
$3 = 10000010000000011101000
```

`x` indicates hexadecimal. `t` indicates binary. The generalized format is `command`/`flags`. Now, suppose you want to view the contents instead. You use the command `x`. `x` takes three flags, and you should go to this reference to see the options.<sup>1</sup> Here is an example of viewing `badger`:

```gdb
(gdb) x/1xw &badger
0x4100e8:	0x00000007
```

An explanation of the flags from left-to-right: display 1 element, format it as a hexadecimal, elements are word length. Another version:

```gdb
(gdb) x/4db &badger
0x4100e8:	7	0	0	0
```

This command translates to: display the 4-bytes at the identifier `badger`, formatted as decimals. Note that you can see the data is little endian, that is, bytes within a word are stored in reverse order.

#### Arithmetic on memory

The first exercise we will implement on memory is to increment a single non-array variable. Consider the following commands:

```ARM
_a2:
        ldr x0, =badger
_b1:
        ldr x2, [x0]
        add x2, x2, 3
_b2:
        str x2, [x0]
_b3:
```

*The labels aren't necessary for operation, they just help us with `gdb` by defining the breakpoints.* We will take this one slowly (hence the many breakpoints). The first instruction, `ldr` fetches the memory address of `badger` and turns `x0` into a pointer. By convention, static labels must be prefixed with a `=`. Check what happened to `x0`:

```gdb
(gdb) br _b1
...
(gdb) run
...
(gdb) info registers x0
x0             0x4100e8	4260072
```

So, when loading the program, `badger` was placed at the memory address 0x4100e8. This is roughly equivalent to the following C statement: `x0 = &badger`. Continue to the `_b2` breakpoint. `ldr x2, [x0]` when used this way dereferences the memory address contained in `x0`. `ldr x2, [x0]` is roughly equivalent to the C statement: `x2 = *x0`, and we know that `x0` points to `badger`, so this fetches the value at `badger` and places it in `x2`. Investigating this with `gdb`:

```gdb
(gdb) br _b2
...
(gdb) continue
...
(gdb) info registers x0 x2
x0             0x4100e8	4260072
x2             0xa	10
(gdb) x/4db &badger
0x4100e8:	7	0	0	0
```

`x0` still contains the pointer the `badger`. `x2` was loaded with the initial value of `badger`, and we added 3 to it. Note that the `badger` memory location still holds 7. Continue to `_b3`.

```gdb
(gdb) break _b3
...
(gdb) continue
...
(gdb) x/1dw &badger
0x4100e8:	10
```

Finally, `str x2, [x0]` writes 10 into `badger`.

### Indexing Arrays

The brackets [] are similar to the C-language dereference operator except it can be used with the following forms:

1. [R]: Where R is a register. Example: `ldr x0, [x2]`. Just dereference `x2`.
2. [R,imm]: R is a register, and imm is the number of bytes to skip. Example: `ldr w1, [w2,4]`, which would be roughly equivalent to the C statement `int w1 = w1[1]`. *Note that imm is the number of bytes to skip, not the number of elements.*

There are more methods of indexing, which we will skip for this lab due to complexity.<sup>2</sup> The following ARM code:

```arm
_b3:
        ldr x1, =coyote
        ldr w2, [x1,#8]
        add w2, w2, #100
        str w2, [x1,#8]
_b4:
```

This code is roughly equivalent to the following C-language code:

```c
coyote[2] = coyote[2] + 100
```

Note that we use the `w` registers here to let the machine know it should only draw 32 bits (a word). If you tried to use `x` in this scenario it would attempt to draw 64 bits and read both `coyote[2]` and `coyote[3]` as a single 64 bit integer. This would cause a segmentation fault. *Feel free to try it if you want to see it in action.*

Also, note that 2 time the length of an integer is 8 bytes. Don't skip to `_b3` yet, first view the initial contents of the array:

```arm
(gdb) x/6dw &coyote
0x4100f0:	0	2	4	6
0x410100:	8	10
```

Now, skip to `_b4` and run the code:

```arm
(gdb) x/6dw &coyote
0x410108:	0	2	104	6
0x410118:	8	10
```

Viola, we incremented a single element within the array `coyote`. Now that that's done, you can get going on the lab finally.

### Approach

Your task is to use your knowledge of the above to copy the values of `coyote` into `fox`. `fox` is much larger than `coyote`, so you should only copy the first 6 elements. We haven't covered control of flow yet (for loops or if statements), so just explicitly code the instructions.

Note that you must change the values, not the pointers.

![Pointers.](https://cs.csubak.edu/~albert/C-658VsXoAo3ovC.jpg)

### Check Off

Demonstrate that your code works in `gdb` for full credit, if you finish early:

![Photos of Spiderman](https://i.imgur.com/cIfZ0EZ.jpg?1)

### References

<sup>1</sup>https://ftp.gnu.org/old-gnu/Manuals/gdb/html_node/gdb_55.html
<sup>2</sup>https://azeria-labs.com/memory-instructions-load-and-store-part-4/

### Footnotes

<sup>a</sup>You may be curious what happens if the value you attempt to stick in a `w` register is greater than 32 bits. Feel free to modify the line by adding a few more `f`s: `mov w1, 0xffffffffff`. When you re-`make` the binary file you should get an error. This has to do with the way ARM encodes the instruction, having inferred your intent to operate on 32-bits, yet being unable to represent without promoting the instruction to 64-bits.

<sup>b</sup>The things that your CMPS 2010 instructor warned you about but we will use liberally for simplicity in this class.
