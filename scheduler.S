# systick configuration registers // https://developer.arm.com/documentation/dui0552/a/cortex-m3-peripherals/system-timer--systick
.equ systick_csr,   0xE000E010
.equ systick_rvr,   0xE000E014
.equ systick_cvr,   0xE000E018
.equ systick_calib, 0xE000E01c
.equ timeout,       0x00ffffff

.section .vectors
vector_table:
    .word 0x20001000 // 4 KB memory above the initial 0x20000000 for the embedded SRAM location
    .word reset_handler
.org 0x3C // ARM Cortex-M3 systick location (https://developer.arm.com/documentation/dui0552/a/the-cortex-m3-processor/exception-model/vector-table)
    .word systick_handler

    .zero 400

    .section .text
    .align 1
    .type reset_handler, %function
reset_handler:
    // The reset handler which will run when the CPU boots up will configure the Systick timer.
    // Then, the handler will keep running in loop forever due to the `b .` instruction.
    // However, as the timer is now configured, whenever the timer countdown goes to zero, it triggers the
    // Systick exception and runs the code for it (represented by the `systick_handler` in this assembly code).
    // Once the exception handler is run and we reach the `magic` label, we exit the exception handler
    // and the forever loop provided by the `b .` instruction is running again, until a new exception happens.
    // If we run this code with `make qemu-scheduler` and then `make gdb-scheduler`, we can put a breakpoint for the
    // `magic` label within GDB with `break magic`. Then, we can continue the code with the `c` GDB command
    // and we'll see the registers used by the systick handler changing whenever an exception triggers the handler.

    ldr r0, =systick_csr
    ldr r1, =systick_rvr
    ldr r2, =systick_cvr
    ldr r3, =timeout

    str r3, [r1]

    mov r3, #0x0
    str r3, [r2]

    mov r3, #0x7
    str r3, [r0]

    b .

    .section .text
    .align 1
    .type systick_handler, %function
systick_handler:
    // Once the exception happens, some registers are automatically saved by the CPU before entering the handler, but some not.
    // So, we can use these registers that aren't saved. Also, we need to push these registers to the stack so we can
    // store then. This way, if we can keep track of different tasks by push and popping (saving and restoring) the registers
    // (current context of a task) to/from the stack. Read more about these registers here: https://developer.arm.com/documentation/dui0552/a/the-cortex-m3-processor/exception-model/exception-entry-and-return
    push {r4-r7}

    // moving the other higher registers to lower registers so we can push their values, because
    // the push instruction doesn't seem to be able to push registers beyond r7.
    mov r0, r8
    mov r1, r9
    mov r2, r10
    mov r3, r11

    push {r0-r3}

magic:
    // this part of the code is used to restore the context (registers) stored by the systick_handler
    pop {r0-r3}

    mov r8, r0
    mov r9, r1
    mov r10, r2
    mov r11, r3

    pop {r4-r7}

    bx lr // this will exit the exception handler (ISR - Interrupt Service Routine (ISR)), which is the timer in this case
