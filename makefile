PATCHES_DIR = patches/
PKGS_DIR = packages/
MIRROR_DIR = archlinux/
MIRROR_URL = rsync://mirror.umd.edu/archlinux

PKGS  = core/filesystem        \
    community/neofetch \
    AUR/yay 

#core/someothercrap    \

REPOS = $(subst /,.db,$(dir $(PKGS)))

all: fetch_rule $(REPOS)

fetch_rule:
	@echo rsync -rtlvHP --delete-after --delay-updates --safe-links    \
		$(MIRROR_URL) $(MIRROR_DIR)

%.db:
	$(MAKE) $(filter $(basename $@)/%, $(PKGS))

$(PKGS):
	@echo "-------------------------------------"
	@echo "making package Dir='$(@D)' pkg='$(@F)'"
	@echo "-------------------------------------"

	#restore package to default
	rm -rf "$(PKGS_DIR)$@"
	svn update "$(PKGS_DIR)$@"

	#patch -d "$(PKGS_DIR)$@/trunk" -p0 < $(PATCHES_DIR)/$(@F)/$(@F)_src.patch \
	#Patch new package
	if [ -d $(PATCHES_DIR)$(@F) ]; \
	then \
		cp $(PATCHES_DIR)$(@F)/$(@F)_src.patch $(PKGS_DIR)$@/trunk ; \
		patch -d "$(PKGS_DIR)$@" -p0 < $(PATCHES_DIR)$(@F)/$(@F).patch ; \
	else \
		if [ -f $(PATCHES_DIR)$(@F).patch ]; \
		then \
			patch -d "$(PKGS_DIR)$@" -p0 < $(PATCHES_DIR)$(@F).patch ; \
		fi \
	fi

	#Make package, move build to mirror
	cd "$(PKGS_DIR)/$@/trunk" && makepkg --sign --skipchecksums -f
	mv -f "$(PKGS_DIR)/$@/trunk/$(@F)"-* $(MIRROR_DIR)/pool/packages/

	#link package to the correct repos symlink folder
	#and repo-add the new package
	cd $(MIRROR_DIR)/$(@D)/*/*/ ;            \
	rm "$(@F)-"* &&                    \
	ln -s "../../../pool/packages/$(@F)"-*xz &&    \
	ln -s "../../../pool/packages/$(@F)"-*xz.sig &&   \
	repo-remove ./$(@D).db.*gz "$(@F)" &&        \
	repo-add ./$(@D).db.*gz "$(@F)-"*xz

.PHONY: all fetch_rule $(PKGS) %.db