PATCHES_DIR = patches/
PKGS_DIR = packages/
PKGS_REF_DIR = packages_ref/
MIRROR_DIR = archlinux/
MIRROR_URL = rsync://mirror.umd.edu/archlinux

SHELL := /bin/bash
MAKEFLAGS="-j8"


PKGS  = core/filesystem			\
	core/grub            		\
    community/neofetch			\
    community/yay 


REPOS = $(sort $(subst /,.db,$(dir $(PKGS))))

all: fetch_rule $(REPOS) publish

dry: $(REPOS)

local: fetch_rule $(REPOS)

publish:
	./sync.sh

init:
	@echo "Creating Folder Structure"

	@#Create Required Folder structure (ones on .gitignore)
	@mkdir packages
	cd packages && svn checkout --depth=empty svn://svn.archlinux.org/packages
	mv packages/packages packages/core
	cd packages && svn checkout --depth=empty svn://svn.archlinux.org/community

	@mkdir packages_ref
	cd packages_ref && svn checkout --depth=empty svn://svn.archlinux.org/packages
	mv packages_ref/packages packages/core
	cd packages_ref && svn checkout --depth=empty svn://svn.archlinux.org/community

	
	@echo "First pull of mirror, thit will take a long time"
	@#Get arch mirror
	$(MAKE) fetch_rule
	

fetch_rule:
	@echo "This might take a while... updating mirror"
	rsync -rtlvHP --delete-after --delay-updates --safe-links    \
		$(MIRROR_URL) $(MIRROR_DIR)

%.db:
	rm -rf packages/community/*
	rm -rf packages/core/*
	$(MAKE) $(filter $(basename $@)/%, $(PKGS))
# $(PKGS):

$(PKGS):
	@echo "-------------------------------------"
	@echo "making package Dir='$(@D)' pkg='$(@F)' @='$@'"
	@echo "-------------------------------------"

        # @echo 
	# @echo "$(PKGS_DIR)"
	#Check if we need to update the package
	@rm -rf "$(PKGS_REF_DIR)/$@"



	@if [ "$(shell svn update $(PKGS_REF_DIR)/$@ | wc -l )" == 2 ] ; then     \
		cd "$(PKGS_REF_DIR)/$(@D)";					\
		git clone "https://aur.archlinux.org/$(@F).git";		\
	else 									\
		svn update "$(PKGS_REF_DIR)/$@"; 			        \
	fi

        
	#decide if we should build the shit
	@if [ -d "$(PKGS_REF_DIR)/$@/trunk" ]; 			                	\
	then 										\
                localPkg="${shell ./scripts/pkgbuild_ver.sh $(PKGS_DIR)/$@/trunk 2> /dev/null}"; 	\
                newPkg="${shell ./scripts/pkgbuild_ver.sh $(PKGS_REF_DIR)/$@/trunk 2> /dev/null}";    \
                if [ "$$localPkg" != "$$newpkg" ]; then       \
                    	make dir=$(@D) pkg=$(@F) target=$@ build;                      \
                fi                                              \
	else 										\
                localPkg="${shell ./scripts/pkgbuild_ver.sh $(PKGS_DIR)/$@ 2> /dev/null}"; 	\
                newPkg="${shell ./scripts/pkgbuild_ver.sh $(PKGS_REF_DIR)/$@ 2> /dev/null}";    \
                if [ "$$localPkg" != "$$newpkg" ]; then       \
                    	make dir=$(@D) pkg=$(@F) target=$@ build  ;                     \
                fi                                              \
	fi

build:
	@echo "yeet"
	$(MAKE) dir=$(dir) pkg=$(pkg) target=$(target) fetch
	$(MAKE) dir=$(dir) pkg=$(pkg) target=$(target) patch
	$(MAKE) dir=$(dir) pkg=$(pkg) target=$(target) compile
	$(MAKE) dir=$(dir) pkg=$(pkg) target=$(target) package

fetch: 
	#pull new package version
	#if git ls-remote -q "https://aur.archlinux.org/$(@F).git" ; then \
	#
	
	if [ "$(shell svn update $(PKGS_DIR)/$(target) | wc -l)" == 2 ] ; then \
		cd "$(PKGS_DIR)/$(dir)"; 				\
		git clone "https://aur.archlinux.org/$(pkg).git"; 	\
	else 								\
		svn update "$(PKGS_DIR)/$(target)"; 				\
	fi
patch:
	#Patch new package
	if [ -d "$(PATCHES_DIR)/$(pkg)" ]; 						\
	then 										\
		cp "$(PATCHES_DIR)/$(pkg)/$(pkg)_src.patch" "$(PKGS_DIR)/$(target)/trunk" ;	\
		patch -d "$(PKGS_DIR)/$(target)" -p0 < "$(PATCHES_DIR)/$(pkg)/$(pkg).patch" ;    \
										        \
	elif [ -f "$(PATCHES_DIR)/$(pkg).patch" ];				        \
	then 									        \
		patch -d "$(PKGS_DIR)/$(target)" -p0 < "$(PATCHES_DIR)/$(pkg).patch" ;  	\
										        \
	fi
compile:
	#Make package, move build to mirror
	if [ -d "$(PKGS_DIR)/$(target)/trunk" ]; 			                	\
	then 										\
		( cd "$(PKGS_DIR)/$(target)/trunk" && makepkg -s --sign --skipchecksums -f ) ; \
		mv -f "$(PKGS_DIR)/$(target)/trunk/$(pkg)"-* "$(MIRROR_DIR)/pool/packages/" ; 	\
	else 										\
                ( cd "$(PKGS_DIR)/$(target)/" && makepkg -s --sign --skipchecksums -f ) ;	\
                mv -f "$(PKGS_DIR)/$(target)/$(pkg)"-*pkg* "$(MIRROR_DIR)/pool/packages/" ;	\
	fi
package:
	#link package to the correct repos symlink folder
	#and repo-add the new package
	cd $(MIRROR_DIR)/$(dir)/*/*/ ;            			\
	rm "$(pkg)-"* || true &&                    			\
	ln -s "../../../pool/packages/$(pkg)"-*tar*.xz || true &&   	\
	ln -s "../../../pool/packages/$(pkg)"-*tar*.zst || true &&  	\
	ln -s "../../../pool/packages/$(pkg)"-*tar*.sig &&   		\
	repo-remove ./$(dir).db.*gz "$(pkg)" || true   &&        		\
	repo-add ./$(dir).db.*gz "$(pkg)-"*xz || true && 			\
	repo-add ./$(dir).db.*gz "$(pkg)-"*zst || true

.PHONY: all fetch_rule $(PKGS) %.db
