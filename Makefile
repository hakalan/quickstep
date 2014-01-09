
COMPILER=../pypruss/PASM/pasm -b 
FILENAME = stepper.bin

.PHONY: clean all

all: $(FILENAME)

%.bin: %.p
	$(COMPILER) $<

clean: 
	rm -rf *.bin


