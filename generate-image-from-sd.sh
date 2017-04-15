#!/bin/bash

# This script currently does not have error checking in it and has not been heavily tested.
#   use this script at your own risk.
#
#   If you are debugging or just concerned uncomment the "set -e" line below to force the script to
#   terminate on any error. This includes erroring on already existing directories and similar minor issues.

#set -e

echo
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo "! This script currently does not have error checking in it and has not been heavily tested. !"
echo "!         As such use this script at your own risk till it can be refined further.          !"
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo
echo "This script will resize the file system and partition on the SD card to as small as possible."
echo "After this it will clone the results to an image file on USB drive"
echo
echo "Please make sure the SD card and FAT formatted USB drive are inserted."
read -rsp $'Press any key to continue...\n' -n1 key

# This is commended out because it currently cannot work, the script shuts the BB down after running
#echo "Running script to clone eMMC to SD"
#echo "/opt/scripts/tools/eMMC/beaglebone-black-make-microSD-flasher-from-eMMC.sh"
echo

# This makes it so the image will boot on other BB not just the one it was built on
echo "Removing UUID references and uncommenting flahser option from /boot/uEnv.txt"
mkdir /mnt/zero
mount /dev/mmcblk1p1 /mnt/zero
sed -ie '/^uuid=/d' /mnt/zero/boot/uEnv.txt
sed -ie 's/#cmdline=init=\/opt\/scripts\/tools\/eMMC\/init-eMMC-flasher-v3.sh$/cmdline=init=\/opt\/scripts\/tools\/eMMC\/init-eMMC-flasher-v3.sh/' /mnt/zero/boot/uEnv.txt
echo "Removing WPA wifi access file just in case"
rm -rf /mnt/zero/root/wpa.conf
echo "Clearing bash history"
rm -rf /mnt/zero/root/.bash_history
rm -rf /mnt/zero/home/ubuntu/.bash_history
echo

# Likely not needed but for the sake of making the image smaller we defrag first
echo "Defragmenting partition."
e4defrag /mnt/zero > /dev/null
umount /mnt/zero
echo

# Run file system checks and then shrink the file system as much as possible
echo "Resizing filesystem."
e2fsck -f /dev/mmcblk1p1
resize2fs -pM /dev/mmcblk1p1
resize2fs -pM /dev/mmcblk1p1
e2fsck -f /dev/mmcblk1p1
echo

# Zero out the free space remaining on the file system
echo "Defrag and zero partition free space."
mount /dev/mmcblk1p1 /mnt/zero
e4defrag /mnt/zero > /dev/null
dd if=/dev/zero of=/mnt/zero/zeros
rm -rf /mnt/zero/zeros
umount /mnt/zero
echo

# Run the file system checks and another series of file system shrinks just in case
#   we can shrink the file system any further after zeroing the free space.
echo "Resizing filesystem again."
e2fsck -f /dev/mmcblk1p1
resize2fs -pM /dev/mmcblk1p1
resize2fs -pM /dev/mmcblk1p1
e2fsck -f /dev/mmcblk1p1
echo

# This is where the real danger starts with modifying the partitions
echo "Shrinking partition now."
# Gather useful partition data
fsblockcount=$(tune2fs -l /dev/mmcblk1p1 | grep "Block count:" | awk '{printf $3}')
fsblocksize=$(tune2fs -l /dev/mmcblk1p1 | grep "Block size:" | awk '{printf $3}')
partblocksize=$(fdisk -l /dev/mmcblk1p1 | grep Units: | awk '{printf $8}')
partblockstart=$(fdisk -l /dev/mmcblk1 | grep /dev/mmcblk1p1 | awk '{printf $3}')
partsize=$((fsblockcount*fsblocksize/partblocksize))

# Write out the partition layout that will replace the currently existing one.
cat <<EOF > /shrink.layout
# partition table of /dev/mmcblk1
unit: sectors

/dev/mmcblk1p1 : start=${partblockstart}, size=${partsize}, Id=83, bootable
EOF

# Perform actual modificaitons to the partition layout
sfdisk /dev/mmcblk1 < /shrink.layout
rm -rf /shrink.layout

# Make sure the system sees the new partition layout, check the file system for issues
#   and then resize the file system to the full size of the new partition if it is needed
echo "Re-read partition table"
hdparm -z /dev/mmcblk1
e2fsck -f /dev/mmcblk1p1
resize2fs /dev/mmcblk1p1
e2fsck -f /dev/mmcblk1p1
echo

# Run one last defrag and zero of the free space before backing it up
echo "Final defrag and zeroing partition free space."
mount /dev/mmcblk1p1 /mnt/zero
kamiversion=$(cat /mnt/zero/etc/dogtag | awk '{printf $2}')
e4defrag /mnt/zero > /dev/null
dd if=/dev/zero of=/mnt/zero/zeros
rm -rf /mnt/zero/zeros
umount /mnt/zero
rm -rf /mnt/zero
echo

# Final file system check
echo "File system and partition shrink are complete, running last file system check."
e2fsck -f /dev/mmcblk1p1
echo

# Mounting the USB thumb drive and generating the compressed image file on it from the sd card
echo "Generating image file now."
blocksize=$(fdisk -l /dev/mmcblk1 | grep Units: | awk '{printf $8}')
count=$(fdisk -l /dev/mmcblk1 | grep /dev/mmcblk1p1 | awk '{printf $4}')
ddcount=$((count*blocksize/1000000+1))
mkdir /mnt/USB
mount /dev/sda1 /mnt/USB
dd if=/dev/mmcblk1 bs=1MB count=${ddcount} | xz > /mnt/USB/Kamikaze-${kamiversion}.img.xz
umount /mnt/USB
rm -rf /mnt/USB
echo

# Talkie talkie
echo "Image file generated on USB drive as Kamikaze-${kamiversion}.img.xz"
echo "USB drive and MicroSD card can be removed safely now."
