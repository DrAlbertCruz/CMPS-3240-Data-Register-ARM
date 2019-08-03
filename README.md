# CMPS-3240-Data-Register-ARM

Requires hexadecimals
Strong familiarity with gdb
2's compliment

## Background

### Part 1 - Register Operations

This first part focuses on registers. The version of ARM we are using has 31 64-bit general-purpose registers `x0`-`x30`, the bottom halves of which are accessible as `w0`-`w30` (Bits 0-31). There are also four stack pointer registers, three exception link registers, and three program status registers which we will cover later on. There is also the `pc`, which is the address of the current instruction. There is also a flag register `cpsr`. Register 31 is a special register that, depending on the instruction, is used as a stack register or a zero-reference value.

Before proceeding you should have two terminals open. One for viewing `hello.s` and another for running the program with `gdb`. Go ahead and open up `hello.s` with your favorite text editor. The file starts as in the previous lab:

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
$ gdb ./hello
```

and set a breakpoint to `_start` and `_a1`, then run the program.

```gdb
(gdb) br _start
...
(gdb) br _a1
...
(gdb) run
``

It should stop at `_start`, which means no instructions from the program are executed. Check the initial values of the two registers:

```gdb
(gdb) info register x0 x1
x0             0x0	0
x1             0x0	0
```

So the start with value 0. Continue, to the next breakpoint and view the same registers, and take a look at the new values:

```gdb
(gdb) info register x0 x1
x0             0xffffffffffffffff	-1
x1             0xffffffff	4294967295
```

Indeed, `x1` was loaded with the smaller value. Here, `gdb` is displaying the value of the register contents as 2's compliment numbers. However, this is only being formatted by `gdb` for us. The register is not intrinsically a signed integer. It could very well mean unsigned 0xffffffffffffffff or -1. It is up to you to keep track.

*Optionally: You may be curious what happens if the value you attempt to stick in a `w` register is greater than 32 bits. Feel free to modify the line by adding a few more `f`s: `mov w1, 0xffffffffff`. When you re-`make` the binary file you should get an error. This has to do with the way ARM encodes the instruction, having inferred your intent to operate on 32-bits, yet being unable to represent without promoting the instruction to 64-bits.*

#### Types and Signedness

If you're following along, there should be no need to quit `gdb` and set new breakpoints (unless you did the optional content). We will now investigate the following code:

```ARM
_a1:
        mov x3, #12
        mov x4, 0xfffffffffffffffe
        add x5, x3, x4
_a2:
```

Assuming you did not quit `gdb`, continue to `_a2` (this is two `gdb` commands, you need to `br _a2` and `continue`). This code should load the literal 12 into `x3`. It should also load -2 into `x4`. You should quickly verify one a piece of paper that the two's compliment representation of -2 comes out to 0xFE. Its important to fill the number to the full 64 bits with a sign extension. The third instruction should carry out 12 + (-2) and store the result in `x5`. Generally, three-argument arithmetic operations are left-to-right assignment with the first argument being the result and the second and third arguments being the operands. Now, check on the values of `x3` thru `x5`:

```gdb
(gdb) info registers x3 x4 x5
x3             0xc	12
x4             0xfffffffffffffffe	-2
x5             0xa	10
```

As expected. The next section will cover the other type of data storage, memory.

### Part 2 - Instruction and Data Memory

In this section we cover how your assembly code can interact with the memory. In this lab we cover static memory, later labs will cover how to use the stack, and how to use the heap. With ARM, generally:

