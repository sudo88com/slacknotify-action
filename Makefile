.DEFAULT_GOAL := help
.PHONY: help files

help:
	@echo "Usage: make [TARGET]"
	@echo "Targets:"
	@echo "files           Show files"

files:
	@find . -path './.git' -prune -o -ls > FILES
