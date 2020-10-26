rsync rsync://mirror.umd.edu/archlinux ./archlinux/  -rtlvH --delete-after --delay-updates --safe-links -P 

echo "Patching filesystem and adding to core"
#filesystem
cd ./packages 
rm -rf ./filesystem
svn update filesystem
cd ./filesystem/trunk 
svn patch ../../../patches/filesystem.patch
makepkg --sign --skipchecksums -f 
mv -f filesystem* ../../../archlinux/pool/packages/
cd ../../../archlinux/core/os/x86_64/
rm filesystem-*
ln -s ../../../pool/packages/filesystem*.tar.xz
ln -s ../../../pool/packages/filesystem*.tar.xz.sig
repo-remove ./core.db.tar.gz filesystem
repo-add ./core.db.tar.gz filesystem-*.tar.xz


cd ../../../..

echo "Patching neofetch and adding to community"

#neofetch
cd ./community 
rm -rf ./neofetch
svn update neofetch
cd .. 
cp ./patches/neofetch/neofetch_src.patch ./community/neofetch/trunk
cd ./community/neofetch/trunk 
svn patch ../../../patches/neofetch/neofetch.patch
makepkg --sign --skipchecksums -f 
rm ../../../archlinux/pool/community/neofetch*
cp -f neofetch*.xz* ../../../archlinux/pool/community/
cd ../../../archlinux/community/os/x86_64/
rm neofetch*
ln -s ../../../pool/community/neofetch*.tar.xz
ln -s ../../../pool/community/neofetch*.tar.xz.sig
repo-remove ./community.db.tar.gz neofetch
repo-add ./community.db.tar.gz neofetch*.xz

#yay 

cd ../../../..


echo "Adding Yay to community"
cd ./AUR/yay/
git reset --hard HEAD
git clean -df
#not patching, skipping that step
makepkg --sign -f 
rm ../../archlinux/pool/community/yay*
cp yay-*.tar.xz ../../archlinux/pool/community/
cd ../../archlinux/community/os/x86_64/
rm yay* 
ln -s ../../../pool/community/yay*.tar.xz
ln -s ../../../pool/community/yay*.tar.xz.sig
repo-remove ./community.db.tar.gz yay
repo-add ./community.db.tar.gz yay*.xz

