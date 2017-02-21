##install archlinux with lvm


# functions
mkpartitions()
{
    # $1 is boot part, $2 is swap part and the rest is lvm. all
    # partions are primary.
    # $1 and $2 are 512M when install archlinux by default.
    if [[ $1 == "" ]]; then
        pa="512M"
    else
        pa=$1
    fi
    if [[ $2 == "" ]]; then
        pb="512M"
    else
        pb=$2
    fi

    fdisk /dev/sda << EOF
n
p


+$pa
n
p


+$pb
n
p



t

8e
w
EOF
}


mkfilesys()
{
    echo "when finished, input q or Q to exit."
    echo ""
    while read -p "which file system(common usr, var, opt): " fls;
    do
        case $fls in
        q|Q)
            break
            ;;
        *)
            read -p "size of it, size{M,G}: " sz
            lvcreate -L $sz -n lv_$fls arch_vg00
            mkfs.ext4 /dev/arch_vg00/lv_$fls
            ;;
        esac
    done
}


# change mirror list, installation stage
mv /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak
echo "Server = http://mirrors.zju.edu.cn/archlinux/\$repo/os/\$arch" > /etc/pacman.d/mirrorlist


# Start to install!
echo "start to install archlinux"
# wait 2 seconds
sleep 2
read -p "input hostname: " hnm

read -p "input size of boot, size{M,G}：" sz_boot
read -p "input size of swap, size{M,G}：" sz_swap
mkpartitions $sz_boot $sz_swap
partprobe

mkfs.ext4 /dev/sda1
mkswap /dev/sda2
swapon /dev/sda2

# for lvm
pvcreate /dev/sda3
vgcreate arch_vg00 /dev/sda3

read -p "how many you separate for root? size{M,G}: " root
lvcreate -L $root -n lv_root arch_vg00
mkfs.ext4 /dev/arch_vg00/lv_root

read -p "do you create other file systems except home? [Yy|Nn]: " yesno
case $yesno in
Y|y)
    mkfilesys
    ;;
n|N)
    echo ""
    echo "didn't create other file systems"
    ;;
esac

echo ""

read -p "the rest of arch_vg00 are created for lv_home? [Yy|Nn]: " ans
case $ans in
Y|y)
    lvcreate -l 100%FREE -n lv_home arch_vg00
    mkfs.ext4 /dev/arch_vg00/lv_home
    ;;
n|N)
    echo ""
    echo "didn't create /home"
    ;;
esac

modprobe dm-mod
vgscan
vgchange -ay

mount /dev/arch_vg00/lv_root /mnt
mkdir /mnt/boot
mount /dev/sda1 /mnt/boot

SMTFS=`ls /dev/arch_vg00/lv_* | sed "s/\/dev\/arch_vg00\///"`
for mfs in $SMTFS
do
    if [[ $mfs != "lv_root" ]]; then
        fs=`echo $mfs | sed "s/lv_//"`
        mkdir /mnt/$fs
        mount /dev/arch_vg00/$mfs /mnt/$fs
    fi
done

pacstrap /mnt base

genfstab -p /mnt >> /mnt/etc/fstab


cp /run/archiso/bootmnt/archlinux_ins2.sh /mnt
cp /run/archiso/bootmnt/archlinux_ins3.sh /mnt
cp -r /run/archiso/bootmnt/configs /mnt/home

# Run the second step
arch-chroot /mnt /bin/bash archlinux_ins2.sh $hnm


# get log
mv /root/install_archlinux.log /mnt/root


# exit from archlinux_ins2.sh, reboot to new system
umount -lR /mnt
reboot