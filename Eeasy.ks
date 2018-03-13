install
cdrom
lang en_US.UTF-8
keyboard us
firewall --disabled
selinux --disable
timezone --utc Asia/Taipei


#default root's password
#  grub-crypt --sha-512
#example: blahblahblah

rootpw --iscrypted $6$633bgr056OgHj1k1$7fOUQaon95JA7t9Od8aoh7FAABS5uhhNtv8s/Q63HrjFOmoKIXcg2zUpR0P.8062HQihOuO1QZCejb1arg.g3/
authconfig --enableshadow --passalgo=sha512

user --name=maxi --iscrypted --password=$6$Gg3h0l3bhYHhbkWf$uDtekP3Pz2ymHYuJlHtVNrSZ5FmT/xWuSX05uAtjFOiHyqMlsMAywvbxNdrGMQbax3TrJcwBOk7IkL6sx.0C9/

sshpw --username=skywalker joechi1234 --plaintext

url --url http://ftp.stu.edu.tw/Linux/CentOS/6/os/x86_64/
repo --name=updates --baseurl=http://ftp.stu.edu.tw/Linux/CentOS/6/updates/x86_64/

%include /tmp/userpasswd.ks
%include /tmp/part_disk.ks

%packages --nobase
#%packages
curl
ntpdate
openssh-clients
%end




%pre --log /tmp/pre-install.log
#!/bin/sh
exec < /dev/tty3 > /dev/tty3 2>&1
chvt 3
#exec < /dev/tty3 > /dev/tty3 2>&1
clear

echo "" > /tmp/userpasswd.ks
echo "" > /tmp/hostname.txt

#get setting from cmdline
for x in `cat /proc/cmdline`; do
	case $x in 
	SERVERNAME*)
		eval $x
		echo ${SERVERNAME} > /tmp/hostname.txt
		;;
	PASSWORD*)
		eval $x
		echo "user --name=opuser --password=${PASSWORD}" > /tmp/userpasswd.ks
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
#chroot /mnt/sysimage /bin/bash -c "test -d /var/lib/pgsql && mv /var/lib/pgsql /home/ && ln -s /home/pgsql /var/lib/pgsql"
#chroot /mnt/sysimage /bin/bash -c "test -d /var/lib/mysql && mv /var/lib/mysql /home/ && ln -s /home/mysql /var/lib/mysql"

#test -f /mnt/sysimage/usr/pgsql-9.4/share/postgresql.conf.sample && \
#sed -i \
#-e 's/^\(#\)\{0,3\}listen_addresses\s\+=\s\+\x27.*\x27/listen_addresses = \x27\*\x27/g' \
#/mnt/sysimage/usr/pgsql-9.4/share/postgresql.conf.sample


#mkdir /mnt/sysimage/home/maxi/.ssh
#chmod 700 /mnt/sysimage/home/maxi/.ssh
#cat  << EOD >> /mnt/sysimage/home/maxi/.ssh/authorized_keys
#ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAt5tN2Mb5nAPUohHRQb2a5ZFaQm30zZfKA0s6pQxDm4Gc3gjz5Xgnv+S/kAp00teR3bvnys842T7Sx6Q6EFLmC5RvB0MO8/CSco8QgGUMqpXluqgKa8p+7KBwXNSvtPUowmK93jjKWsg5fKGoRlehcKgfrqFn0ya7wh0Ycr7z2Bi8EAar6Mc5tMKnYqJVXNOoosgZ+n9UzQ26wkUZXhvW2snO+ZPaSTIX8pA/q7XVWX3rW7khZ/hG6GMUsBZcWg6wSLh5I1cUng9iBbjiIbD2tuNnlppGEQkWsx5ayvgFgFE1f++VomzUQ0dWNNdhppCvDCaB/IEKorHaIsFwB59VYw== geoyue@joechi.no-ip.com
#EOD
#chroot /mnt/sysimage /bin/bash -c "chown -R maxi:maxi /home/maxi/.ssh"

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
