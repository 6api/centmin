#!/bin/sh
SCRIPT_VERSION='1.2.3'
SCRIPT_DATE='04/10/2011'
SCRIPT_AUTHOR='BTCentral (btcentral.org.uk)'
SCRIPT_MODIFICATION_AUTHOR='eva2000 (vbtechsupport.com)'
COPYRIGHT="Copyright 2011 BTCentral"
DISCLAIMER='This software is provided "as is" in the hope that it will be useful, but WITHOUT ANY WARRANTY, to the extent permitted by law; without even the implied warranty of MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.'
#
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation, either version 3 of the License, or (at your option)
# any later version. See the included license.txt for futher details.
#
# PLEASE MODIFY VALUES BELOW THIS LINE ++++++++++++++++++++++++++++++++++++++
# Note: Please enter y for yes or n for no.

# General Configuration
ZONEINFO=Europe/London       # Set Timezone
NSD_INSTALL=y                # Install NSD (DNS Server)
NSD_VERSION='3.2.8'          # NSD Version
NTP_INSTALL=y                # Install Network time protocol daemon
NGINX_INSTALL=y              # Install Nginx (Webserver)
PHP_INSTALL=y                # Install PHP /w Fast Process Manager
MDB_INSTALL=n                # Install MariaDB MySQL Server replacement (Not recommended for VPS with less than 512MB RAM!)
MDB_VERONLY='5.2.9'
MDB_BUILD='102'
MDB_VERSION="${MDB_VERONLY}-${MDB_BUILD}"     # Use this version of MariaDB ${MDB_VERONLY}

# Optionally, if you want to install MariaDB instead of standard MySQL you can do. Set MDB_INSTALL=y and MYSQL_INSTALL=n
MYSQL_INSTALL=y              # Install MySQL Server (MariaDB recommended if you have a VPS with over 512MB RAM)
SENDMAIL_INSTALL=y           # Install Sendmail (and mailx)
# Nginx
NGINX_VERSION='1.0.8'        # Use this version of Nginx
LIBUNWIND_VERSION='1.0.1'     # Use this version of libunwind
GPERFTOOLS_VERSION='1.8.3'     # Use this version of google-perftools
OPENSSL_VERSION='1.0.0e'     # Use this version of OpenSSL
PCRE_VERSION='8.13'          # Use this version of PCRE library
# PHP and Cache/Acceleration
MEMCACHED_INSTALL=y          # Install Memcached
LIBEVENT_VERSION='2.0.14'    # Use this version of Libevent
MEMCACHED_VERSION='1.4.7'    # Use this version of Memcached
MEMCACHE_VERSION='3.0.5'     # Use this version of Memcache - note issues with 3.0.6
PHP_VERSION='5.3.8'          # Use this version of PHP
XCACHE_VERSION='1.3.2'       # Use this version of Xcache
APCCACHE_VERSION='3.1.9'     # Use this version of APC Cache
# Python
PYTHON_VERSION='2.7.2'       # Use this version of Python

# The default is stable, you can change this to development if you wish
#ARCH_OVERRIDE='i386'
# Uncomment the above line if you are running a 32bit Paravirtulized Xen VPS
# on a 64bit host node.

# YOU SHOULD NOT NEED TO MODIFY ANYTHING BELOW THIS LINE  +++++++++++++++++++
# JUST RUN chmod +x ./centmin.sh && ./centmin.sh
#
###############################################################
KEYPRESS_PARAM='-s -n1 -p'   # Read a keypress without hitting ENTER.
		# -s means do not echo input.
		# -n means accept only N characters of input.
		# -p means echo the following prompt before reading input
ASKCMD="read $KEYPRESS_PARAM "
MACHINE_TYPE=`uname -m` # Used to detect if OS is 64bit or not.
CENTOSVER=`cat /etc/redhat-release | awk '{ print $3 }'`

if [ "$CENTOSVER" == 'release' ]; then
CENTOSVER=`cat /etc/redhat-release | awk '{ print $4 }'`
fi

if [ -f /proc/user_beancounters ];
then
    # Get OpenVZ Memory allocation guarantee
    OVZ_GARPAGES=`cat /proc/user_beancounters | grep " vmguarpages " | awk '{ print $4 }'`
    # Calculate equivalent amount of RAM (in MB)
    OVZ_GAR_MEM=`expr $OVZ_GARPAGES \\* 4 / 1024`
    TOTAL_MEM=`free -m -t | grep "Mem" | awk '{ print $2 }';`
else 
    TOTAL_MEM=`free -m -t | grep "Mem" | awk '{ print $2 }';`
fi

if [ -f /proc/user_beancounters ];
then
    CPUS='1'
    MAKETHREADS=" -j$CPUS"
else
    # speed up make
    CPUS=`cat "/proc/cpuinfo" | grep "processor"|wc -l`
    MAKETHREADS=" -j$CPUS"
fi

CUR_DIR=`pwd` # Get current directory.
###############################################################
# FUNCTIONS

if [ "${ARCH_OVERRIDE}" != '' ]
then
    ARCH=${ARCH_OVERRIDE}
else
    if [ ${MACHINE_TYPE} == 'x86_64' ];
    then
        ARCH='x86_64'
    else
        ARCH='i386'
    fi
fi

ASK () {
keystroke=''
while [[ "$keystroke" != [yYnN] ]]
do
    $ASKCMD "$1" keystroke
    echo "$keystroke";
done

key=$(echo $keystroke)
}

# Setup Colours
black='\E[30;40m'
red='\E[31;40m'
green='\E[32;40m'
yellow='\E[33;40m'
blue='\E[34;40m'
magenta='\E[35;40m'
cyan='\E[36;40m'
white='\E[37;40m'

boldblack='\E[1;30;40m'
boldred='\E[1;31;40m'
boldgreen='\E[1;32;40m'
boldyellow='\E[1;33;40m'
boldblue='\E[1;34;40m'
boldmagenta='\E[1;35;40m'
boldcyan='\E[1;36;40m'
boldwhite='\E[1;37;40m'

Reset="tput sgr0"      #  Reset text attributes to normal
                       #+ without clearing screen.

cecho ()                     # Coloured-echo.
                             # Argument $1 = message
                             # Argument $2 = color
{
message=$1
color=$2
echo -e "$color$message" ; $Reset
return
}

