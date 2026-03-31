## catnip
VERSION=0.1.8

## Do nothing by default
all:

## requires catnip to be installed
tests: FORCE
	./run_tests.sh && \
	echo "All tests OK"

# src/catnip.egg-info/PKG-INFO:Version
release:
	# Update version in pyproject.toml
	sed -i 's/^version *= *.*/version = "$(VERSION)"/' pyproject.toml
	sed -i 's/^VERSION=.*/VERSION="$(VERSION)"/' src/catnip/catnip.sh

	# Clean previous builds
	rm -rf dist build src/*.egg-info

	# Build package
	python3 -m build

	# Commit and tag
	git pull && \
	git add pyproject.toml && \
	git commit -e -m "New version $(VERSION)" . && \
	git tag -a "$(VERSION)" -m "v$(VERSION)" && \
	git push && git push --tags

	# Upload to PyPI (will prompt for API token)
	twine upload dist/*

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
