#!/bin/sh

test $# -lt 2 && echo "Usage: <contact> <message>" >&2 && exit 1

TGLINK=${HOME}/.tglink

test ! -p $TGLINK && echo "tglink is not running" && exit 2

echo "msg $@" > $TGLINK
