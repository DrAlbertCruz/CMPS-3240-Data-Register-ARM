LINKER=ld
ASSEMBLER=as

hello.out: hello.o
	ld $< -o $@

hello.o: hello.s
	as $< -o $@

clean:
	rm -r -f *.out *.o
