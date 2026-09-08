#!/usr/bin/env bash

shellcheck --shell=bash --external-sources --source-path=lib \
	bin/* \
	lib/* \
	scripts/*

shfmt --language-dialect bash --diff \
	./**/*
