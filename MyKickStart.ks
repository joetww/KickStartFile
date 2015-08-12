install
cdrom
lang en_US.UTF-8
keyboard us

rootpw  --iscrypted blahblahblah
firewall --disabled
authconfig --enableshadow --passalgo=sha512
selinux --disable
timezone --utc Asia/Taipei
bootloader --location=mbr --append="crashkernel=auto rhgb quiet"
user --name=maxi --iscrypted --password=blahblahblah

sshpw --username=skywalker joechi1234 --plaintext


%include /tmp/userpasswd.ks

%include /tmp/part_disk.ks

#clearpart --all
#part / --fstype=ext4 --size=12288 --asprimary
#part swap --size=2046
#part /home --fstype=ext4 --grow --size=1

%packages --nobase
%end

%pre --log /tmp/pre-install.log
#!/bin/sh
echo "playme.gamemag.com.tw" > /tmp/hostname.txt
echo "user --name=opuser" > /tmp/userpasswd.ks
cat << EOD > /tmp/part_disk.ks
#預設自動切割硬碟
clearpart --all
part / --fstype=ext4 --size=12288 --asprimary
part swap --size=2046
part /home --fstype=ext4 --grow --size=1
EOD
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
		#把自動切割硬碟的設定清空，進入手動切割
		echo "" > /tmp/part_disk.ks
		;;
	esac;
done
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
-e 's/^\(#\)\{0,3\}PermitRootLogin.*$/PermitRootLogin no/g' \
-e 's/^\(#\)\{0,3\}UseDNS.*$/UseDNS no/g' \
/mnt/sysimage/etc/ssh/sshd_config


cat << EOD > /mnt/sysimage/root/cronjob.txt
0 */4 * * * /usr/sbin/ntpdate pool.ntp.org 1> /dev/null && /sbin/clock -w 1> /dev/null
EOD

chroot /mnt/sysimage crontab /root/cronjob.txt
chroot /mnt/sysimage /bin/bash -c "test -d /var/lib/pgsql && mv /var/lib/pgsql /home/ && ln -s /home/pgsql /var/lib/pgsql"
chroot /mnt/sysimage /bin/bash -c "test -d /var/lib/mysql && mv /var/lib/mysql /home/ && ln -s /home/mysql /var/lib/mysql"

test -f /mnt/sysimage/usr/pgsql-9.4/share/postgresql.conf.sample && \
sed -i \
-e 's/^\(#\)\{0,3\}listen_addresses\s\+=\s\+\x27.*\x27/listen_addresses = \x27\*\x27/g' \
/mnt/sysimage/usr/pgsql-9.4/share/postgresql.conf.sample


mkdir /mnt/sysimage/home/maxi/.ssh
chmod 700 /mnt/sysimage/home/maxi/.ssh
cat  << EOD >> /mnt/sysimage/home/maxi/.ssh/authorized_keys
ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAt5tN2Mb5nAPUohHRQb2a5ZFaQm30zZfKA0s6pQxDm4Gc3gjz5Xgnv+S/kAp00teR3bvnys842T7Sx6Q6EFLmC5RvB0MO8/CSco8QgGUMqpXluqgKa8p+7KBwXNSvtPUowmK93jjKWsg5fKGoRlehcKgfrqFn0ya7wh0Ycr7z2Bi8EAar6Mc5tMKnYqJVXNOoosgZ+n9UzQ26wkUZXhvW2snO+ZPaSTIX8pA/q7XVWX3rW7khZ/hG6GMUsBZcWg6wSLh5I1cUng9iBbjiIbD2tuNnlppGEQkWsx5ayvgFgFE1f++VomzUQ0dWNNdhppCvDCaB/IEKorHaIsFwB59VYw== geoyue@joechi.no-ip.com
EOD
chroot /mnt/sysimage /bin/bash -c "chown -R maxi:maxi /home/maxi/.ssh"

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
