#############################################################################
# ldms_log_core.pl                                                          #
# (c) 2009 Jack Coates, jack@monkeynoodle.org                               #
# Released under GPL, see http://www.gnu.org/licenses/gpl.html for license  #
# Patches welcome at the above email address, current version available at  #
# http://www.droppedpackets.org/                                            #
#############################################################################

package ldms_log_core;
#############################################################################
# Pragmas and Modules                                                       #
#############################################################################
use strict;
use vars qw($prog $VERSION @ISA @EXPORT @EXPORT_OK);
use warnings;
use Env;
use Cwd;
use Win32::GUI ();
use Win32::TieRegistry ( Delimiter => "/", ArrayValues => 1 );
use Getopt::Long;
use File::Tail;
use File::Basename;
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
    'debug'      => \$DEBUG,
    'help'       => \$help,
);


( my $prog = $0 ) =~ s/^         # command line from the beginning
                       .*[\\\/]  # without any slashes
                       //x;
$VERSION = "1.0.1";
my $usage = <<"EOD";

Usage: $prog [/debug] [/help]
			 
	/d(ebug)	 debug
	/h(elp)		 this display

$prog v $VERSION
Jack Coates, jack\@monkeynoodle.org, released under GPL
This program tails the important logs on your LANDesk core server.
The latest version lives at http://www.droppedpackets.org/scripts/ldms_log.

EOD
croak $usage if $help;

# Prepare logging system
$ldms_log::prog = $prog;
$ldms_log::DEBUG = $DEBUG;
$ldms_log::ver = $VERSION;
my $logfile = "$prog.log";
$ldms_log::logfile = $logfile;
&NewLog();

#############################################################################
# Variables                                                                 #
#############################################################################

# Global variables
my (
    $RegKey,   $FILE,    $ldmain, $ldlog, $lpmdir,
    @logfiles, $ldlogon, @files
);

my $timeout = 30;

#############################################################################
# Main Loop                                                                 #
#############################################################################

# Set up
&ReadRegistry;
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

