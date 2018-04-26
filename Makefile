all: README.pdf

README.pdf: README.md
	pandoc -t latex -o $@ $<
