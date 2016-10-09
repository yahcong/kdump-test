# Makefile

.PHONY: build run

FILES: altsysrq.c Makefile.altsysrq runtest.sh Makefile PURPOSE

build:
	chmod a+x runtest.sh

run: $(FILES) build
	./runtest.sh
