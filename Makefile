emacs ?= emacs

.PHONY: compile clean

compile:
	$(emacs) -batch --eval '(byte-compile-file "helm-make.el")'

clean:
	rm -f *.elc
