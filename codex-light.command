#!/bin/zsh
cd "$(dirname "$0")"
if [ ! -x "./CodexTrafficLight" ] || [ "CodexTrafficLight.swift" -nt "CodexTrafficLight" ]; then
  swiftc -framework Cocoa CodexTrafficLight.swift -o CodexTrafficLight || exit 1
fi
./CodexTrafficLight
