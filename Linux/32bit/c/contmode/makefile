#
# Makefile for demo with hhlib.so


# Paths

LPATH = /usr/local/lib/hh400/

# Flags

CC = gcc

WARN = -Wall -Wno-format
COPTS = -g -O

CFLAGS = $(WARN) $(COPTS)

# Rules

%.o: %.c
	$(CC) -c $(CFLAGS) -I$(LPATH) -o $@ $<

# Variables

BINS = contmode
SRCS = contmode.c
OBJS = $(SRCS:%.c=%.o)

# Main target

all: $(BINS)

# Dependencies

contmode: contmode.o
	$(CC) $(OBJS) $(LPATH)hhlib.so -o $@

# Misc

clean:
	rm -f *.o *~ ~* *.bck core *.out
	rm -f $(BINS)

