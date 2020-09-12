#!/usr/bin/env bash

rm example.eventlog example.eventlog.trace.json
stack install opentelemetry-extra
stack clean
stack build --ghc-options="-eventlog"
find .stack-work/ -name render | tail -n 1 | xargs -I '{}' cp '{}' .
./render ${@} +RTS -T -l -olexample.eventlog
eventlog-to-chrome read example.eventlog
cat example.eventlog.trace.json
