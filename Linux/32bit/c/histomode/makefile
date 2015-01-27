#
# Makefile for demo with phlib.so


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

BINS = histomode
SRCS = histomode.c
OBJS = $(SRCS:%.c=%.o)

# Main target

all: $(BINS)

# Dependencies

histomode: histomode.o
	$(CC) $(OBJS) $(LPATH)hhlib.so -o $@

# Misc

clean:
	rm -f *.o *~ ~* *.bck core
	rm -f $(BINS)