run_once ()
{
# If OpenVZ user add user/group 500 - else various folders and devices will end up with an odd user/group name for some reason
if [ -f /proc/user_beancounters ];
then
    groupadd 500
    useradd -g 500 -s /sbin/nologin -M 500
fi

ASK "Would you like to update any pre-installed software? (Recommended) [y/n] "
if [[ "$key" = [yY] ]];
then
    echo "Let's do that then..."
    yum clean all
    yum -y update glibc\*
    yum -y update yum\* rpm\* python\*
    yum clean all
    yum -y update
fi

if [ ${ARCH} == 'x86_64' ];
then
    ASK "Would you like to exclude installation of 32bit Yum packages? (Recommended for 64bit CentOS) [y/n] "
    if [[ "$key" = [yY] ]];
    then
        mv /etc/yum.conf /etc/yum.bak
        mv $CUR_DIR/config/yum/yum.conf /etc/yum.conf
        echo "Your origional yum configuration has been backed up to /etc/yum.bak"
    else
        rm -rf $CUR_DIR/config/yum
    fi
fi

ASK "Would you like to secure /tmp and /var/tmp? (Highly recommended) [y/n] "   
if [[ "$key" = [yY] ]]; 
then
	echo "*************************************************"
	cecho "* Secured /tmp and /var/tmp" $boldgreen
	echo "*************************************************"

	rm -rf /tmp
	mkdir /tmp
	mount -t tmpfs -o rw,noexec,nosuid tmpfs /tmp
	chmod 1777 /tmp
	echo "tmpfs   /tmp    tmpfs   rw,noexec,nosuid        0       0" >> /etc/fstab
	rm -rf /var/tmp
	ln -s /tmp /var/tmp
fi

if [ "$CENTOSVER" == '6.0' ];
then
    echo "*************************************************"
    cecho "* CentOS 6 detected installing RPMForge Repo" $boldgreen
    echo "*************************************************"

    if [ ${MACHINE_TYPE} == 'x86_64' ];
    then
        ARCH2='x86_64'
    else
        ARCH2='i686'
    fi

    cd /usr/local/src

    if [ -s rpmforge-release-0.5.2-2.el6.rf.${ARCH2}.rpm ]; then
        cecho "rpmforge-release-0.5.2-2.el6.rf.${ARCH2}.rpm found, skipping download..." $boldgreen
    else
        wget -c http://pkgs.repoforge.org/rpmforge-release/rpmforge-release-0.5.2-2.el6.rf.${ARCH2}.rpm --tries=3
    fi

    rpm --import http://apt.sw.be/RPM-GPG-KEY.dag.txt
    rpm -i rpmforge-release-0.5.2-2.el6.rf.${ARCH2}.rpm
fi

echo "*************************************************"
cecho "* Installing Development Tools" $boldgreen
echo "*************************************************"
    yum -y install gcc gcc-c++ automake autoconf autoconf213 libtool make libXext-devel unzip distcache slocate patch sysstat gcc44 gcc44-c++ zlib zlib-devel openssh* openssl* gd gd-devel pcre pcre-devel pcre.${ARCH} pcre-devel.${ARCH} flex bison file libgcj gettext gettext-devel e2fsprogs-devel libtool-libs libtool-ltdl-devel kernel-devel libidn libidn-devel krb5-devel libjpeg libjpeg-devel libpng libpng-devel freetype freetype-devel libxml2 libxml2-devel libXpm-devel libmcrypt libmcrypt-devel glib2 glib2-devel bzip2 bzip2-devel vim-minimal nano sendmail ncurses ncurses-devel curl curl-devel e2fsprogs gmp-devel pspell-devel aspell-devel numactl lsof pkgconfig gdbm-devel tk-devel bluez-libs-devel iptables* rrdtool diffutils libc-client libc-client-devel

if [ "$CENTOSVER" == '6.0' ];
then
    # CentOS 6 repo mirrors aren't fully updated so need to specify actual kernel-headers version
    yum -y install mlocate kernel-headers-`uname -r` kernel-devel-`uname -r`
fi

ASK "Would you like to set the server localtime? [y/n] "   
if [[ "$key" = [yY] ]];
then
    echo "*************************************************"
    cecho "* Setting preferred localtime for VPS" $boldgreen
    echo "*************************************************"
    rm -f /etc/localtime
    ln -s /usr/share/zoneinfo/$ZONEINFO /etc/localtime
    echo "Current date & time for the zone you selected is:"
    date
fi
}

# END FUNCTIONS
################################################################
# SCRIPT START
#
clear
cecho "**********************************************************************" $boldyellow
cecho "* Centmin, an nginx, MariaDB/MySQL, PHP & DNS Install script for CentOS" $boldgreen
cecho "* Version: $SCRIPT_VERSION - Date: $SCRIPT_DATE - $COPYRIGHT" $boldgreen
cecho "* Contributions by: $SCRIPT_MODIFICATION_AUTHOR" $boldgreen
cecho "**********************************************************************" $boldyellow
echo " "
cecho "This software comes with no warranty of any kind. You are free to use" $boldyellow
cecho "it for both personal and commercial use as licensed under the GPL." $boldyellow
echo " "
cecho "Please read the included readme.txt before using this script." $boldmagenta
echo " "
ASK "Would you like to continue? [y/n] "   
if [[ "$key" = [nN] ]];
then
    exit 0
fi

# Set LIBDIR
if [ ${ARCH} == 'x86_64' ];
then
    LIBDIR='lib64'
else
    LIBDIR='lib'
fi

DIR_TMP="/svr-setup"
if [ -a "$DIR_TMP" ];
then
	ASK "It seems that you have run this script before, would you like to start from after setting the timezone? [y/n] "
	if [[ "$key" = [nN] ]];
	then
		run_once
	fi
else
	mkdir /svr-setup
	run_once
fi

if [ -f /proc/user_beancounters ];
then
    cecho "We have detected that your system has $OVZ_GAR_MEM MB Guaranteed and $TOTAL_MEM MB Burst RAM" $boldyellow

    if [ $OVZ_GAR_MEM -ge 256 ];
    then
    	ASK "Due to this we recommend using the higher resource usage configuration files. Would you like to? [y/n] "
    	if [[ "$key" = [yY] ]];
    	then
    		MIN_CFG='n'
    	else
    	    MIN_CFG='y'
    	fi
    else
    	ASK "Due to this we highly recommend using the low resource usage configuration files. Would you like to? [y/n] "
    	if [[ "$key" = [yY] ]];
    	then
    		MIN_CFG='y'
    	else
    	    MIN_CFG='n'
    	fi
    fi
else
    cecho "We have detected that your system has $TOTAL_MEM MB RAM" $boldyellow

    if [ $TOTAL_MEM -ge 256 ];
    then
    	ASK "Due to this we recommend using the higher resource usage configuration files. Would you like to? [y/n] "
    	if [[ "$key" = [yY] ]];
    	then
    		MIN_CFG='n'
    	else
    	    MIN_CFG='y'
    	fi
    else
    	ASK "Due to this we highly recommend using the low resource usage configuration files. Would you like to? [y/n] "
    	if [[ "$key" = [yY] ]];
    	then
    		MIN_CFG='y'
    	else
    	    MIN_CFG='n'
    	fi
    fi
fi

