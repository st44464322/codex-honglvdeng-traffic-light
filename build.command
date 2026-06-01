#!/bin/zsh
cd "$(dirname "$0")"
swiftc -framework Cocoa CodexTrafficLight.swift -o CodexTrafficLight