* The memory can be thought of as a long array with a single index that holds instructions, data, the stack, the heap and reserved space for the supervisor process. This means some parts of memory cannot be accessed by your user process.
* To reiterate a statement made above, this memory holds both your binary encoded instructions and data in the same array, just in different parts. You already saw a brief glimpse of this with the `.text` directive that indicated the following lines of code should be placed in the instruction part of memory.
* Like registers, type is not specified in the data itself. However, you must carefully note the length of your data. If it is an array, you also need to note the number of elements in the array.
* What you think of as variables in a high level language are stored in memory, not registers. These locations can be named with identifiers in your code, unlike registers.
* In practice, where these values are placed in memory may be challenging to determine at compile-time. When debugging, there will be a specific instruction to 'see'  the address where the data was placed.
* Perhaps the most important concept is the idea of a load-store architecture. You cannot perform arithmetic on memory directly.

The general idea for load-store operations is:
1. Often as a first step, you will set a register to point to the memory you want to interact with. Sometimes you will already have the pointer loaded, or you will know to interact with a specific address.
2. Load the value from memory with a single instruction. This instruction transfers the data from memory into a register.
3. Interact with the data as needed.
4. Store the value back into memory with single instruction. This instruction transfers the data from a register into memory.

#### Static Memory

Scroll all the way down to the bottom of `hello.s`:

```ARM
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

This section is distinct from the `.text` section, the `.data` directive indicates that whatever follows should be placed in static memory. There are four variables in this program: `badger`, `eagle`, `coyote`, and `fox`. The `.global` directive helps the linker identify global variables (the things that your CMPS 2010 instructor warned you about but we will use liberally for simplicity in this class). The chunk of data is requisitioned with `.word 7`, and the statement `badger:` associates this 'word' with the identifier `badger`. Word length in ARM is 4 bytes, despite us working in 64-bit ARM. This code is roughly equivalent to:

```c
int badger = 7;
int eagle = 0;
int coyote[] = { 0, 2, 4, 6, 8, 10 };
int fox[200];
```

*Recall from above that the `int` is not specified in the assembly code, only the length (32-bits for `int`, which means word length).*

The initialization of `coyote` is interesting because you requisition the data chunks piece by piece. Recall from CMPS 2010 that the variable `*coyote` merely points to the start of the array. Indeed, the first element here is the only labelled element. Everything else has to be indexed relative to `*coyote`.

`.comm fox, 200, 4` is unique from the others. We do not initialize is. Instead, we use the `.comm` directive, which orders the linker to requisition uninitialized array space. The first argument is the name, the second argument is the length, and the third argument is the length of each element in bytes. Again, `int` is 4-bytes, so that's why we enter 4 here.

So that was fun and interesting, if you have `gdb` open still, there are two commands that will help you peek at the variables in memory. The first is to resolve the address:

```gdb
(gdb) p &badger
$1 = (<data variable, no debug info> *) 0x4100e8
```

The command is `p`. To view our static memory elements pass it the label identifier with an ampersand. `gdb` would have provided more information if you used `gcc` because it is more verbose with directives. The key here is the last item, which indicates that the variable `badger` is place at 0x4100e8. Before we move on the next concept you should know that when printing to the screen the output of `gdb` can be formatted by appending characters to the command like so:

```gdb
(gdb) p/x &badger
$2 = 0x4100e8
(gdb) p/t &badger
$3 = 10000010000000011101000
```

*Supposedly they those 't' because it stands for 'two', no idea why they didn't go with 'b' instead.* So the generalized format is `command`/`flags`. Now, suppose you want to view the contents instead. You use the command `x`. `x` takes three flags, and you should go to this reference to see the options.<sup>1</sup> Here is an example of viewing `badger`:

```gdb
(gdb) x/1xw &badger
0x4100e8:	0x00000007
```

The flags from left-to-right: display 1 element, format it as a hexadecimal, elements are word length. Another version:

```gdb
(gdb) x/4db &badger
0x4100e8:	7	0	0	0
```

This command translates to: display the 4-bytes at the identifier `badger`, formatted as decimals. Note that you can see the data is little endian, that is, bytes within a word are stored in reverse order.

### References

<sup>1</sup>https://ftp.gnu.org/old-gnu/Manuals/gdb/html_node/gdb_55.html
