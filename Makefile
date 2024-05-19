ARCH ?= arm
PKGS ?= zerotier wifi-qcom-ac wifi-qcom
CHANNEL ?= stable
CIP ?= 172.17.9.202
OPTS ?= -b -r
URLVER ?= https://upgrade.mikrotik.com/routeros/NEWESTa7
VER_CHANNEL := $(firstword $(shell wget -q -O - $(URLVER).$(CHANNEL)))
VER ?= $(VER_CHANNEL)
VER_NETINSTALL ?= $(VER)
PKGS_FILES := $(foreach pkg, $(PKGS), $(pkg)-$(VER)-$(ARCH).npk)
QEMU ?= ./i386
PLATFORM ?= $(shell uname -m)
.PHONY: run all clean nothing dump extra-packages stable long-term testing arm arm64 mipsbe mmips smips ppc tile x86
.SUFFIXES:

run: all
	$(eval PKGS_FILES := $(shell for file in $(PKGS_FILES); do if [ -e "./$$file" ]; then echo "$$file"; fi; done))
	@echo starting netinstall... ARCH=$(ARCH) VER=$(VER) OPTS="$(OPTS)" PLATFORM=$(PLATFORM) CIP=$(CIP) PKGS=$(PKGS) 
	@echo using $(PKGS_FILES)
	$(if $(findstring x8_64, $(PLATFORM)), , $(QEMU)) ./netinstall-cli-$(VER) $(OPTS) -a $(CIP) routeros-$(VER)-$(ARCH).npk $(PKGS_FILES)

all: routeros-$(VER)-$(ARCH).npk netinstall-cli-$(VER) all_packages-$(ARCH)-$(VER).zip
	@echo finished download ARCH=$(ARCH) VER=$(VER) PKGS=$(PKGS) PLATFORM=$(PLATFORM)

dump: 
	@echo ARCH=$(ARCH) VER=$(VER) CHANNEL=$(CHANNEL)

clean:
	rm -rf *.npk *.zip *.tar.gz *.lock
	rm -f netinstall*
	rm -f LICENSE.txt

netinstall-$(VER).tar.gz:
	wget https://download.mikrotik.com/routeros/$(VER)/netinstall-$(VER).tar.gz

netinstall-cli-$(VER): netinstall-$(VER).tar.gz
	tar zxvf netinstall-$(VER).tar.gz
	mv netinstall-cli netinstall-cli-$(VER)
	touch netinstall-cli-$(VER)

routeros-$(VER)-$(ARCH).npk:
	wget https://download.mikrotik.com/routeros/$(VER)/$@

all_packages-$(ARCH)-$(VER).zip:
	wget https://download.mikrotik.com/routeros/$(VER)/$@
	unzip -o all_packages-$(ARCH)-$(VER).zip 

stable long-term testing: 
	$(MAKE) $(filter-out $@,$(MAKECMDGOALS)) CHANNEL=$@ ARCH=$(ARCH)

arm arm64 mipsbe mmips smips ppc tile x86: 
	$(MAKE) $(filter-out $@,$(MAKECMDGOALS)) CHANNEL=$(CHANNEL) ARCH=$@

nothing:
	while :; do sleep 3600; done