install
#cdrom
lang en_US.UTF-8
keyboard us
firewall --disabled
selinux --disable
timezone --utc Asia/Taipei
text

%include /tmp/rootpasswd.ks
#default root's password
#  grub-crypt --sha-512
#example: 
#rootpw --iscrypted $6$633bgr056OgHj1k1$7fOUQasfsdfdsfdsffaoh7FAABS5uhhNtv8s/Q63HrjFOmoKIXcg2zUpR0P.8062HQihOuO1QZCejb1arg.g3/
authconfig --enableshadow --passalgo=sha512

#add a default user
#user --name=maxi --iscrypted --password=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

#During installation, you can interact with anaconda and monitor its progress over an SSH connection
sshpw --username=skywalker joechi1234 --plaintext

%include /tmp/use_url.ks

url --url http://linux.cs.nctu.edu.tw/CentOS/6.9/os/x86_64/
#repo --name=base --baseurl=http://linux.cs.nctu.edu.tw/CentOS/6.9/updates/x86_64/
#repo --name=updates --baseurl=http://linux.cs.nctu.edu.tw/CentOS/6.9/updates/x86_64/
repo --name=epel --baseurl=http://dl.fedoraproject.org/pub/epel/6/x86_64/

%include /tmp/userpasswd.ks
%include /tmp/part_disk.ks


%packages --nobase
#%packages
epel-release
at
curl
ntpdate
openssh-clients
vim-filesystem
vim-common
vim-enhanced
nc
wget
unzip
zip
bc
mutt
net-snmp
net-snmp-utils
lynx
geoipupdate
geoipupdate-cron
GeoIP
man
%end




%pre --log /tmp/pre-install.log
#!/bin/sh
exec < /dev/tty3 > /dev/tty3 2>&1
chvt 3
#exec < /dev/tty3 > /dev/tty3 2>&1
clear

echo "" > /tmp/userpasswd.ks
echo "" > /tmp/rootpasswd.ks
echo "" > /tmp/hostname.txt
echo "" > /tmp/use_url.ks

for i in http://linux.cs.nctu.edu.tw/CentOS/6.9/ http://ftp.stu.edu.tw/Linux/CentOS/6.9/ http://ftp.twaren.net/Linux/CentOS/6.9/ http://ftp.yzu.edu.tw/Linux/CentOS/6.9/ http://mirror.centos.org/centos/6.9/ ; do
	curl -sSLf -D - "${i}os/x86_64/" -o /dev/null && {
		cat << EOD > /tmp/use_url.ks
#url --url ${i}os/x86_64/
repo --name=updates --baseurl=${i}updates/x86_64/
repo --name=base --baseurl=${i}updates/x86_64/
EOD
	echo "Use URL SOURCE: ${i}"
	break;
}
done

#get setting from cmdline
for x in `cat /proc/cmdline`; do
	case $x in 
	SERVERNAME=*)
		eval $x
		echo ${SERVERNAME} > /tmp/hostname.txt
		;;
	MAXIPASSWORD=*)
		eval $x
		echo "user --name=maxi --password=${MAXIPASSWORD}" > /tmp/userpasswd.ks
		;;
	ROOTPASSWORD=*)
		eval $x
		echo "rootpw ${ROOTPASSWORD}" > /tmp/rootpasswd.ks
		;;
	DISKMANUAL*)
		#manual disk partition setting
		echo "" > /tmp/part_disk.ks
		;;
	esac;
done

while [ "X"${SERVERNAME} == "X" ]; do
	## Query for hostname, then write it to 'network' file
	#read -p "What is my hostname (FQDN)? (This will be set on eth0)" SERVERNAME /dev/tty3 2>&1
	read -p "What is my hostname (FQDN)? (This will be set on eth0): " SERVERNAME

	echo "${SERVERNAME}" > /tmp/hostname.txt
done


# pick the first drive that is not removable and is over MINSIZE
DIR="/sys/block"

# minimum size of hard drive needed specified in GIGABYTES
MINSIZE=60
ROOTDRIVE=""