if [[ "$NSD_INSTALL" = [yY] ]]; 
then
    echo "*************************************************"
    cecho "* Installing NSD" $boldgreen
    echo "*************************************************"
    cd /svr-setup
    if [ -s nsd-${NSD_VERSION}.tar.gz ]; then
        cecho "NSD ${NSD_VERSION} Archive found, skipping download..." $boldgreen
    else
        wget -c http://www.nlnetlabs.nl/downloads/nsd/nsd-${NSD_VERSION}.tar.gz --tries=3
    fi
    echo "Compiling NSD..."
    tar xzvf nsd-${NSD_VERSION}.tar.gz
    cd nsd-${NSD_VERSION}
    ./configure
    make$MAKETHREADS
    make install
    echo "Creating user and group for nsd..."
    groupadd nsd
    useradd -g nsd -s /sbin/nologin -M nsd
    echo "Setting up directories..."
    mkdir /var/run/nsd
    chown -R nsd:nsd /var/run/nsd/
    chown -R nsd:nsd /var/db/nsd/
    mkdir /etc/nsd/master
    mkdir /etc/nsd/slave
    chown -R nsd:nsd /etc/nsd/
    cp -R $CUR_DIR/config/nsd/* /etc/nsd/
    cd /etc/sysconfig/
    mv $CUR_DIR/sysconfig/nsd nsd
    cd /etc/init.d/
    mv $CUR_DIR/init/nsd nsd
    chmod +x /etc/init.d/nsd
    chkconfig --levels 235 nsd on
    echo "*************************************************"
    cecho "* NSD installed" $boldgreen
    echo "*************************************************"
fi

if [ -f /proc/user_beancounters ];
then
    cecho "OpenVZ system detected, NTP not installed" $boldgreen
else
    if [[ "$NTP_INSTALL" = [yY] ]]; 
    then
        echo "*************************************************"
        cecho "* Installing NTP (and syncing time)" $boldgreen
        echo "*************************************************"
        yum -y install ntp
        chkconfig --levels 235 ntpd on
        ntpdate pool.ntp.org
        echo "The date/time is now:"
        date
        echo "If this is correct, then everything is working properly"
        echo "*************************************************"
        cecho "* NTP installed" $boldgreen
        echo "*************************************************"
    fi
fi

if [[ "$NGINX_INSTALL" = [yY] ]]; 
then
    echo "*************************************************"
    cecho "* Installing nginx" $boldgreen
    echo "*************************************************"

    # Disable Apache if installed
    if [ -f /etc/init.d/httpd ];
    then
      /sbin/service httpd stop
      chkconfig httpd off
    fi

    # Then install nginx
    cd /svr-setup

    # Set VPS hard/soft limits
    echo "* soft nofile 65536" >>/etc/security/limits.conf
    echo "* hard nofile 65536" >>/etc/security/limits.conf

    # nginx Modules / Prerequisites
	cecho "Installing nginx Modules / Prerequisites..." $boldgreen

    # Install libunwind
    echo "Compiling libunwind..."
    if [ -s libunwind-${LIBUNWIND_VERSION}.tar.gz ]; then
        cecho "libunwind ${LIBUNWIND_VERSION} Archive found, skipping download..." $boldgreen 
    else
        wget -c http://download.savannah.gnu.org/releases/libunwind/libunwind-${LIBUNWIND_VERSION}.tar.gz --tries=3
    fi

    tar xvzf libunwind-${LIBUNWIND_VERSION}.tar.gz
    cd libunwind-${LIBUNWIND_VERSION}
    ./configure
    make$MAKETHREADS
    make install

    # Install google-perftools
    cd /svr-setup

    echo "Compiling google-perftools..."
    if [ -s google-perftools-${GPERFTOOLS_VERSION}.tar.gz ]; then
        cecho "google-perftools ${GPERFTOOLS_VERSION} Archive found, skipping download..." $boldgreen
    else
        wget -c http://google-perftools.googlecode.com/files/google-perftools-${GPERFTOOLS_VERSION}.tar.gz --tries=3
    fi

    tar xvzf google-perftools-${GPERFTOOLS_VERSION}.tar.gz
    cd google-perftools-${GPERFTOOLS_VERSION}
    ./configure --enable-frame-pointers
    make$MAKETHREADS
    make install
    echo "/usr/local/lib" > /etc/ld.so.conf.d/usr_local_lib.conf
    /sbin/ldconfig

    # Install OpenSSL
    cd /svr-setup

    echo "Compiling OpenSSL..."
    if [ -s openssl-${OPENSSL_VERSION}.tar.gz ]; then
        cecho "openssl ${OPENSSL_VERSION} Archive found, skipping download..." $boldgreen
    else
        wget -c http://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz --tries=3
    fi

    tar xvzf openssl-${OPENSSL_VERSION}.tar.gz
    cd openssl-${OPENSSL_VERSION}
    ./config shared --prefix=/usr/local --openssldir=/usr/local/ssl
    make$MAKETHREADS
    make install

    # Install PCRE
    cd /svr-setup

    echo "Compiling PCRE..."
    if [ -s pcre-${PCRE_VERSION}.tar.gz ]; then
        cecho "pcre ${PCRE_VERSION} Archive found, skipping download..." $boldgreen
    else
        wget -c ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/pcre-${PCRE_VERSION}.tar.gz --tries=3
    fi

    tar xvzf pcre-${PCRE_VERSION}.tar.gz
    cd pcre-${PCRE_VERSION}
    ./configure
    make$MAKETHREADS
    make install

    # nginx Modules
    cd /svr-setup

    if [ -s ngx-fancyindex-0.3.1.tar.gz ]; then
        cecho "ngx-fancyindex 0.3.1 Archive found, skipping download..." $boldgreen
    else
        wget -c http://gitorious.org/ngx-fancyindex/ngx-fancyindex/archive-tarball/v0.3.1 -O ngx-fancyindex-0.3.1.tar.gz --tries=3
    fi

    tar zvxf ngx-fancyindex-0.3.1.tar.gz

    if [ -s ngx_cache_purge-1.3.tar.gz ]; then
        cecho "ngx_cache_purge 1.3 Archive found, skipping download..." $boldgreen
    else
        wget -c http://labs.frickle.com/files/ngx_cache_purge-1.3.tar.gz --tries=3
    fi

    tar zvxf ngx_cache_purge-1.3.tar.gz

    if [ -s Nginx-accesskey-2.0.3.tar.gz ]; then
        cecho "Nginx-accesskey 2.0.3 Archive found, skipping download..." $boldgreen
    else
        wget -c http://wiki.nginx.org/images/5/51/Nginx-accesskey-2.0.3.tar.gz --tries=3
    fi

    tar zvxf Nginx-accesskey-2.0.3.tar.gz

    # Install nginx
    cd /svr-setup

    echo "Compiling nginx..."
    if [ -s nginx-${NGINX_VERSION}.tar.gz ]; then
        cecho "nginx ${NGINX_VERSION} Archive found, skipping download..." $boldgreen
    else
        wget -c "http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz" --tries=3
    fi

    tar xvfz nginx-${NGINX_VERSION}.tar.gz
    cd nginx-${NGINX_VERSION}

    ASK "Would you like to compile nginx with IPv6 support? [y/n] "
    if [[ "$key" = [yY] ]];
    then
        ./configure --sbin-path=/usr/local/sbin --conf-path=/usr/local/nginx/conf/nginx.conf --with-ipv6 --with-http_ssl_module --with-http_gzip_static_module --with-http_stub_status_module --with-http_sub_module --with-http_addition_module --with-http_secure_link_module --with-http_flv_module --with-http_realip_module --add-module=../ngx-fancyindex-ngx-fancyindex --add-module=../ngx_cache_purge-1.3 --add-module=../nginx-accesskey-2.0.3 --with-google_perftools_module --with-openssl=../openssl-${OPENSSL_VERSION} --with-openssl-opt="enable-tlsext"
    else
        ./configure --sbin-path=/usr/local/sbin --conf-path=/usr/local/nginx/conf/nginx.conf --with-http_ssl_module --with-http_gzip_static_module --with-http_stub_status_module --with-http_sub_module --with-http_addition_module --with-http_secure_link_module --with-http_flv_module --with-http_realip_module --add-module=../ngx-fancyindex-ngx-fancyindex --add-module=../ngx_cache_purge-1.3 --add-module=../nginx-accesskey-2.0.3 --with-google_perftools_module --with-openssl=../openssl-${OPENSSL_VERSION} --with-openssl-opt="enable-tlsext"
    fi    

    make$MAKETHREADS
    make install

    groupadd nginx
    useradd -g nginx -d /home/nginx -s /sbin/nologin nginx
    # Set user nginx hard/soft limits
    echo "nginx soft nofile 65536" >>/etc/security/limits.conf
    echo "nginx hard nofile 65536" >>/etc/security/limits.conf
    ulimit -n 65536

    mkdir /home/nginx/domains
    mkdir -p /home/nginx/domains/demo.com/{public,private,log,backup}
    cp -R $CUR_DIR/htdocs/demo.com/* /home/nginx/domains/demo.com/public
    chown -R nginx:nginx /home/nginx

    mkdir -p /usr/local/nginx/html
    mkdir -p /usr/local/nginx/conf/conf.d
    cp -R $CUR_DIR/htdocs/default/* /usr/local/nginx/html
    cp -R $CUR_DIR/config/nginx/* /usr/local/nginx/conf
    mv $CUR_DIR/init/nginx /etc/init.d/nginx
    chmod +x /etc/init.d/nginx
    chkconfig --levels 235 nginx on

    if [ ! -f /usr/local/nginx/conf/htpasswd ]; then
        touch /usr/local/nginx/conf/htpasswd
    fi

    if [ ! -f /etc/logrotate.d/nginx ]; then
        echo "*************************************************"
        cecho "* Creating /etc/logrotate.d/nginx file" $boldgreen
        echo "*************************************************"

        touch /etc/logrotate.d/nginx

cat > "/etc/logrotate.d/nginx" <<END
/var/log/nginx/*.log /usr/local/nginx/logs/*.log /home/nginx/domains/*/log/*.log {
        daily
        missingok
        rotate 10
        size=100M
        compress
        delaycompress
        notifempty
        postrotate
                /sbin/service nginx restart
        endscript            
}
END
    fi

    echo "*************************************************"
    cecho "* nginx logrotation setup completed" $boldgreen
    echo "*************************************************"

    cp $CUR_DIR/config/htpasswdgen/htpasswd.py /usr/local/nginx/conf/htpasswd.py
    echo "*************************************************"
    cecho "* nginx installed, Apache disabled" $boldgreen
    echo "*************************************************"
fi

if [[ "$MDB_INSTALL" = [yY] ]]; 
then
    echo "*************************************************"
    cecho "* Installing MariaDB " $boldgreen
    echo "*************************************************"
    service mysqld stop

    yum -y remove mysql mysql-libs
    if [ -f /etc/my.cnf ]; then
        cp /etc/my.cnf /etc/my.cnf-original
    fi

    # The MariaDB mirror uses x86 and amd64 prefixes for rpm folders instead of i386/x84_64, so compensate for that...
    if [ ${ARCH} == 'x86_64' ];
    then
        MDB_ARCH='amd64'
    else
        MDB_ARCH='x86'
    fi

    cd /svr-setup

    yum -y install perl-DBD-MySQL
    service mysqld stop
    yum -y remove mysql mysql-libs

    if [ ${MIN_CFG} == 'y' ]; then
        echo -e "\nCopying MariaDB my-mdb-min.cnf file to /etc/my.cnf\n"
        cp $CUR_DIR/config/mysql/my-mdb-min.cnf /etc/my.cnf
    else
        echo -e "\nCopying MariaDB my-mdb.cnf file to /etc/my.cnf\n"
        cp $CUR_DIR/config/mysql/my-mdb.cnf /etc/my.cnf
    fi

    if [ -s MariaDB-client-${MDB_VERSION}.el5.${ARCH}.rpm ]; then
        cecho "MariaDB-client-${MDB_VERSION}.el5.${ARCH}.rpm found, skipping download..." $boldgreen
    else
        wget -c http://mirror.aarnet.edu.au/pub/MariaDB/mariadb-${MDB_VERONLY}/kvm-rpm-centos5-${MDB_ARCH}/rpms/MariaDB-client-${MDB_VERSION}.el5.${ARCH}.rpm --tries=3
    fi

    if [ -s MariaDB-devel-${MDB_VERSION}.el5.${ARCH}.rpm ]; then
        cecho "MariaDB-devel-${MDB_VERSION}.el5.${ARCH}.rpm found, skipping download..." $boldgreen
    else
        wget -c http://mirror.aarnet.edu.au/pub/MariaDB/mariadb-${MDB_VERONLY}/kvm-rpm-centos5-${MDB_ARCH}/rpms/MariaDB-devel-${MDB_VERSION}.el5.${ARCH}.rpm --tries=3
    fi

    if [ -s MariaDB-server-${MDB_VERSION}.el5.${ARCH}.rpm ]; then
        cecho "MariaDB-server-${MDB_VERSION}.el5.${ARCH}.rpm found, skipping download..." $boldgreen
    else
        wget -c http://mirror.aarnet.edu.au/pub/MariaDB/mariadb-${MDB_VERONLY}/kvm-rpm-centos5-${MDB_ARCH}/rpms/MariaDB-server-${MDB_VERSION}.el5.${ARCH}.rpm --tries=3
    fi

    if [ -s MariaDB-shared-${MDB_VERSION}.el5.${ARCH}.rpm ]; then
        cecho "MariaDB-shared-${MDB_VERSION}.el5.${ARCH}.rpm found, skipping download..." $boldgreen
    else
        wget -c http://mirror.aarnet.edu.au/pub/MariaDB/mariadb-${MDB_VERONLY}/kvm-rpm-centos5-${MDB_ARCH}/rpms/MariaDB-shared-${MDB_VERSION}.el5.${ARCH}.rpm --tries=3
    fi

    if [ -s MariaDB-test-${MDB_VERSION}.el5.${ARCH}.rpm ]; then
        cecho "MariaDB-test-${MDB_VERSION}.el5.${ARCH}.rpm found, skipping download..." $boldgreen
    else
        wget -c http://mirror.aarnet.edu.au/pub/MariaDB/mariadb-${MDB_VERONLY}/kvm-rpm-centos5-${MDB_ARCH}/rpms/MariaDB-test-${MDB_VERSION}.el5.${ARCH}.rpm --tries=3
    fi

    rpm -i MariaDB-shared-${MDB_VERSION}.el5.${ARCH}.rpm
    rpm -i MariaDB-client-${MDB_VERSION}.el5.${ARCH}.rpm
    rpm -i MariaDB-devel-${MDB_VERSION}.el5.${ARCH}.rpm

    gzip /var/lib/mysql/{ibdata1,ib_logfile0,ib_logfile1}

    rpm -i MariaDB-server-${MDB_VERSION}.el5.${ARCH}.rpm
    rpm -i MariaDB-test-${MDB_VERSION}.el5.${ARCH}.rpm

    yum -y install perl-DBD-MySQL

    cd /root

    if [ -s mysqlreport ]; then
        cecho "mysqlreport found, skipping download..." $boldgreen
    else
        wget -c http://thisfile.net/mysqlreport --tries=3
    fi

    if [ -s mysqltuner.pl ]; then
        cecho "mysqltuner.pl found, skipping download..." $boldgreen
    else
        wget -c http://vbtechsupport.com/mysqltuner/mysqltuner.txt -O mysqltuner.pl --tries=3
    fi

    chmod +x mysqlreport mysqltuner.pl

    cd /svr-setup

    if [[ ! `grep exclude /etc/yum.conf` ]]; then
        cecho "Can't find exclude line in /etc/yum.conf... adding exclude line for mysql*" $boldgreen
        echo "exclude=mysql*">> /etc/yum.conf
    else
        cecho "exclude line exists... adding exclude line for mysql*" $boldgreen
        sed -i "s/exclude=\*.i386 \*.i586 \*.i686/exclude=\*.i386 \*.i586 \*.i686 mysql\*/" /etc/yum.conf
    fi

    echo "*************************************************"
    cecho "* Starting MariaDB Secure Installation" $boldgreen
    echo "*************************************************"
    mysql_upgrade --force --verbose
    service mysql restart
    mysql_secure_installation
    
    echo "*************************************************"
    cecho "* MariaDB installed" $boldgreen
    echo "*************************************************"
    
    /etc/init.d/mysql stop
    echo "*************************************************"
    cecho "* MariaDB installed" $boldgreen
    echo "*************************************************"
    
    /etc/init.d/mysql stop
