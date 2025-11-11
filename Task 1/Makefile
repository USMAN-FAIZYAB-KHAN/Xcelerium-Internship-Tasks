.PHONY: clean
all: program
program: main.o mathlib.o
	g++ main.o mathlib.o -o program
main.o: main.cpp mathlib.h
	g++ -c main.cpp
mathlib.o: mathlib.cpp mathlib.h
	g++ -c mathlib.cpp
clean:
	rm -f *.o program