# /sys/block/*/size is in 512 byte chunks
for DEV in sda sdb sdc sdd hda hdb; do
	if [ -d $DIR/$DEV ]; then
		REMOVABLE=`cat $DIR/$DEV/removable`
		if (( $REMOVABLE == 0 )); then
			SIZE=`cat $DIR/$DEV/size`
			GB=$(($SIZE/2**21))
			if [ $GB -gt $MINSIZE ]; then
				if [ -z $ROOTDRIVE ]; then
					ROOTDRIVE=$DEV
				fi
			fi
		fi
	fi
done
echo "ROOTDRIVE=$ROOTDRIVE"
ifconfig
read -n 10 -s -r -p "Press any key to continue" /dev/tty3 2>&1

cat << EOD > /tmp/part_disk.ks
zerombr
clearpart --all --drives=$ROOTDRIVE --initlabel
bootloader --location=mbr --driveorder=$ROOTDRIVE --append="crashkernel=auto rhgb quiet"
part /boot --fstype ext3 --size=500 --ondisk=$ROOTDRIVE
part pv.01 --size=100 --grow --ondisk=$ROOTDRIVE
volgroup vg00 pv.01
logvol swap --fstype swap --name=swap --vgname=vg00 --recommended
logvol /home --fstype ext4 --name=home --vgname=vg00 --size=50000
logvol / --fstype ext4 --name=root --vgname=vg00 --size=1 --grow
EOD


chvt 1
exec < /dev/tty1 > /dev/tty1
%end




%post --nochroot --interpreter /bin/bash --log=/mnt/sysimage/root/ks-post.log

cp /tmp/pre-install.log /mnt/sysimage/root/
cp /tmp/hostname.txt /mnt/sysimage/root/


sed -i -e 's/^\(HOSTNAME=\).*/\1'`cat /tmp/hostname.txt`'/g' /mnt/sysimage/etc/sysconfig/network


mkdir -p /mnt/sysimage/root/EXTRAS
cp -arv /mnt/source/extract/* /mnt/sysimage/root/EXTRAS
mkdir -p /mnt/sysimage/root/rpm-gpg
cp -arv /mnt/source/rpm-gpg/* /mnt/sysimage/root/rpm-gpg
chroot /mnt/sysimage /bin/bash -c "rpm --import /root/rpm-gpg/RPM*"
chroot /mnt/sysimage /bin/bash -c "rpm -Uvh /root/EXTRAS/*.rpm"

cp /mnt/sysimage/usr/share/vim/vim72/vimrc_example.vim /mnt/sysimage/etc/vimrc
grep -q 'alias vim' /mnt/sysimage/etc/bashrc || echo "alias vim='vi'" >> /mnt/sysimage/etc/bashrc

test -f /mnt/sysimage/etc/ssh/sshd_config && \
sed -i \
-e 's/^\(#\)\{0,3\}Port.*$/Port 27777/g' \
-e 's/^\(#\)\{0,3\}PermitRootLogin.*$/PermitRootLogin yes/g' \
-e 's/^\(#\)\{0,3\}UseDNS.*$/UseDNS no/g' \
/mnt/sysimage/etc/ssh/sshd_config


cat << EOD > /mnt/sysimage/root/cronjob.txt
0 */4 * * * /usr/sbin/ntpdate pool.ntp.org 1> /dev/null && /sbin/clock -w 1> /dev/null
EOD

chroot /mnt/sysimage crontab /root/cronjob.txt

cat << EOD > /mnt/sysimage/etc/sudoers.d/sudomaxi
User_Alias	MAXI = maxi, opuser

Cmnd_Alias	PS = /bin/netstat, /bin/ps
Cmnd_Alias	SU = /bin/su
Cmnd_Alias	CRON = /usr/bin/crontab
Cmnd_Alias	EDIT = /usr/bin/vim, /usr/bin/less, /bin/cat

MAXI	ALL=(root) NOPASSWD: PS, SU, CRON, EDIT
EOD

echo "Done!"
%end