fi

if [[ "$MYSQL_INSTALL" = [yY] ]]; 
then
    echo "*************************************************"
    cecho "* Installing MySQL" $boldgreen
    echo "*************************************************"
    yum -y install mysql mysql-devel mysql-server perl-DBD-MySQL

    if [ -f /etc/my.cnf ]; then
        cp /etc/my.cnf /etc/my.cnf-original
    fi

    if [ ${MIN_CFG} == 'y' ]; then
        echo -e "\nCopying MySQL my-min.cnf file to /etc/my.cnf\n"
        cp $CUR_DIR/config/mysql/my-min.cnf /etc/my.cnf
    else
        echo -e "\nCopying MySQL my.cnf file to /etc/my.cnf\n"
        cp $CUR_DIR/config/mysql/my.cnf /etc/my.cnf
    fi

    cd /root

    if [ -s mysqlreport ]; then
        cecho "mysqlreport found, skipping download..." $boldgreen
    else
        wget -c http://thisfile.net/mysqlreport --tries=3
    fi

    if [ -s mysqltuner.pl ]; then
        cecho "mysqltuner.pl found, skipping download..." $boldgreen
    else
        wget -c http://vbtechsupport.com/mysqltuner/mysqltuner.txt -O mysqltuner.pl --tries=3
    fi

    chmod +x mysqlreport mysqltuner.pl

    cd /svr-setup

    chkconfig --levels 235 mysqld on
    /etc/init.d/mysqld start

    echo "*************************************************"
    cecho "* Starting MySQL Secure Installation" $boldgreen
    echo "*************************************************"
    mysql_secure_installation
    echo "*************************************************"
    cecho "* MySQL installed" $boldgreen
    echo "*************************************************"

    /etc/init.d/mysqld stop
fi

