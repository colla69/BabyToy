.PHONY: run try test lint snapshot

run:
	swift run BabyToy

try:
	swift run BabyToy --exit-after 60

test:
	swift test

lint:
	swift format lint --strict --recursive Sources Tests

snapshot:
	swift run BabyToy --snapshot .build/snapshots
