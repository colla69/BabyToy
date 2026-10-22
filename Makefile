.PHONY: test lint snapshot

test:
	swift test

lint:
	swift format lint --strict --recursive Sources Tests

snapshot:
	swift run BabyToy --snapshot .build/snapshots
