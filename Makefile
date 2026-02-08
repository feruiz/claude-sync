.PHONY: test test-unit test-integration test-git

test:
	bash test/run_tests.sh

test-unit:
	bash test/run_tests.sh test/unit

test-integration:
	bash test/run_tests.sh test/integration

test-git:
	bash test/run_tests.sh test/git
