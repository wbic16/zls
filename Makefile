.PHONY: start stop clean

start:
	./dev/dev.sh

stop:
	-pkill -f qemu-system-x86_64 || true

clean:
	-rm -rf dev/vms
