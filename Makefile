PROJECT=foo
CPU ?= cortex-m3
BOARD ?= stm32vldiscovery

qemu:
	arm-none-eabi-as -mthumb -mcpu=$(CPU) -g -c foo.S -o foo.o
	arm-none-eabi-ld -Tmap.ld foo.o -o foo.elf
	arm-none-eabi-objdump -D -S foo.elf > foo.elf.lst
	arm-none-eabi-readelf -a foo.elf > foo.elf.debug
	qemu-system-arm -S -M $(BOARD) -cpu $(CPU) -nographic -kernel $(PROJECT).elf -gdb tcp::1234

gdb:
	gdb-multiarch -q $(PROJECT).elf -ex "target remote localhost:1234"

qemu-scheduler:
	arm-none-eabi-as -mthumb -mcpu=$(CPU) -g -c scheduler.S -o scheduler.o
	arm-none-eabi-ld -Tmap.ld scheduler.o -o scheduler.elf
	arm-none-eabi-objdump -D -S scheduler.elf > scheduler.elf.lst
	arm-none-eabi-readelf -a scheduler.elf > scheduler.elf.debug
	qemu-system-arm -S -M $(BOARD) -cpu $(CPU) -nographic -kernel scheduler.elf -gdb tcp::1234

gdb-scheduler:
	gdb-multiarch -q scheduler.elf -ex "target remote localhost:1234"

clean:
	rm -rf *.out *.elf .gdb_history *.lst *.debug *.o *.bin