### Select the files we're monitoring ######################################
sub LocateFiles {

    # http://community.landesk.com/support/docs/DOC-5156
    if ( !-e $ldmain ) {
        &LogDie("Can't find $ldmain");
    }

# TODO -- Handle IIS logs
# TODO -- Handle $ldlog\\scheduledtaskhandler_#.log
# TODO -- Handle $ldlogon\\AdvanceAgent\[Agent Name].exe.log
# TODO -- Handle $ldlog\\CJ-OSD-[SCRIPT NAME].log
# TODO -- Handle $ldlog\\CAB_#.log
# TODO -- Handle $ldmain\\MCC-[xxxxxxxxxxxxxxxxx].log
# TODO -- Handle $ldmain\\MCS-[xxxxxxxxxxxxxxxxx].log
# TODO -- Handle $lpmdir\\TaskEngine\[xxxx]Landesk.Workflow.TaskEngine.Internal.log
# TODO -- Handle $ldmain\\Rollup_[LinkName].log

    my @Corelogs = (
        "$ldmain\\alertdetail.log",
        "$ldmain\\alertname2table.exe.log",
        "$ldmain\\alertrule2xml.exe.log",
        "$ldmain\\alertruleset2table.exe.log",
        "$ldmain\\AlertService.log",
        "$ldmain\\sendemail.log",
        "$ldmain\\AMTDiscService.log",
        "$ldmain\\AMTProvMgr.log",
        "$ldmain\\AMTProv\\AMTProvMgr2.log",
        "$ldmain\\IPMIRedirectionService.log",
        "$ldmain\\AmtSessionMgrSvc.log",
        "$ldmain\\AmtSessionMgr.log",
        "$ldmain\\IpmiRedirectionService.log",
        "$WINDIR\\Temp\\AMTConfigDll.log",
        "$TEMP\\AMTConfigDll.log",
        "$ldmain\\apmservice.exe.log",
        "$ldmain\\apmservice.log",
        "$ldmain\\schedpkgupdate.exe.log",
        "$ldmain\\landesk.scheduler.globalscheduler.exe.log",
        "$ldmain\\landesk.scheduler.globalscheduler.log",
        "$ldmain\\landesk.scheduler.globalscheduler.skeleton.log",
        "$ldmain\\landesk.scheduler.globalscheduler.skeleton.exe.log",
        "$ldmain\\PreferredServerConfig.exe.log",
        "$ldmain\\raxfer.log",
        "$ldmain\\schedqry.exe.log",
        "$ldmain\\schedsvc.exe.log",
        "$ldmain\\schedsvc.log",
        "$lpmdir\\LaunchApp.log",
        "$lpmdir\\DatabaseManager\\DatabaseManager.log",
        "$lpmdir\\TaskEngine\\LANDesk.Workflow.TaskEngine.Internal.log",
        "$lpmdir\\LANDesk.Workflow.TaskEngine.log",
        "$lpmdir\\WorkflowManager\\WorkflowManager.log",
"$lpmdir\\Web\ Services\\LANDesk.Workflow.ServiceHost\\LANDesk.Workflow.ServiceHost.log",
        "$ldlog\\log\\mbsdk.log",
        "$ldmain\\mbsdkalerthandler.exe.log",
        "$ldmain\\prov_schedule.exe.log",
        "$ldlog\\provisioning\\provisioning.log",
        "$ldmain\\custjob.exe.log",
        "$ldlog\\corewebservices.log",
        "$ldmain\\landesk.managementsuite.licensing.activatecore.exe.log",
        "$ldmain\\landesk.managementsuite.licensing.usageservice.exe.log",
        "$ldmain\\landesk.managementsuite.licensing.activationservice.exe.log",
        "$ldmain\\BrokerService.log",
        "$ldmain\\console.exe.log",
        "$ldmain\\console.log",
        "$ldmain\\vaminer.exe.log",
        "$ldlogon\\antivirus\\cab\\cab.log",
        "$ldlogon\\antivirus\\bases\\cab.log",
        "$ldlogon\\spyware\\vulscan.log",
        "$ldmain\\LDInv32.exe.log",
        "$ldmain\\LDInv32.log",
        "$ldmain\\UserValidatorErrLog.txt",
        "$ldmain\\LANDeskManagementSuite.Information.log",
        "$ldmain\\dashboardreportservice.exe.log"
    );

    foreach my $candidate (@Corelogs) {
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

### ReadRegisty subroutine #################################################
sub ReadRegistry {

    # Check the registry for LDMAIN
    $RegKey =
      $Registry->{"HKEY_LOCAL_MACHINE/Software/LANDesk/ManagementSuite/Setup"};
    if ($RegKey) {
        $ldmain = &SetValueFromReg("LDMainPath");
        $ldmain = Win32::GetShortPathName($ldmain);
        if ($DEBUG) { &LogDebug("LDMAIN is $ldmain"); }
        $ldlog   = $ldmain . "log";
        $ldlogon = $ldmain . "logon";

    }

    # Check the registry for LPM's home
    $RegKey = $Registry->{"HKEY_LOCAL_MACHINE/Software/LANDesk/Workflow"};
    if ($RegKey) {
        $lpmdir = &SetValueFromReg("InstallPath");
        $lpmdir = Win32::GetShortPathName($lpmdir);
        if ($DEBUG) { &LogDebug("LPMDIR is $lpmdir"); }
    }

    return 0;
}
### End of ReadRegistry subroutine #########################################

### SetValueFromReg subroutine ##############################################
sub SetValueFromReg {

    # Assuming RegKey handle exists, return with its contents
    if ($RegKey) {
        my $keyname = shift;
        if ( $RegKey->GetValue("$keyname") ) {
            my $output = $RegKey->GetValue("$keyname");
            return $output;
        }
        else {
            if ($DEBUG) {
                &LogDebug("SetValueFromReg, key $keyname was empty.");
            }
            return 0;
        }
    }
    else {
        if ($DEBUG) {
            &LogDebug("SetValueFromReg called without RegKey handle");
        }
        return -1;
    }
}

1;
__END__

