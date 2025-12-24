- `make qemu` in one terminal
  - to exit qemu later, press `Ctrl + A`, then `X`
- `make gdb` in another terminal
  - to exit gdb later, press `q`, then 'y' (for yes) and `ENTER`

To see the binary file from an executable, run: `arm-none-eabi-objcopy -O binary foo.elf foo.bin`. This will show how the program
(from the `foo.S` assembly file) is loaded into the memory as binary code.
To print the binary file content: `xxd -e -c 4 -g 4 foo.bin` (if needed, install `xxd` with `sudo apt install xxd`)
