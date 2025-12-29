.section .vectors
vector_table:
    /* For the stm32vldiscovery, the embedded SRAM (writable and readable memory) starts at 0x20000000 address.
       Here, we're moving 4 KB memory above the initial 0x20000000, which is 0x20000000 + 0x00001000 = 0x20001000.
       0x1000 = 4096 in decimal. 4 KB is just an arbitrary choice, the whole SRAM for this MCU is 32 KB, so we're
       basically reserve some part of it (4 KB out of 32 KB) to push some stuff to the memory stack. So, if we
       emulate this code with QEMU and connect GDB to QEMU, we should see the Stack Pointer (sp) register pointing to 0x20001000.
       We can execute the next code instruction in GDB with the `ni` command. As soon as it runs the `push {r1, r2}` instruction
       from our assembly code, we'll see the `sp` register now pointing to `0x20000ff8`, which is `0x20001000 - (2 * 4)`.
       We subtract from the original 0x20001000 `sp` address because the memory stack starts at higher address and move to lower
       address when the stack is filling up (so, it is an inverted stack in terms of memory address). And, we subtract (2 * 4 = 8)
       because we're pushing register values (`r1` and `r2` registers) in the stack, where each register has 4 bytes, which essentially means we require
       4 address in the memory (as each address acommodates only 1 byte). So, each register needs 4 memory addresses to be acommodated
       and as we're putting 2 register values, we need 2 * 4 addresses.
       If we run the `x 0x20000ff8` command in GDB to see the memory content for `0x20000ff8`, we'll see the value 7. If we run
       the `x 0x20000ffc` command in GDB, which is 4 bytes above `0x20000ff8`, we'll see the value 3. If we do `x 0x20001000`,
       we'll see the value 0. This means that, the program starts with the `sp` register at `0x20001000`, then when the `push {r1, r2}`
       instructions is executed, it first decrement the stack pointer to `x 0x20000ffc` and loads the first register value \
       (`r2` in this case, with value 3) to the memory at this address. Then, the stack pointer is decremented to the address
       `x 0x20000ff8` and the `r1` register value (equals 7) is written to it.
       As the location `x 0x20001000` started with value 0 and didn't have anything written to it, it'll be kept with a 0.

       Finally, when the code runs `pop {r2, r1}`, it first pops the value from the last address pointed by the
       stack pointer, which was `x 0x20000ff8`, retrieving the value 7 and assigning it to the register `r1`. Then,
       the stack pointer is incremented and the address `x 0x20000ffc` is now fetched, retrieving the value 3 and assigning
       it to the register `r2`. Then, the stack pointer address is incremented again, returning to the `0x20001000` address
       that we started with.
    */
    .word 0x20001000
    .word reset_handler
    .zero 400

    .section .text
    .align 1
    .type reset_handler, %function
reset_handler:
    mov r1, #7
    mov r2, #3

    push {r1, r2}

    mov r1, #5
    mov r2, #5

    pop {r2, r1}

    b .