if [[ "$PHP_INSTALL" = [yY] ]]; 
then
    echo "*************************************************"
    cecho "* Installing PHP" $boldgreen
    echo "*************************************************"

    if [[ "$CENTOSVER" != '5.5' ]]; then
        MCRYPT=" --with-mcrypt"
    else
        MCRYPT=""
    fi

    export PHP_AUTOCONF=/usr/bin/autoconf-2.13
    export PHP_AUTOHEADER=/usr/bin/autoheader-2.13

    cd /svr-setup

    # IMPORTANT Erase any PHP installations first, otherwise conflicts may arise
    yum -y erase php*

    if [ -s php-${PHP_VERSION}.tar.gz ]; then
        cecho "php ${PHP_VERSION} Archive found, skipping download..." $boldgreen
    else
        wget -c http://us2.php.net/get/php-${PHP_VERSION}.tar.gz/from/this/mirror --tries=3
    fi

    tar xzvf php-${PHP_VERSION}.tar.gz

    cd php-${PHP_VERSION}

    ./buildconf --force
    mkdir fpm-build && cd fpm-build

    mkdir -p /usr/${LIBDIR}/mysql
    ln -s /usr/${LIBDIR}/libmysqlclient.so /usr/${LIBDIR}/mysql/libmysqlclient.so

../configure --enable-cgi --enable-fpm${MCRYPT} --with-mhash --with-zlib --with-gettext --enable-exif --enable-zip --with-bz2 --enable-soap --enable-sockets --enable-sysvmsg --enable-sysvsem --enable-sysvshm --enable-shmop --with-pear --enable-mbstring --with-openssl --with-mysql=/usr/bin/ --with-libdir=${LIBDIR} --with-mysqli=/usr/bin/mysql_config --with-mysql-sock --with-curl --with-gd --with-xmlrpc --enable-bcmath --enable-calendar --enable-ftp --enable-gd-native-ttf --with-freetype-dir=${LIBDIR} --with-jpeg-dir=${LIBDIR} --with-png-dir=${LIBDIR} --with-xpm-dir=${LIBDIR} --enable-pdo --with-pdo-sqlite --with-pdo-mysql --with-imap --with-imap-ssl --with-kerberos --mandir=/usr/share/man --infodir=/usr/share/info --enable-mbregex --with-pcre-regex --enable-inline-optimization --with-fpm-user=nginx --with-fpm-group=nginx

    make$MAKETHREADS
    make install

    cd ../

    CUSTOMPHPINICHECK=`grep 'realpath_cache_size = 1024k' /usr/local/lib/php.ini`

    if [[ -z $CUSTOMPHPINICHECK ]]; then

    cp -f php.ini-production /usr/local/lib/php.ini
    chmod 644 /usr/local/lib/php.ini

    sed -i "s/;date.timezone =/date.timezone = Europe\/London/g" /usr/local/lib/php.ini

    sed -i 's/short_open_tag = Off/short_open_tag = On/g' /usr/local/lib/php.ini
    sed -i 's/;realpath_cache_size = 16k/realpath_cache_size = 1024k/g' /usr/local/lib/php.ini
    sed -i 's/;realpath_cache_ttl = 120/realpath_cache_ttl = 180/g' /usr/local/lib/php.ini
    sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 15M/g' /usr/local/lib/php.ini
    #sed -i 's/memory_limit = 128M/memory_limit = 256M/g' /usr/local/lib/php.ini
    sed -i 's/post_max_size = 8M/post_max_size = 15M/g' /usr/local/lib/php.ini
    
    fi

    if [ ${MIN_CFG} == 'y' ]; then
        echo -e "\nCopying php-fpm-min.conf /usr/local/etc/php-fpm.conf\n"
        cp $CUR_DIR/config/php-fpm/php-fpm-min.conf /usr/local/etc/php-fpm.conf
    else
        echo -e "\nCopying php-fpm.conf /usr/local/etc/php-fpm.conf\n"
        cp $CUR_DIR/config/php-fpm/php-fpm.conf /usr/local/etc/php-fpm.conf
    fi

    cp $CUR_DIR/init/php-fpm /etc/init.d/php-fpm

    chmod +x /etc/init.d/php-fpm

    mkdir -p /var/run/php-fpm
    touch /var/run/php-fpm/php-fpm.pid
    chown nginx:nginx /var/run/php-fpm

    mkdir /var/log/php-fpm/
    touch /var/log/php-fpm/www-error.log
    chmod 0666 /var/log/php-fpm/www-error.log

    chkconfig --levels 235 php-fpm on
    /etc/init.d/php-fpm start

    if [[ `grep exclude /etc/yum.conf` && $MDB_INSTALL = y ]]; then
        cecho "exclude line exists... adding mysql* php*" $boldgreen
        sed -i "s/exclude=\*.i386 \*.i586 \*.i686 mysql\*/exclude=\*.i386 \*.i586 \*.i686 mysql\* php\*/" /etc/yum.conf
        sed -i "s/exclude=mysql\*/exclude=mysql\* php\*/" /etc/yum.conf
    elif [[ `grep exclude /etc/yum.conf` ]]; then
        cecho "exclude line exists... adding php*" $boldgreen
        sed -i "s/exclude=\*.i386 \*.i586 \*.i686/exclude=\*.i386 \*.i586 \*.i686 php\*/" /etc/yum.conf 
    fi

    if [[ ! `grep exclude /etc/yum.conf` && $MDB_INSTALL = y ]]; then
        cecho "Can't find exclude line in /etc/yum.conf.. adding exclude line for mysql* php*" $boldgreen
        echo "exclude=mysql* php*">> /etc/yum.conf
    elif [[ ! `grep exclude /etc/yum.conf` ]]; then
        cecho "Can't find exclude line in /etc/yum.conf... adding exclude line for php*" $boldgreen
        echo "exclude=php*">> /etc/yum.conf
    fi

    if [ ! -f /etc/logrotate.d/php-fpm ]; then
        echo "*************************************************"
        cecho "* Creating /etc/logrotate.d/php-fpm file" $boldgreen
        echo "*************************************************"

        touch /etc/logrotate.d/php-fpm

