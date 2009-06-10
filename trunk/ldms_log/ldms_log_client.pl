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
use Win32::GUI ();
use Getopt::Long;
use File::Tail;
use File::Basename;

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
$VERSION = "1.0.0";

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
my $logfile = "ldms_log_client.log";
my $LOG;
open( $LOG, '>', $logfile ) or croak("Cannot open $logfile - $!");
print $LOG localtime() . " $prog $VERSION starting.\n";
close($LOG);

#############################################################################
# Variables                                                                 #
#############################################################################

# Global variables
my ( $RegKey, $FILE, $ldmain, $ldlog, $lpmdir, @logfiles, $ldlogon, @files );

my $timeout = 30;

my $basedir = "C:\\Progra~1";
if ($PROGRAMFILES) {
    $basedir = Win32::GetShortPathName($PROGRAMFILES);
}
my $ldclient = $basedir . "\\LANDesk\\LDClient";
my $ldshared = $basedir . "\\LANDesk\\Shared\ Files";
my $sdcache  = $ldclient . "\\sdmcache";
my $localappdata;
if ($ALLUSERSPROFILE) {
    $localappdata = $ALLUSERSPROFILE;
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
while (1) { &DoTail; }

exit(0);

#############################################################################
# Subroutines                                                               #
#############################################################################

### Prepare all these tail handles subroutine ###############################
sub SetupTail {
    foreach (@logfiles) {
        push(
            @files,
            File::Tail->new(
                name               => "$_",
                debug              => $DEBUG,
                ignore_nonexistant => 1,
                tail               => 20,
            )
        );
    }
    return 0;
}

### See what's on Tail subroutine ###########################################
sub DoTail {
    my ( $nfound, $timeleft, @pending ) =
      File::Tail::select( undef, undef, undef, $timeout, @files );
    unless ($nfound) {

        # timeout - do something else here, if you need to
    }
    else {
        foreach (@pending) {
            my $filename = basename( $_->{"input"} );
            &Log( $filename . ": " . $_->read );
        }
    }
    return 0;
}

### Logging subroutine ######################################################
sub Log {
    my $msg = shift;
    if ( !defined($msg) ) { $msg = "Log: Can't report nothing"; }
    open( $LOG, '>>', "$logfile" ) or croak("Can't open $logfile - $!");
    $LOG->autoflush();
    print $LOG localtime() . ": $msg\n";
    close($LOG);
    if ($DEBUG) { print $msg; }
    return 0;
}

### Logging with warning subroutine #########################################
sub LogWarn {
    my $msg = shift;
    if ( !defined($msg) ) { $msg = "LogWarn: Can't report nothing"; }
    open( $LOG, '>>', "$logfile" ) or croak("Can't open $logfile - $!");
    $LOG->autoflush();
    print $LOG localtime() . ": WARN: $msg\n";
    close($LOG);

    Win32::GUI::MessageBox( 0, "$msg", "ldms_log_client", 64 );
    return 0;
}

### Logging with death subroutine ###########################################
sub LogDie {
    my $msg = shift;
    if ( !defined($msg) ) { $msg = "LogDie Can't report nothing"; }
    open( $LOG, '>>', "$logfile" ) or croak("Can't open $logfile - $!");
    $LOG->autoflush();
    print $LOG localtime() . ": DIE: $msg\n";
    close($LOG);
    Win32::GUI::MessageBox( 0, "$msg", "ldms_log_client", 48 );
    exit 1;
}

### Select the files we're monitoring ######################################
sub LocateFiles {

    # http://community.landesk.com/support/docs/DOC-5130
    if ( !-e $ldclient ) {
        &LogDie("Can't find $ldclient");
    }

# TODO -- Handle $ldclient\\data\\sdclient_task#.log
# TODO -- Handle $ldclient\\SDClientTask.[Core-Name].[task#].log
# TODO -- Handle $ldclient\\[MSI Name].log (created during installation of MSI packages)
# TODO -- Handle "$localappdata\\vulScan\\vulscan.#.log (The vulscan log will roll and create a vulscan.1.log, vulscan.2.log, etc)
# TODO -- Handle "$ldclient\\data\\proddefs\\*.xml"

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
                push @logfiles, $candidate;
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


