ARCH ?= arm
PKGS ?= zerotier wifi-qcom-ac wifi-qcom
CHANNEL ?= stable
OPTS ?= -b -r
IFACE ?= eth0
#CLIENTIP ?= 172.17.9.202
NET_OPTS ?= $(if $(CLIENTIP), "-a $(CLIENTIP)", "-i $(IFACE)")
URLVER ?= https://upgrade.mikrotik.com/routeros/NEWESTa7
VER_CHANNEL := $(firstword $(shell wget -q -O - $(URLVER).$(CHANNEL)))
VER ?= $(VER_CHANNEL)
VER_NETINSTALL ?= $(VER_CHANNEL)
PKGS_FILES := $(foreach pkg, $(PKGS), $(pkg)-$(VER)-$(ARCH).npk)
QEMU ?= ./i386
PLATFORM ?= $(shell uname -m)
.PHONY: run all service clean nothing dump extra-packages stable long-term testing arm arm64 mipsbe mmips smips ppc tile x86
.SUFFIXES:

run: all
	$(eval PKGS_FILES := $(shell for file in $(PKGS_FILES); do if [ -e "./$$file" ]; then echo "$$file"; fi; done))
	@echo starting netinstall... PLATFORM=$(PLATFORM) ARCH=$(ARCH) VER=$(VER) OPTS="$(OPTS)" NET_OPTS="$(NET_OPTS)" PKGS=$(PKGS) 
	@echo using $(PKGS_FILES)
	$(if $(findstring x86_64, $(PLATFORM)), , $(QEMU)) ./netinstall-cli-$(VER_NETINSTALL) $(OPTS) $(NET_OPTS) routeros-$(VER)-$(ARCH).npk $(PKGS_FILES)

service: all
	while :; do $(MAKE) run ARCH=$(ARCH) VER=$(VER); done

all: routeros-$(VER)-$(ARCH).npk netinstall-cli-$(VER_NETINSTALL) all_packages-$(ARCH)-$(VER).zip
	@echo finished download ARCH=$(ARCH) VER=$(VER) PKGS=$(PKGS) PLATFORM=$(PLATFORM)

dump: 
	@echo ARCH=$(ARCH) VER=$(VER) CHANNEL=$(CHANNEL)

clean:
	rm -rf *.npk *.zip *.tar.gz *.lock
	rm -f netinstall*
	rm -f LICENSE.txt

netinstall-$(VER_NETINSTALL).tar.gz:
	wget https://download.mikrotik.com/routeros/$(VER_NETINSTALL)/netinstall-$(VER_NETINSTALL).tar.gz

netinstall-cli-$(VER_NETINSTALL): netinstall-$(VER_NETINSTALL).tar.gz
	tar zxvf netinstall-$(VER_NETINSTALL).tar.gz
	mv netinstall-cli netinstall-cli-$(VER_NETINSTALL)
	touch netinstall-cli-$(VER_NETINSTALL)

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