cat > "/etc/logrotate.d/php-fpm" <<END
/var/log/php-fpm/*.log {
        daily
        missingok
        rotate 10
        size=100M
        compress
        delaycompress
        notifempty
        postrotate
                /sbin/service php-fpm restart
        endscript            
}
END
    fi

    echo "*************************************************"
    cecho "* nginx logrotation setup completed" $boldgreen
    echo "*************************************************"

    echo "*************************************************"
    cecho "* PHP installed" $boldgreen
    echo "*************************************************"
fi

ASK "Install XCache? (By default uses 32MB RAM) If XCache installed DO NOT install APC [y/n] "
if [[ "$key" = [yY] ]];
then
    echo "*************************************************"
    cecho "* Installing XCache" $boldgreen
    echo "*************************************************"

    cd /svr-setup

    if [ -s xcache-${XCACHE_VERSION}.tar.gz ]; then
        cecho "xcache ${XCACHE_VERSION} Archive found, skipping download..." $boldgreen
    else
        wget -c http://xcache.lighttpd.net/pub/Releases/${XCACHE_VERSION}/xcache-${XCACHE_VERSION}.tar.gz --tries=3
    fi

    if [ ${MIN_CFG} == 'y' ]; then
        echo -e "\nCopying xcache-min.ini >> /usr/local/lib/php.ini\n"
        cat $CUR_DIR/config/xcache/xcache-min.ini >> /usr/local/lib/php.ini
    else
        echo -e "\nCopying xcache.ini >> /usr/local/lib/php.ini\n"
        cat $CUR_DIR/config/xcache/xcache.ini >> /usr/local/lib/php.ini
    fi

    export PHP_AUTOCONF=/usr/bin/autoconf
    export PHP_AUTOHEADER=/usr/bin/autoheader

    tar xvfz xcache-${XCACHE_VERSION}.tar.gz
    cd xcache-${XCACHE_VERSION}
    /usr/local/bin/phpize
    ./configure --enable-xcache --with-php-config=/usr/local/bin/php-config
    make$MAKETHREADS && make install

    if [ ! -d /usr/local/nginx/html/myxcacheadmin ]; then
        echo ""
        cecho "Creating xcache admin directory at /usr/local/nginx/html/myxcacheadmin " $boldgreen
        mkdir /usr/local/nginx/html/myxcacheadmin
    fi

    cp -a admin/* /usr/local/nginx/html/myxcacheadmin
    chown -R nginx:nginx /usr/local/nginx/html/myxcacheadmin

    echo ""
    echo "*************************************************"
    cecho "Setup Xcache Admin Password for /usr/local/nginx/html/myxcacheadmin" $boldgreen
    echo "*************************************************"
    echo -n "(Type password your want to set and press Enter): "
    read xcachepassword

    xcachepass="`echo -n "${xcachepassword}" | md5sum | awk '{ print $1 }'`"

    cecho "old password: `grep xcache.admin.pass /usr/local/lib/php.ini | awk '{ print $3 }' | sed -e 's/"//g'`" $boldgreen
    cecho "new password: ${xcachepass}" $boldgreen
    cecho "xcache username: `grep xcache.admin.user /usr/local/lib/php.ini | awk '{ print $3 }' | sed -e 's/"//g'`" $boldgreen

    sed -i "s/d440aed189a13ff970dac7e7e8f987b2/${xcachepass}/g" /usr/local/lib/php.ini

    cecho "php.ini now has xcache.admin.pass set as follows: :" $boldgreen
    cecho "`cat /usr/local/lib/php.ini | grep xcache.admin.pass`" $boldgreen

    /etc/init.d/php-fpm restart
    echo "*************************************************"
    cecho "* XCache installed" $boldgreen
    echo "*************************************************"
fi

cecho "* If you installed Xcache, DO NOT install APC" $boldgreen

ASK "Install APC? (By default uses 32MB RAM) [y/n] "
if [[ "$key" = [yY] ]];
then
    echo "*************************************************"
    cecho "* Installing Alternative PHP Cache" $boldgreen
    echo "*************************************************"

    cd /svr-setup

    if [ -s APC-${APCCACHE_VERSION}.tgz ]; then
        cecho "xcache APC-${APCCACHE_VERSION}.tgz Archive found, skipping download..." $boldgreen
    else
        wget -c http://pecl.php.net/get/APC-${APCCACHE_VERSION}.tgz --tries=3
    fi

    export PHP_AUTOCONF=/usr/bin/autoconf
    export PHP_AUTOHEADER=/usr/bin/autoheader

    tar xvzf APC-${APCCACHE_VERSION}.tgz
    cd APC-${APCCACHE_VERSION}
    /usr/local/bin/phpize
    ./configure --with-php-config=/usr/local/bin/php-config
    make$MAKETHREADS
    make install

    cp apc.php /usr/local/nginx/html/myapc.php
    chown nginx:nginx /usr/local/nginx/html/myapc.php

    if [ ${MIN_CFG} == 'y' ]; then
        echo -e "\nCopying apc-min.ini >> /usr/local/lib/php.ini\n"
        cat $CUR_DIR/config/apc/apc-min.ini >> /usr/local/lib/php.ini
    else
        echo -e "\nCopying apc.ini >> /usr/local/lib/php.ini\n"
        cat $CUR_DIR/config/apc/apc.ini >> /usr/local/lib/php.ini
    fi

    /etc/init.d/php-fpm restart
    echo "*************************************************"
    cecho "* Alternative PHP Cache installed" $boldgreen
    echo "*************************************************"
fi

ASK "Install Memcached Server? (By default each uses 16MB RAM) [y/n] "
if [[ "$key" = [yY] ]];
then
    echo "*************************************************"
    cecho "* Installing memcached" $boldgreen
    echo "*************************************************"
    echo "Downloading memcached..."
    cd /svr-setup

    if [ -s libevent-${LIBEVENT_VERSION}-stable.tar.gz ]; then
        echo "libevent-${LIBEVENT_VERSION} Archive found, skipping download..." $boldgreen
    else
        wget -c http://www.monkey.org/~provos/libevent-${LIBEVENT_VERSION}-stable.tar.gz --tries=3
    fi

    if [ -s memcached-${MEMCACHED_VERSION}.tar.gz ]; then
        cecho "memcached ${MEMCACHED_VERSION} Archive found, skipping download..." $boldgreen
    else
        wget -c http://memcached.googlecode.com/files/memcached-${MEMCACHED_VERSION}.tar.gz --tries=3
    fi

    if [ -s memcache-${MEMCACHE_VERSION}.tgz ]; then
        cecho "memcache ${MEMCACHE_VERSION} Archive found, skipping download..." $boldgreen
    else
        wget -c http://pecl.php.net/get/memcache-${MEMCACHE_VERSION}.tgz --tries=3
    fi

    cecho "Compiling libevent..." $boldgreen

    cd /svr-setup
    tar xfz libevent-${LIBEVENT_VERSION}-stable.tar.gz
    cd libevent-${LIBEVENT_VERSION}-stable
    ./configure --prefix=/usr/${LIBDIR}
    make$MAKETHREADS && make install

    echo "/usr/${LIBDIR}/lib/" > /etc/ld.so.conf.d/libevent-i386.conf
    ldconfig

    cecho "Compiling memcached..." $boldgreen

    cd /svr-setup
    tar xzf memcached-${MEMCACHED_VERSION}.tar.gz
    cd memcached-${MEMCACHED_VERSION}
    ./configure --with-libevent=/usr/${LIBDIR}
    make$MAKETHREADS && make install
    cp /svr-setup/memcached-${MEMCACHED_VERSION}/scripts/memcached-tool /usr/local/bin

    cecho "Compiling memcached..." $boldgreen

    cd /svr-setup
    cp $CUR_DIR/config/memcached/memcached /etc/init.d/memcached
    chmod +x /etc/init.d/memcached
    chkconfig --add memcached
    chkconfig --level 345 memcached on
    service memcached start

    cecho "Compiling PHP memcache extension..." $boldgreen

    cd /svr-setup
    tar -xvf memcache-${MEMCACHE_VERSION}.tgz
    cd memcache-${MEMCACHE_VERSION}
    /usr/local/bin/phpize
    ./configure --enable-memcache --with-php-config=/usr/local/bin/php-config
    make$MAKETHREADS && make install
    echo "" >> /usr/local/lib/php.ini
    echo "extension=/usr/local/lib/php/extensions/no-debug-non-zts-20090626/memcache.so" >> /usr/local/lib/php.ini

    /etc/init.d/php-fpm restart

    echo ""
    echo "*************************************************"
    cecho "Setup memcached.php admin page ..." $boldgreen
    echo "*************************************************"

    cp -a memcache.php /usr/local/nginx/html
    chown -R nginx:nginx /usr/local/nginx/html
    chmod 644 /usr/local/nginx/html/memcache.php

    sed -i "s/'ADMIN_USERNAME','memcache'/'ADMIN_USERNAME','memcacheuser'/g" /usr/local/nginx/html/memcache.php
    sed -i "s/'ADMIN_PASSWORD','password'/'ADMIN_PASSWORD','memcachepass'/g" /usr/local/nginx/html/memcache.php
    sed -i "s/mymemcache-server1:11211/localhost:11211/g" /usr/local/nginx/html/memcache.php
    sed -i "s/mymemcache-server2:11211/localhost:11212/g" /usr/local/nginx/html/memcache.php

    cecho "Setup Memcached Server Admin Login Details for /usr/local/nginx/html/memcache.php" $boldgreen
    echo -n "(Type username your want to set and press Enter): "
    read memcacheduser
    echo -n "(Type password your want to set and press Enter): "
    read memcachedpassword

    cecho "current memcached username: `grep "'ADMIN_USERNAME','memcacheuser'" /usr/local/nginx/html/memcache.php | sed -e "s/define('ADMIN_USERNAME','//" | sed -e 's/\/\/ Admin Username//' | sed 's/^[ \t]*//;s/[ \t]*$//' | sed -e "s/');//"`" $boldgreen

    cecho "current memcached password: `grep "'ADMIN_PASSWORD','memcachepass'" /usr/local/nginx/html/memcache.php | sed -e "s/define('ADMIN_PASSWORD','//" | sed -e 's/\/\/ Admin Password//' | sed 's/^[ \t]*//;s/[ \t]*$//' | sed -e "s/');//"`" $boldgreen

    sed -i "s/'ADMIN_USERNAME','memcacheuser'/'ADMIN_USERNAME','${memcacheduser}'/g" /usr/local/nginx/html/memcache.php
    sed -i "s/'ADMIN_PASSWORD','memcachepass'/'ADMIN_PASSWORD','${memcachedpassword}'/g" /usr/local/nginx/html/memcache.php

    cecho "new memcached username: ${memcacheduser}" $boldgreen
    cecho "new memcached password: ${memcachedpassword}" $boldgreen

    echo "*************************************************"
    cecho "* memcached installed" $boldgreen
    echo "*************************************************"
fi

if [[ "$SENDMAIL_INSTALL" = [yY] ]]; 
then
    echo "*************************************************"
    cecho "* Installing sendmail" $boldgreen
    echo "*************************************************"
    yum -y install sendmail mailx
    chkconfig --levels 235 sendmail on
    /etc/init.d/sendmail start
    echo "*************************************************"
    cecho "* sendmail installed" $boldgreen
    echo "*************************************************"
fi

ASK "Install CSF firewall script ? [y/n] "
if [[ "$key" = [yY] ]];
then
    echo "*************************************************"
    cecho "* Installing CSF firewall... " $boldgreen
    echo "*************************************************"
    echo "Installing..."

    cd /svr-setup

    if [ -s csf.tgz ]; then
        cecho "csf Archive found, skipping download..." $boldgreen
    else
        wget -c http://www.configserver.com/free/csf.tgz --tries=3
    fi

    yum -y install perl-libwww-perl perl-Time-HiRes

    tar xzf csf.tgz
    cd csf
    sh install.sh

    echo "Test IP Tables Modules..."

    perl /etc/csf/csftest.pl

    echo "CSF adding memcached, varnish ports to csf.allow list..."
    sed -i 's/20,21,22,25,53,80,110,143,443,465,587,993,995/20,21,22,25,53,80,110,143,161,443,465,587,993,995,1186,2202,11211,11212,11213,11214,2222,3334,8080,8888,81,9000,9001,6081,6082,3000:3050/g' /etc/csf/csf.conf

    echo "Disabling CSF Testing mode (activates firewall)..."
    sed -i 's/TESTING = "1"/TESTING = "0"/g' /etc/csf/csf.conf

    echo "Adding Applications/Users to CSF ignore list..."
cat >>/etc/csf/csf.pignore<<EOF
exe:/usr/local/bin/memcached
cmd:/usr/local/bin/memcached
user:mysql
exe:/usr/sbin/mysqld 
cmd:/usr/sbin/mysqld
user:varnish
exe:/usr/sbin/varnishd
cmd:/usr/sbin/varnishd
exe:/sbin/portmap
cmd:portmap
exe:/usr/libexec/gdmgreeter
cmd:/usr/libexec/gdmgreeter
exe:/usr/sbin/avahi-daemon
cmd:avahi-daemon
exe:/sbin/rpc.statd
cmd:rpc.statd
exe:/usr/libexec/hald-addon-acpi
cmd:hald-addon-acpi
user:nsd
user:nginx
user:ntp
user:dbus
user:smmsp
user:postfix
user:dovecot
user:www-data
user:spamfilter
EOF

    chkconfig --levels 235 csf on
    service csf restart

    echo "*************************************************"
    cecho "* CSF firewall installed " $boldgreen
    echo "*************************************************"
fi

ASK "Install Siege Benchmark script ? [y/n] "
if [[ "$key" = [yY] ]];
then
    echo "*************************************************"
    cecho "* Installing Siege Benchmark... " $boldgreen
    echo "*************************************************"
    echo "Installing..."

    cd /svr-setup

    if [ -s siege-latest.tar.gz ]; then
        cecho "siege-latest Archive found, skipping download..." $boldgreen
    else
        wget -c http://www.joedog.org/pub/siege/siege-latest.tar.gz --tries=3
    fi

    if [ -s sproxy-latest.tar.gz ]; then
        cecho "sproxy-latest Archive found, skipping download..." $boldgreen
    else
        wget -c http://www.joedog.org/pub/sproxy/sproxy-latest.tar.gz --tries=3
    fi

    tar -xzf siege-latest.tar.gz
    cd siege-2.70
    ./configure
    make$MAKETHREADS
    make install
    mkdir /usr/local/var/

    sed -i 's/# failures =/failures = 2048/g' /usr/local/etc/siegerc

    cd /svr-setup

    tar -xzf sproxy-latest.tar.gz
    cd sproxy-1.01
    ./configure
    make$MAKETHREADS
    make install

    echo "*************************************************"
    cecho "* Siege Benchmark installed " $boldgreen
    echo "*************************************************"
fi

ASK "Install Python Update ? [y/n] "
if [[ "$key" = [yY] ]];
then
    echo "*************************************************"
    cecho "* Installing Python... " $boldgreen
    echo "*************************************************"
    echo "Installing..."

    cd /svr-setup

    if [ -s Python-${PYTHON_VERSION}.tgz ]; then
        cecho "Python-${PYTHON_VERSION} Archive found, skipping download..." $boldgreen
    else
        wget -c http://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz --tries=3
    fi

    if [ -s setuptools-0.6c11-py2.7.egg ]; then
        cecho "setuptools-0.6c11-py2.7.egg found, skipping download..." $boldgreen
    else
        wget -c http://pypi.python.org/packages/2.7/s/setuptools/setuptools-0.6c11-py2.7.egg --tries=3
    fi

    cecho "Compiling Python..." $boldgreen

    tar xvfz Python-${PYTHON_VERSION}.tgz
    cd Python-${PYTHON_VERSION}
    ./configure --prefix=/opt/python${PYTHON_VERSION} --with-threads --enable-shared
    make$MAKETHREADS
    make install

    touch /etc/ld.so.conf.d/opt-python${PYTHON_VERSION}.conf
    echo "/opt/python${PYTHON_VERSION}/lib/" >> /etc/ld.so.conf.d/opt-python${PYTHON_VERSION}.conf
    ldconfig

    ln -sf /opt/python${PYTHON_VERSION}/bin/python /usr/bin/python2.7

    cd /svr-setup

    sh setuptools-0.6c11-py2.7.egg --prefix=/opt/python${PYTHON_VERSION}

    /opt/python${PYTHON_VERSION}/bin/easy_install pip

    ln -sf /opt/python${PYTHON_VERSION}/bin/pip /usr/bin/pip
    ln -sf /opt/python${PYTHON_VERSION}/bin/virtualenv /usr/bin/virtualenv

    echo "alias python=/opt/python${PYTHON_VERSION}/bin/python" >> ~/.bash_profile
    echo "alias python2.7=/opt/python${PYTHON_VERSION}/bin/python" >> ~/.bash_profile
    echo "PATH=$PATH:/opt/python2.7/bin" >> ~/.bash_profile
    source ~/.bash_profile

    echo "*************************************************"
    cecho "* Python Update installed " $boldgreen
    echo "*************************************************"
fi

if [ -f $CUR_DIR/Extras/nginx-update.sh ];
then
    chmod +x $CUR_DIR/Extras/nginx-update.sh
fi

echo " "

ASK "Add script shortcuts (as shown in command_shortcuts.txt) ? [y/n] "
if [[ "$key" = [yY] ]];
then
    cecho "**********************************************************************" $boldgreen
    cecho "* Add cmd shortcuts for php.ini, my.cnf, php-fpm.conf, nginx.conf and virtual.conf " $boldgreen
    cecho "* Edit php.ini = phpedit " $boldgreen
    cecho "* Edit my.cnf = mycnf " $boldgreen
    cecho "* Edit php-fpm.conf = fpmconf " $boldgreen
    cecho "* Edit nginx.conf = nginxconf " $boldgreen
    cecho "* Edit (nginx) virtual.conf = vhostconf " $boldgreen
    cecho "* Edit (nginx) php.conf = phpinc " $boldgreen
    cecho "* Edit (nginx) drop.conf = dropinc " $boldgreen
    cecho "* Edit (nginx) staticfiles.conf = statfilesinc " $boldgreen
    cecho "* nginx stop/start/restart = ngxstop/ngxstart/ngxrestart " $boldgreen
    cecho "* php-fpm stop/start/restart = fpmstop/fpmstart/fpmrestart " $boldgreen
    cecho "* mysql stop/start/restart = mysqlstop/mysqlstart/mysqlrestart " $boldgreen
    cecho "* nginx + php-fpm stop/start/restart = npstop/npstart/nprestart " $boldgreen
    cecho "* memcached stop/start/restart = memcachedstop/memcachedstart/memcachedrestart " $boldgreen
    cecho "* csf stop/start/restart = csfstop/csfstart/csfrestart " $boldgreen
    cecho "**********************************************************************" $boldgreen

    echo "nano -w /usr/local/lib/php.ini" > /usr/bin/phpedit ; chmod 700 /usr/bin/phpedit
    echo "nano -w /etc/my.cnf" >/usr/bin/mycnf ; chmod 700 /usr/bin/mycnf
    echo "nano -w /usr/local/etc/php-fpm.conf" >/usr/bin/fpmconf ; chmod 700 /usr/bin/fpmconf
    echo "nano -w /usr/local/nginx/conf/nginx.conf" >/usr/bin/nginxconf ; chmod 700 /usr/bin/nginxconf
    echo "nano -w /usr/local/nginx/conf/conf.d/virtual.conf" >/usr/bin/vhostconf ; chmod 700 /usr/bin/vhostconf
    echo "nano -w /usr/local/nginx/conf/php.conf" >/usr/bin/phpinc ; chmod 700 /usr/bin/phpinc
    echo "nano -w /usr/local/nginx/conf/drop.conf" >/usr/bin/dropinc ; chmod 700 /usr/bin/dropinc
    echo "nano -w /usr/local/nginx/conf/staticfiles.conf" >/usr/bin/statfilesinc ; chmod 700 /usr/bin/statfilesinc

    echo "service nginx stop" >/usr/bin/ngxstop ; chmod 700 /usr/bin/ngxstop
    echo "service nginx start" >/usr/bin/ngxstart ; chmod 700 /usr/bin/ngxstart
    echo "service nginx restart" >/usr/bin/ngxrestart ; chmod 700 /usr/bin/ngxrestart
    echo "service php-fpm stop" >/usr/bin/fpmstop ; chmod 700 /usr/bin/fpmstop
    echo "service php-fpm start" >/usr/bin/fpmstart ; chmod 700 /usr/bin/fpmstart
    echo "service php-fpm restart" >/usr/bin/fpmrestart ; chmod 700 /usr/bin/fpmrestart

    if [ -f /etc/init.d/mysql ]; then
        echo "service mysql stop" >/usr/bin/mysqlstop ; chmod 700 /usr/bin/mysqlstop
        echo "service mysql start" >/usr/bin/mysqlstart ; chmod 700 /usr/bin/mysqlstart
        echo "service mysql restart" >/usr/bin/mysqlrestart ; chmod 700 /usr/bin/mysqlrestart
    elif [ -f /etc/init.d/mysqld ]; then
        echo "service mysqld stop" >/usr/bin/mysqlstop ; chmod 700 /usr/bin/mysqlstop
        echo "service mysqld start" >/usr/bin/mysqlstart ; chmod 700 /usr/bin/mysqlstart
        echo "service mysqld restart" >/usr/bin/mysqlrestart ; chmod 700 /usr/bin/mysqlrestart
    fi

    echo "service nginx stop;service php-fpm stop" >/usr/bin/npstop ; chmod 700 /usr/bin/npstop
    echo "service nginx start;service php-fpm start" >/usr/bin/npstart ; chmod 700 /usr/bin/npstart
    echo "service nginx restart;service php-fpm restart" >/usr/bin/nprestart ; chmod 700 /usr/bin/nprestart
    echo "service memcached stop" >/usr/bin/memcachedstop ; chmod 700 /usr/bin/memcachedstop
    echo "service memcached start" >/usr/bin/memcachedstart ; chmod 700 /usr/bin/memcachedstart
    echo "service memcached restart" >/usr/bin/memcachedrestart ; chmod 700 /usr/bin/memcachedrestart

    echo "service csf stop" >/usr/bin/csfstop ; chmod 700 /usr/bin/csfstop
    echo "service csf start" >/usr/bin/csfstart ; chmod 700 /usr/bin/csfstart
    echo "service csf restart" >/usr/bin/csfrestart ; chmod 700 /usr/bin/csfrestart
fi

echo " "

cecho "**********************************************************************" $boldgreen
cecho "* Starting Services..." $boldgreen
cecho "**********************************************************************" $boldgreen
if [[ "$NSD_INSTALL" = [yY] ]]; 
then
    /etc/init.d/nsd start
fi

if [ -f /etc/init.d/ntpd ];
then
    /etc/init.d/ntpd start
fi

if [[ "$NGINX_INSTALL" = [yY] ]]; 
then
    /etc/init.d/nginx start
fi

if [[ "$MDB_INSTALL" = [yY] ]]; 
then
    /etc/init.d/mysql start
fi

if [[ "$MYSQL_INSTALL" = [yY] ]]; 
then
    /etc/init.d/mysqld start
fi

echo " "

cecho "**********************************************************************" $boldgreen
cecho "* Adding nginx-update and nginx-vhost commands..." $boldgreen
cecho "**********************************************************************" $boldgreen

cp -R $CUR_DIR/Extras/nginx-update.sh /sbin/nginx-update
cp -R $CUR_DIR/Extras/nginx-vhost.sh /sbin/nginx-vhost

chmod +x /sbin/nginx-update
chmod +x /sbin/nginx-vhost

cecho "**********************************************************************" $boldgreen
cecho "* Added nginx-update and nginx-vhost commands!" $boldgreen
cecho "**********************************************************************" $boldgreen

cd

ASK "Do would you like to run script cleanup (Highly recommended) ? [y/n] "
if [[ "$key" = [yY] ]];
then
    rm -rf /svr-setup
    rm -rf $CUR_DIR/config
    rm -rf $CUR_DIR/init
    rm -rf $CUR_DIR/sysconfig
    echo "Temporary files/folders removed"
fi

ASK "Do you want to delete this script ? [y/n] "
if [[ "$key" = [yY] ]];
then
    echo "*************************************************"
    cecho "* Deleting Centmin script... " $boldgreen
    echo "*************************************************"
    echo "Removing..."

rm -f $0

    echo "*************************************************"
    cecho "* Centmin script deleted" $boldgreen
    echo "*************************************************"
fi

    echo "*************************************************"
    cecho "* Running updatedb command. Please wait...." $boldgreen
    echo "*************************************************"

updatedb

if [ -f /proc/user_beancounters ]; then

    echo ""
    echo "*************************************************"
    cecho "* Correct service's stack size for OpenVZ systems. Please wait...." $boldgreen
    echo "*************************************************"

    sed -i 's/#!\/bin\/bash/#!\/bin\/bash\nif [ -f \/proc\/user_beancounters ]; then\nulimit -s 512\nfi\n/g' /etc/init.d/rsyslog
    sed -i 's/#!\/bin\/bash/#!\/bin\/bash\nif [ -f \/proc\/user_beancounters ]; then\nulimit -s 512\nfi\n/g' /etc/init.d/nsd
    sed -i 's/#!\/bin\/sh/#!\/bin\/sh\nif [ -f \/proc\/user_beancounters ]; then\nulimit -s 512\nfi\n/g' /etc/init.d/nginx
    sed -i 's/#!\/bin\/sh/#!\/bin\/sh\nif [ -f \/proc\/user_beancounters ]; then\nulimit -s 512\nfi\n/g' /etc/init.d/php-fpm
    sed -i 's/#!\/bin\/sh/#!\/bin\/sh\nif [ -f \/proc\/user_beancounters ]; then\nulimit -s 2048\nfi\n/g' /etc/init.d/lfd

    RSYSLOGRUNNING=`service rsyslog status | awk '{ print $5 }' | sed 's/running.\.\./running/g'`

    if [[ "$RSYSLOGRUNNING" = 'running' ]]; then
        service rsyslog restart
    fi

fi

echo " "

cecho "**********************************************************************" $boldgreen
cecho "* Installation complete, congratulations!" $boldgreen
cecho "* For security reasons we would recommend deleting this script." $boldgreen
cecho "* " $boldgreen
cecho "* We would highly recommend that you reboot your server." $boldgreen
cecho "* " $boldgreen
cecho "* Enjoy CentOS  -  BTCentral" $boldgreen
cecho "**********************************************************************" $boldgreen

exit 0