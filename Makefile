## catnip
VERSION=0.1.4

## Do nothing by default
all:

## requires catnip to be installed
tests: FORCE
	./run_tests.sh && \
	echo "All tests OK"

# src/catnip.egg-info/PKG-INFO:Version
release:
	sed -i "s/^Version: .*/Version: $(VERSION)/" src/catnip_seq.egg-info/PKG-INFO
	git pull && \
	git commit -m "New version $(VERSION)" . && \
	git push && git tag -a "$(VERSION)" -m "v$(VERSION)" && \
	git push --follow-tags

release2master:
	git checkout master && \
        git pull && \
        git merge devel &&\
        git checkout devel

## run docker login -u username first
docker: FORCE
	docker build -f Dockerfile --tag bu/catnip:v$(VERSION) .

run_docker_test: docker
	docker run -i -t bu/catnip:v$(VERSION)



## Install in the subfolder  metabinkit
install:
	./install.sh -i ../catnip_install


FORCE:
