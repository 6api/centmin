BTCentral Centmin - a CentOS Minimal install script for Nginx, PHP, MySQL, SendMail and NSD
Copyright 2011, BTCentral - http://www.btcentral.org.uk
With Contributions by eva2000 - http://www.vbtechsupport.com

Version 1.2.3 - 4th October, 2011

Please note:

This software is provided "as is" in the hope that it will be useful, but WITHOUT ANY WARRANTY, to the
extent permitted by law; without even the implied warranty of MERCHANTABILITY OR FITNESS FOR A
PARTICULAR PURPOSE. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
SUCH DAMAGE.

This script is NOT SUPPORTED in any way, shape or form. While the script may be updated periodically,
any support requests will be ignored (unless you wish to pay our standard support rate of 25 GBP/hour).

However, if you have noticed a bug please feel free to let us know and we will fix it as soon as possible.

License:

This script is licensed under GPLv3 (or higher - at your discretion, if available)
For details please read the included license.txt or visit http://www.gnu.org/licenses/gpl.html

But basically, feel free to modify or use this script as you see fit. If you have made modifications
that you feel would be useful to be included in this, let us know where we can download a copy and we
will consider adding them.

Configuration:

If you are using Xen Paravirtualization and are running a 32bit OS on a 64bit host node, then you must
uncomment the "#ARCH_OVERRIDE='i386'" line (line 50) of the script, else it will not function correctly.
(to uncomment, simply remove the hash - #).

Normally there is only one thing you will need to change yourself, and that will be the timezone.
If you are not sure what you should be setting this to then via SSH cd to the /usr/share/zoneinfo
directory, type ls -l and it will list the possible timezones for you.

Any folders that are highlighted in a different colour you can cd into, e.g. for the United Kingdom
you could use either "GB" or "Europe/London" as your timezone.

If you lived in Los Angeles it would be "America/Los_Angeles" and so on.

When you have worked out the correct timezone you would then change the "ZONEINFO" line (line 18) of
the script. So using Los Angeles as the example the line would be changed to: ZONEINFO=America/Los_Angeles

Optionally, you can also change any of the y/n values that specify if you wish for the specific software
to be installed or not.

Also, there is the option to specify which version of Nginx the script downloads and installs (line 33),
it is set by default to the current (at of time of writing) stable version, feel free to change this to the
development version if you wish (e.g. NGINX_VERSION='1.1.x') - check the latest version at http://nginx.org.

Installation/usage:

1) Download the script from http://www.btcentral.org.uk/projects/centmin/
2) Extract the files to a directory of your choice (tar xzvf centmin-latest.tar.gz)
3) Edit the script (as explained in the configuration section above) if needed.
4) Run:
script -f centmin.log
./centmin.sh

5) Follow the onscreen prompts
6) When installation is complete, simply type:
exit

The results of your installation will have been logged to centmin.log, which can be used to debug any errors.

Post-installation:

We have included configuration files for MySQL, Nginx, NSD and PHP-FPM which should generally be fine for use
in any environment (as in, both production and testing). However feel free to edit these if you wish.

By default the script will start any services it installs, including Nginx. So if you browse to your server IP
after installation, you should see our Nginx test page, obviously feel free to replace this.

If you cd to /home/nginx/domains/demo.com you will see that we have setup an example folder structure for you.
Any public content (e.g. html, php etc. files) should go in the public folder, logs will be placed in the logs
folder by Nginx, any private files (e.g. php configuration files etc.) should be put in the private folder
(as it is not accessible by the webserver), backups obviously go in the backups folder.

To get a live domain up and running, simply rename the demo.com folder to whatever your domain is called, then
edit /usr/local/nginx/conf/conf.d/virtual.conf to reflect these changes - for most setups a simple find/replace
with your domain name (without the www.) should be fine.

Also, if you are using NSD an example zone for "demo.com" is included, a find/replace for demo.com with your
domain (without www.), and 192.192.192.192 with your server IP address in /etc/nsd/master/demo.com.zone and
replace demo.com with your domain (without www.) in /etc/nsd/nsd.conf should be enough to get you up and running.

Extras:

In the "Extras" folder you will find the nginx-update.sh and nginx-vhost.sh scripts.

nginx-update can be used to update nginx to the latest version at any time, for ease of use this script is
automatically copied to your /sbin/ folder.

To use when logged in as root simply type: nginx-update
Then enter the version number of the version you wish to update to and answer the yes/no questions.

nginx-vhost can be used to create a new virtual host for nginx, for ease of use this script is automatically
copied to your /sbin/ folder.

To use when logged in as root simply type: nginx-vhost yourdomain.com
Where yourdomain.com is the domain you want to add (without a www. prefix).

~ Enjoy
BTCentral