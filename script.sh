#!/usr/bin/env bash

stack clean
stack build --ghc-options="-eventlog"
stack run -- +RTS -T -l -olpub_example.eventlog
