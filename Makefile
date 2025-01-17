F= docker-copyedit.py
D=$(basename $F)
B= 2017
FOR=today

FILES = *.py *.cfg
PYTHON3 = python3
PARALLEL = -j2

version1:
	@ grep -l __version__ $(FILES) | { while read f; do echo $$f; done; } 

version:
	@ grep -l __version__ $(FILES) | { while read f; do : \
	; Y=`date +%Y -d "$(FOR)"` ; X=$$(expr $$Y - $B); D=`date +%W%u -d "$(FOR)"` ; sed -i \
	-e "/^version /s/[.]-*[0123456789][0123456789][0123456789]*/.$$X$$D/" \
	-e "/^ *__version__/s/[.]-*[0123456789][0123456789][0123456789]*\"/.$$X$$D\"/" \
	-e "/^ *__version__/s/[.]\\([0123456789]\\)\"/.\\1.$$X$$D\"/" \
	-e "/^ *__copyright__/s/(C) [0123456789]*-[0123456789]*/(C) $B-$$Y/" \
	-e "/^ *__copyright__/s/(C) [0123456789]* /(C) $$Y /" \
	$$f; done; }
	@ grep ^__version__ $(FILES)

help:
	python docker-copyedit.py --help

###################################### TESTS
CENTOS=centos:centos8
UBUNTU=ubuntu:latest
check: ; $(MAKE) check0 && $(MAKE) check2 && $(MAKE) check3 
check0: ; test ! -f ../retype/retype.py || $(MAKE) type
check2: ; ./docker-copyedit-tests.py -vv --python=python2 --image=$(CENTOS)
check3: ; ./docker-copyedit-tests.py -vv --python=python3 --image=$(CENTOS)
check4: ; ./docker-copyedit-tests.py -vv --python=python3 --image=$(CENTOS) --docker=podman

test_%: ; ./docker-copyedit-tests.py $@ -vv --python=python3 --image=$(CENTOS)
est_%: ; ./docker-copyedit-tests.py t$@ -vv --python=python2 --image=$(CENTOS)
t_%: ; ./docker-copyedit-tests.py tes$@ -vv --python=python3 --image=$(CENTOS) --docker=podman

centos/test_%: ; ./docker-copyedit-tests.py $(notdir $@) -vv --python=python3 --image=$(CENTOS)
ubuntu/test_%: ; ./docker-copyedit-tests.py $(notdir $@) -vv --python=python3 --image=$(UBUNTU)
centos: ; ./docker-copyedit-tests.py -vv --python=python3 --image=$(CENTOS)
ubuntu: ; ./docker-copyedit-tests.py -vv --python=python3 --image=$(UBUNTU)
tests:  ; ./docker-copyedit-tests.py -vv --python=python3 --image=$(UBUNTU) --xmlresults=TEST-python3-ubuntu.xml

coverage: ; ./docker-copyedit-tests.py -vv --python=python3 --image=$(CENTOS) --xmlresults=TEST-python3-centos.xml --coverage

clean:
	- rm *.pyc 
	- rm -rf *.tmp
	- rm -rf tmp tmp.files
	- rm TEST-*.xml
	- rm -rf .coverage *,cover tmp.coverage.xml
	- rm setup.py README
	- rm -rf build dist *.egg-info

############## https://pypi.org/project/docker-copyedit/

README: README.md Makefile
	cat README.md | sed -e "/\\/badge/d" -e /take.patches/d -e /however.please/d > README
setup.py: Makefile
	{ echo '#!/usr/bin/env python3' \
	; echo 'import setuptools' \
	; echo 'setuptools.setup()' ; } > setup.py
	chmod +x setup.py
setup.py.tmp: Makefile
	echo "import setuptools ; setuptools.setup()" > setup.py

sdist bdist bdist_wheel:
	- rm -rf build dist *.egg-info
	$(MAKE) $(PARALLEL) README setup.py
	$(PYTHON3) setup.py $@
	- rm setup.py README

.PHONY: build
build:
	- rm -rf build dist *.egg-info
	$(MAKE) $(PARALLEL) README setup.py
	# pip install --root=~/local . -v
	$(PYTHON3) setup.py sdist
	- rm setup.py README
	twine check dist/*
	: twine upload dist/*

.PHONY: docker-test docker-example docker
docker-test: docker-example
	docker run --rm -v /var/run/docker.sock:/var/run/docker.sock $D:tests -vv
docker-example: docker
	docker run --rm -v /var/run/docker.sock:/var/run/docker.sock $D:latest FROM $D:latest INTO $D:tests set entrypoint $D-tests.py
docker:
	docker build . -t $D:latest

####### retype + stubgen
PY_RETYPE = ../retype
py-retype:
	set -ex ; if test -d $(PY_RETYPE); then cd $(PY_RETYPE) && git pull; else : \
	; cd $(dir $(PY_RETYPE)) && git clone git@github.com:ambv/retype.git $(notdir $(PY_RETYPE)) \
	; cd $(PY_RETYPE) && git checkout 17.12.0 ; fi
	python3 $(PY_RETYPE)/retype.py --version

mypy:
	zypper install -y mypy
	zypper install -y python3-click python3-pathspec
	$(MAKE) py-retype

MYPY = mypy
MYPY_STRICT = --strict --show-error-codes --show-error-context --no-warn-unused-ignores

type: type.d type.t
type.d:
	$(PYTHON3) $(PY_RETYPE)/retype.py docker-copyedit.py -t tmp.files -p .
	$(MYPY) $(MYPY_STRICT) tmp.files/docker-copyedit.py
	- rm -rf .mypy_cache
type.t:
	$(PYTHON3) $(PY_RETYPE)/retype.py docker-copyedit-tests.py -t tmp.files -p .
	$(MYPY) $(MYPY_STRICT) tmp.files/docker-copyedit-tests.py
	- rm -rf .mypy_cache

AUTOPEP8=autopep8
pep style: 
	$(MAKE) pep.di pep.d pep.ti pep.t
pep.d style.d:
	$(AUTOPEP8) docker-copyedit.py --in-place
	git --no-pager diff docker-copyedit.py
pep.di style.di:
	$(AUTOPEP8) docker-copyedit.pyi --in-place
	git --no-pager diff docker-copyedit.pyi
pep.t style.t:
	$(AUTOPEP8) docker-copyedit-tests.py --in-place
	git --no-pager diff docker-copyedit-tests.py
pep.ti style.ti:
	$(AUTOPEP8) docker-copyedit-tests.pyi --in-place
	git --no-pager diff docker-copyedit-tests.pyi


