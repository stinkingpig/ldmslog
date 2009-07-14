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
use Win32::TieRegistry ( Delimiter => "/", ArrayValues => 1 );
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
Getopt::Long::Configure("long_prefix_pattern=(--|\/)", "prefix_pattern=(--|-|\/)");
GetOptions(
    'debug' => \$DEBUG,
    'help'  => \$help,
);

( my $prog = $0 ) =~ s/^         # command line from the beginning
                       .*[\\\/]  # without any slashes
                       //x;
$VERSION = "1.0.6";
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
$ldms_log::prog    = $prog;
$ldms_log::DEBUG   = $DEBUG;
$ldms_log::ver     = $VERSION;
$ldms_log::logfile = "$prog.log";
&NewLog();

#############################################################################
# Variables                                                                 #
#############################################################################

# Global variables
my ( $RegKey, $FILE, $ldmain, $ldlog, $lpmdir, $ldlogon, );

$ldms_log::timeout = 30;

#############################################################################
# Main Loop                                                                 #
#############################################################################

# Set up
&ReadRegistry;
&LocateFiles;
&SetupTail;
&BuildWindow;

# Put a timer on it
# Causes DoTail to be called every 1 seconds
$ldms_log::Main->AddTimer( 'T1', 1000 );
&DoTail;
&ShowTail;
Win32::GUI::Dialog();

exit(0);

#############################################################################
# Subroutines                                                               #
#############################################################################



### Select the files we're monitoring ######################################
sub LocateFiles {

    # http://community.landesk.com/support/docs/DOC-5156
    if ( !-e $ldmain ) {
        &LogDie("Can't find $ldmain");
    }

    # Handle IIS logs
    &LocateAutoNamedFiles( "$WINDIR\\system32\\LogFiles\\W3SVC1", 'ex(\d+).log' );

    # Handle XTrace logs
    &LocateAutoNamedFiles( $ldmain, '(.+).xlg' );

    &LocateAutoNamedFiles( $ldlog, 'scheduledtaskhandler_(\d+).log' );
    &LocateAutoNamedFiles( $ldlog, 'cab_(\d+).log' );
    &LocateAutoNamedFiles( $ldlog, 'cj-(.+).log' );
    &LocateAutoNamedFiles( $ldlog, 'mcc-(.+).log' );
    &LocateAutoNamedFiles( $ldlog, 'mcs-(.+).log' );
    &LocateAutoNamedFiles( "$ldlogon\\advanceagent", '(.+).exe.log' );
    &LocateAutoNamedFiles( $ldmain, 'Rollup_(.+).log' );
    &LocateAutoNamedFiles( $ldmain, 'LDInv32(.+).log' );
    &LocateAutoNamedFiles( "$lpmdir\\TaskEngine", '(.+)Landesk.Workflow.TaskEngine.Internal.log' );

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
        "$ldmain\\UserValidatorErrLog.txt",
        "$ldmain\\LANDeskManagementSuite.Information.log",
        "$ldmain\\dashboardreportservice.exe.log"
    );

    foreach my $candidate (@Corelogs) {
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

### ReadRegisty subroutine #################################################
sub ReadRegistry {

    # Check the registry for LDMAIN
    $RegKey =
      $Registry->{"HKEY_LOCAL_MACHINE/Software/LANDesk/ManagementSuite/Setup"};
    if ($RegKey) {
        $ldmain = &SetValueFromReg("LDMainPath");
        $ldmain = Win32::GetShortPathName($ldmain);
        if ($DEBUG) { &Log("LDMAIN is $ldmain"); }
        $ldlog   = $ldmain . "log";
        $ldlogon = $ldmain . "ldlogon";

    }

    # Check the registry for LPM's home
    $RegKey = $Registry->{"HKEY_LOCAL_MACHINE/Software/LANDesk/Workflow"};
    if ($RegKey) {
        $lpmdir = &SetValueFromReg("InstallPath");
        $lpmdir = Win32::GetShortPathName($lpmdir);
        if ($DEBUG) { &Log("LPMDIR is $lpmdir"); }
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
                &Log("SetValueFromReg, key $keyname was empty.");
            }
            return 0;
        }
    }
    else {
        if ($DEBUG) {
            &Log("SetValueFromReg called without RegKey handle");
        }
        return -1;
    }
}

1;
__END__

