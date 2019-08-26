#!/bin/sh

# Generate a new makefile for all .v files in the library.
coq_makefile -R "." HSLib -o makefile Base.v Control.v Thesis/snippets/Example1.v $(find Control Misc Parser Theory -name "*v")

# Build the library.
make

# Delete the makefile and related files.
rm makefile makefile.conf
