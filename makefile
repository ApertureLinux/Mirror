PATCHES_DIR = patches/
PKGS_DIR = packages/
MIRROR_DIR = archlinux/
MIRROR_URL = rsync://mirror.umd.edu/archlinux

PKGS  = core/filesystem        \
    community/neofetch \
    community/yay 


REPOS = $(sort $(subst /,.db,$(dir $(PKGS))))

all: fetch_rule $(REPOS)

init:
	@echo "Creating Folder Structure"

	@#Create Required Folder structure (ones on .gitignore)
	@mkdir packages
	cd packages && svn checkout --depth=empty svn://svn.archlinux.org/packages
	mv packages/packages packages/core
	cd packages && svn checkout --depth=empty svn://svn.archlinux.org/community

	
	@echo "First pull of mirror, thit will take a long time"
	@#Get arch mirror
	$(MAKE) fetch_rule
	

fetch_rule:
	@echo "This might take a while... updating mirror"
	rsync -rtlvHP --delete-after --delay-updates --safe-links    \
		$(MIRROR_URL) $(MIRROR_DIR)

%.db:
	$(MAKE) $(filter $(basename $@)/%, $(PKGS))

$(PKGS):
	@echo "-------------------------------------"
	@echo "making package Dir='$(@D)' pkg='$(@F)'"
	@echo "-------------------------------------"

	#restore package to default
	rm -rf "$(PKGS_DIR)/$@"

	#pull new package version
	#if git ls-remote -q "https://aur.archlinux.org/$(@F).git" ; then \
	#
	
	if [ "$(shell svn update $(PKGS_DIR)/$@ | wc -l)" == 2 ] ; then \
		cd "$(PKGS_DIR)/$(@D)"; \
		git clone "https://aur.archlinux.org/$(@F).git"; \
	else \
		svn update "$(PKGS_DIR)/$@"; \
	fi


	#patch -d "$(PKGS_DIR)$@/trunk" -p0 < $(PATCHES_DIR)/$(@F)/$(@F)_src.patch \


	#Patch new package
	if [ -d "$(PATCHES_DIR)/$(@F)" ]; \
	then \
		cp "$(PATCHES_DIR)/$(@F)/$(@F)_src.patch" "$(PKGS_DIR)/$@/trunk" ; \
		patch -d "$(PKGS_DIR)/$@" -p0 < "$(PATCHES_DIR)/$(@F)/$(@F).patch" ; \
\
	elif [ -f "$(PATCHES_DIR)/$(@F).patch" ]; \
	then \
		patch -d "$(PKGS_DIR)/$@" -p0 < "$(PATCHES_DIR)/$(@F).patch" ; \
\
	fi

	#Make package, move build to mirror
	if [ -d "$(PKGS_DIR)/$@/trunk" ]; \
	then \
		( cd "$(PKGS_DIR)/$@/trunk" && makepkg --sign --skipchecksums -f ) ; \
		mv -f "$(PKGS_DIR)/$@/trunk/$(@F)"-* "$(MIRROR_DIR)/pool/packages/" ; \
	else \
                ( cd "$(PKGS_DIR)/$@/" && makepkg --sign --skipchecksums -f ) ; \
                mv -f "$(PKGS_DIR)/$@/$(@F)"-*pkg* "$(MIRROR_DIR)/pool/packages/" ; \
	fi


	#link package to the correct repos symlink folder
	#and repo-add the new package
	cd $(MIRROR_DIR)/$(@D)/*/*/ ;            \
	rm "$(@F)-"* || true &&                    \
	ln -s "../../../pool/packages/$(@F)"-*xz &&    \
	ln -s "../../../pool/packages/$(@F)"-*xz.sig &&   \
	repo-remove ./$(@D).db.*gz "$(@F)" || true   &&        \
	repo-add ./$(@D).db.*gz "$(@F)-"*xz

.PHONY: all fetch_rule $(PKGS) %.db
