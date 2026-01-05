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
    // Once the exception handler is run and we reach the `break_here` label, we exit the exception handler
    // and the forever loop provided by the `b .` instruction is running again, until a new exception happens.
    // If we run this code with `make qemu-scheduler` and then `make gdb-scheduler`, we can put a breakpoint for the
    // `break_here` label within GDB with `break break_here`. Then, we can continue the code with the `c` GDB command
    // and we'll see the r5 register incrementing by 1 whenever the systick exception handler runs.

    mov r5, #0 // just clearing r5, which will be used by the systick_handler later.

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
    // Once the exception happens, some registers are automatically saved by the CPU, but some not.
    // So, we can use these registers that aren't saved. Read more here: https://developer.arm.com/documentation/dui0552/a/the-cortex-m3-processor/exception-model/exception-entry-and-return
    add r5, r5, #1
break_here:
    bx lr // this will exit the exception handler (ISR - Interrupt Service Routine (ISR)), which is the timer in this case
