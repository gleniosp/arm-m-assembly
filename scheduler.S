# systick configuration registers // https://developer.arm.com/documentation/dui0552/a/cortex-m3-peripherals/system-timer--systick
.equ systick_csr,   0xE000E010
.equ systick_rvr,   0xE000E014
.equ systick_cvr,   0xE000E018
.equ systick_calib, 0xE000E01c
.equ timeout,       0x00ffffff

.section .vectors
vector_table:
    .word 0x20001000 // 4 KB memory above the initial 0x20000000 for the embedded SRAM location. This is where the initial stack pointer will point to.
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
    // This part of the code is used to restore the context (registers) stored by the systick_handler.
    // However, at the moment, this `magic` code is only using the default stack that we provided in the beginning of this
    // assembly code, that is, the stack pointed by the address `.word 0x20001000` which we defined in the `vector_table:`
    // part of the code in the beginning. To test the switching between the stacks that we manually created for the
    // 3 tasks (stack_1 for task main1, stack_2 for task main2, stack_3 for task main3), we need to make this `magic`
    // code also change the current Stack Pointer (sp) register to point to one of these three stacks in a round robin manner
    // every time the systick_handler is triggered, so the code keeps alternating between the tasks. This works because
    // each stack is setting the Program Counter (pc) register to point to its respective task, like stack_1 is setting
    // `.word main1`.
    //
    // As we don't have this round robin implementation yet, what are doing is to run GDB connected to the QEMU
    // and putting breakpoints in the `magic` label and a desired task. For example, we run the `break magic` command
    // to put a breakpoint at the `magic` code and also `break main1` to put a breakpoint at the `main1` code. Then,
    // we make the code continue with the `c` command until it stops at the first breakpoint, `magic`. At this point,
    // before magic can pop the registers from the context (stack) and load them into the CPU registers and handle the
    // control back to the exception handler, we manually do `set $sp=0x20000000` (because the `.data` section where
    // the `stack_1` is allocated starts at this address), which sets the stack pointer register to the location of the `stack_1`.
    // Then we do `c` again and let the `magic` code runs until the next breakpoint is reached.
    // As `magic` will now pop from the stack and we manually set the stack pointer to point to the `stack_1`
    // all 16 `.word...` instructions in the `stack_1` will be popped and loaded into the CPU registers. Then, `magic`
    // returns the control to the exception handler and now the CPU sees the new values for its registers, one of them
    // being the Program Counter (pc) register which will be pointing to the `main1` task. Then, as the next step,
    // the CPU will simply start executing the `main1` task as pointed by the pc register. So, we'll see GDB
    // breaking at the `main1` code/task next, because we put a breakpoint there.
    //
    // So, as a next step to improve this code, is to make the code switch between the 3 tasks without we doing this
    // via GDB manually by setting the stack pointer ourselves.
    // Also, we're loading the stack values into the embedded SRAM. When the board is first loaded with the program,
    // it'll load these values correctly. However, if we power off and on (restart) the board, it'll lose these initial
    // RAM values. While working with QEMU here, it is fine. However, in the real world, we should initially load
    // the `.data` section for the stacks in the program memory (flash memory) itself, along with the program code,
    // then, we'd have a logic in the exception handler to copy this stack data into the SRAM so we can do reads/writes
    // to the stack data there.
    pop {r0-r3}

    mov r8, r0
    mov r9, r1
    mov r10, r2
    mov r11, r3

    pop {r4-r7}

    bx lr // this will exit the exception handler (ISR - Interrupt Service Routine (ISR)), which is the timer in this case

# Tasks
    .section .text
    .p2align 4
    .globl main1
    .type main1, %function
main1:
    nop
    add r0, r0, #1;
    b main1

    .section .text
    .p2align 4
    .globl main2
    .type main2, %function
main2:
    nop
    add r1, r1, #2;
    b main2

    .section .text
    .p2align 4
    .globl main3
    .type main3, %function
main3:
    nop
    add r2, r2, #3;
    b main3

    // This tells the assembler to put the following code for the stacks (stack_1, stack_2 and stack_3) in the .data section.
    // And, the .data section is located in the RAM space according to the `map.ld` file. We made the RAM space point to the
    // Embedded SRAM location, which starts at the 0x20000000 address for the Cortex M3. This way, we can not only read
    // content from this location, but also write to it, which is required by our trick of pushing (writing) and
    // popping (reading) values from the stack. If we were to put the stacks in the same space as the rest of the code,
    // which is located in the .vectors and .text sections, which in turn is mapped to the MEM space by the `map.ld` file,
    // we wouldn't be able to write to it, only read.
    // As the stack_1 is the following code, this stack will then start at the beginning of the RAM space, 0x20000000.
    .data
    .align 4
stack_1:
    // The .word instructions below are addresses that will be load to all 16 registers for the Cortext M3 CPU.
    // This will happen when the systick_handler is triggered, which will change the Stack Pointer (SP) to point to
    // this stack_1 at first. Then, this will cause the CPU to load all these values from the stack_1 into the CPU registers,
    // which basically causes the CPU to switch to another context. As one of the registers, the Program counter (PC) is
    // pointing to the main1 address, it'll cause the CPU to start executing the code for the main1 task.
    // This is how we tricky the CPU to switch between tasks.
    // There is also a pattern in the addresses here, the hex numbers are not increasing fully in numerical order.
    .word 0x18
    .word 0x19
    .word 0x1a
    .word 0x1b
    .word 0x14
    .word 0x15
    .word 0x16
    .word 0x17
    .word 0x10
    .word 0x11
    .word 0x12
    .word 0x13
    .word 0x1c
    .word 0x309 // Link register (lr)
    .word main1 // Program counter register (pc)
    .word 0x01000000 // Program status register (xpsr)
    .zero 64
    .align 4
stack_2:
    .word 0x28
    .word 0x29
    .word 0x2a
    .word 0x2b
    .word 0x24
    .word 0x25
    .word 0x26
    .word 0x27
    .word 0x20
    .word 0x21
    .word 0x22
    .word 0x23
    .word 0x2c
    .word 0x309
    .word main2
    .word 0x01000000
    .zero 64
    .align 4
stack_3:
    .word 0x38
    .word 0x39
    .word 0x3a
    .word 0x3b
    .word 0x34
    .word 0x35
    .word 0x36
    .word 0x37
    .word 0x30
    .word 0x31
    .word 0x32
    .word 0x33
    .word 0x3c
    .word 0x309
    .word main3
    .word 0x01000000
    .zero 100
