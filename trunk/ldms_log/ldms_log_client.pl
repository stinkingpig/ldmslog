#############################################################################
# ldms_log_client.pl                                                        #
# (c) 2009 Jack Coates, jack@monkeynoodle.org                               #
# Released under GPL, see http://www.gnu.org/licenses/gpl.html for license  #
# Patches welcome at the above email address, current version available at  #
# http://www.droppedpackets.org/                                            #
#############################################################################

package ldms_log_client;
#############################################################################
# Pragmas and Modules                                                       #
#############################################################################
use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
use warnings;
use Env;
use Cwd;
use File::Basename;
use Getopt::Long;
use Carp;
use ldms_log;

#############################################################################
# Preparation                                                               #
#############################################################################
my $commandline;
for ( 0 .. $#ARGV ) {
    $commandline .= "$ARGV[$_] ";
}

my ( $DEBUG, $help ) = '';
GetOptions(
    '/',
    'debug' => \$DEBUG,
    'help'  => \$help,
);

( my $prog = $0 ) =~ s/^         # command line from the beginning
                       .*[\\\/]  # without any slashes
                       //x;
$VERSION = "1.0.2";

my $usage = <<"EOD";

Usage: $prog [/debug] [/help]
			 
	/d(ebug)	 debug
	/h(elp)		 this display

$prog v $VERSION
Jack Coates, jack\@monkeynoodle.org, released under GPL
This program tails the important logs on your LANDesk client.
The latest version lives at http://www.droppedpackets.org/scripts/ldms_log.

EOD
croak $usage if $help;

# Prepare logging system
$ldms_log::prog    = $prog;
$ldms_log::DEBUG   = $DEBUG;
$ldms_log::ver     = $VERSION;
$ldms_log::logfile = "$prog.log";
&NewLog();

#############################################################################
# Variables                                                                 #
#############################################################################

# Global variables
my ( $RegKey, $FILE );

$ldms_log::timeout = 30;

my $basedir = "C:\\Progra~1";
if ($PROGRAMFILES) {
    $basedir = Win32::GetShortPathName($PROGRAMFILES);
}
my $ldclient = $basedir . "\\LANDesk\\LDClient";
my $ldshared = $basedir . "\\LANDesk\\Shared\ Files";
my $sdcache  = $ldclient . "\\sdmcache";
my $localappdata;
if ($ALLUSERSPROFILE) {
    $localappdata = $ALLUSERSPROFILE . "\\Application\ Data";
}
else {
    $localappdata = Win32::GetFolderPath( CSIDL_COMMON_APPDATA() );
}
$localappdata = Win32::GetShortPathName($localappdata);

#############################################################################
# Main Loop                                                                 #
#############################################################################

# Set up
&LocateFiles;
&SetupTail;
&BuildWindow;

# Put a timer on it
# Causes DoTail to be called every 30 seconds
$ldms_log::Main->AddTimer( 'T1', 30000 );
&DoTail;
Win32::GUI::Dialog();

exit(0);

#############################################################################
# Subroutines                                                               #
#############################################################################

### Select the files we're monitoring ######################################
sub LocateFiles {

    # http://community.landesk.com/support/docs/DOC-5130
    if ( !-e $ldclient ) {
        &LogDie("Can't find $ldclient");
    }

# TODO -- Handle XTRACE files: http://community.landesk.com/support/docs/DOC-1623
    &LocateAutoNamedFiles( "$ldclient\\data",        'sdclient_task(.+).log' );
    &LocateAutoNamedFiles( "$ldclient",              'sdclienttask.(.+).log' );
    &LocateAutoNamedFiles( "$localappdata\\vulscan", 'vulscan.(\d).log' );

    my @Clientlogs = (
        "$ldclient\\amtmon.Log",
        "$ldclient\\sdclient.log",
        "$ldclient\\tmcsvc.log",
        "$ldclient\\policy.cgi.log",
        "$ldclient\\policy.client.portal.log",
        "$ldclient\\policy.client.invoker.log",
        "$ldclient\\policy.sync.log",
        "$ldshared\\residentagent.log",
        "$ldshared\\residentagent.old",
        "$ldshared\\servicehost.log",
        "$ldshared\\servicehost.old",
        "$ldclient\\fwregister.log",
        "$ldshared\\proxyhost.log",
        "$ldclient\\brokerconfig.log",
        "$ldshared\\alert.log",
        "$ldclient\\alertsync.log",
        "$ldclient\\lddetectsystem.log",
        "$ldclient\\createmonitorroot.log",
        "$localappdata\\vulScan\\vulscan.log",
        "$ldclient\\vulscan.log",
        "$localappdata\\vulScan\\softmon.log",
        "$ldclient\\Antivirus\\UpdateVirusDefinitions.log",
        "$ldclient\\Antivirus\\UpdateVirusDefinitions.old",
        "$localappdata\\LANDeskAV\\avservice.log",
        "$localappdata\\LANDeskAV\\avservice_channel.log",
        "$localappdata\\LANDeskAV\\LANDeskAV\\AVScanShExt.log",
        "$localappdata\\LANDeskAV\\LANDeskAV\\LDAV.log",
        "$localappdata\\LANDeskAV\\LANDeskAV\\avservice_update.log",
        "$ldclient\\data\\gatherproducts.log",
        "$ldclient\\ldiscn32.log",
        "$ldclient\\data\ldiscn32.log",
        "$ldclient\\ldiscnupdate.log",
        "$ldclient\\localsch.log",
        "$ldclient\\LDSystemEventCapture.log"
    );

    foreach my $candidate (@Clientlogs) {
        if ( defined($candidate) ) {

            #            $candidate = Win32::GetShortPathName($candidate);
            if ( -e $candidate ) {
                push @ldms_log::logfiles, $candidate;
                if ($DEBUG) {
                    &Log("monitoring $candidate");
                }

            }
            else {
                if ($DEBUG) {
                    &Log("$candidate is not present");
                }
            }
        }
    }
    return 0;
}

1;
__END__


