ARCH ?= arm arm64
PKGS ?= wifi-qcom-ac
CHANNEL ?= stable
OPTS ?= -b -r
IFACE ?= eth0
# PKGS_CUSTOM ?= ""
# example: CLIENTIP ?= 172.17.9.101
NET_OPTS ?= $(if $(CLIENTIP),-a $(CLIENTIP),-i $(IFACE))
URLVER ?= https://upgrade.mikrotik.com/routeros/NEWESTa7
channel_ver = $(firstword $(shell wget -q -O - $(URLVER).$(1)))
VER ?= $(call channel_ver,$(CHANNEL))
VER_NETINSTALL ?= $(call channel_ver,$(CHANNEL))
PKGS_FILES := $(foreach somearch, $(ARCH), $(foreach pkg, $(PKGS), $(pkg)-$(VER)-$(somearch).npk))

QEMU ?= ./i386
PLATFORM ?= $(shell uname -m)
FIRST_MULTIARCH_NETINSTALL_VER ?= 7.16

.PHONY: run all service download clean nothing dump extra-packages stable long-term testing arm arm64 mipsbe mmips smips ppc tile x86
.SUFFIXES:

define compare_versions
  $(if $(findstring $(word 1,$(sort $(1) $(2))),$(2)),true,false)
endef

run: all
	$(eval PKGS_FILES := $(shell for file in $(PKGS_FILES); do if [ -e "./$$file" ]; then echo "$$file"; fi; done))
	@echo starting netinstall... PLATFORM=$(PLATFORM) ARCH=$(ARCH) VER=$(VER) OPTS="$(OPTS)" NET_OPTS="$(NET_OPTS)" PKGS=$(PKGS) 
	@echo using $(PKGS_FILES)

	$(if $(call compare_versions,$(VER_NETINSTALL),$(FIRST_MULTIARCH_NETINSTALL_VER)), , \
		$(if $(findstring ,$(wordlist 2,2,$(ARCH))),, \
			$(error "You cannot have multiple ARCH items if you use netinstall-cli < 7.16")))

	$(if $(findstring x86_64, $(PLATFORM)), , $(QEMU)) ./netinstall-cli-$(VER_NETINSTALL) $(OPTS) $(NET_OPTS) routeros-$(VER)-$(ARCH).npk $(PKGS_FILES) $(PKGS_CUSTOM)

service: all
	while :; do $(MAKE) run ARCH=$(ARCH) VER=$(VER); done

download: all
	@echo use 'make' to run netinstall after connecting $(IFACE) or $(CLIENTIP) to router

all: $(foreach somearch,$(ARCH),routeros-$(VER)-$(somearch).npk netinstall-cli-$(VER_NETINSTALL) all_packages-$(somearch)-$(VER).zip)
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

routeros-$(VER)-%.npk:
	wget https://download.mikrotik.com/routeros/$(VER)/$@

all_packages-%-$(VER).zip:
	wget https://download.mikrotik.com/routeros/$(VER)/$@
	unzip -o all_packages-$*-$(VER).zip 

stable long-term testing: 
	$(MAKE) $(filter-out $@,$(MAKECMDGOALS)) CHANNEL=$@ ARCH=$(ARCH)

arm arm64 mipsbe mmips smips ppc tile x86: 
	$(MAKE) $(filter-out $@,$(MAKECMDGOALS)) CHANNEL=$(CHANNEL) ARCH=$@

nothing:
	while :; do sleep 3600; done
