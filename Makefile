
testfiles=$(wildcard test/test_*)
tests=$(patsubst test/%, %, $(testfiles))

all: $(tests)

$(tests): 
	test/$@
	
test: $(testfiles) $(tests)

.PHONY: test $(tests)

