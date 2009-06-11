package ldms_log;

use strict;
use warnings;
use Carp;

BEGIN {
    use Exporter ();
    our ( $VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS );

    # set the version for version checking
    $VERSION = 1.0.0;
    @ISA     = qw(Exporter);
    @EXPORT  = qw(&NewLog &Log &LogWarn &LogDie);
    %EXPORT_TAGS = ();    # eg: TAG => [ qw!name1 name2! ],

    # your exported package globals go here,
    # as well as any optionally exported functions
    @EXPORT_OK = qw($prog $LOG $logfile $DEBUG);
}
our @EXPORT_OK;

# exported package globals go here
our ( $prog, $ver, $LOG, $logfile, $DEBUG );

# non-exported package globals go here

# initialize package globals, first exported ones

# then the others (which are still accessible as $Some::Module::stuff)

# all file-scoped lexicals must be created before
# the functions below that use them.

# file-private lexicals go here

# make all your functions, whether exported or not;
### Create new logfile subroutine ###########################################
sub NewLog {
    if ( !defined($logfile) ) { return 1; }
    open( $LOG, '>', $logfile ) or croak("Cannot open $logfile - $!");
    print $LOG localtime() . " $prog $ver starting.\n";
    close($LOG);
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

    Win32::GUI::MessageBox( 0, "$msg", "ldms_log_core", 64 );
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
    Win32::GUI::MessageBox( 0, "$msg", "ldms_log_core", 48 );
    exit 1;
}

END { }    # module clean-up code here (global destructor)

1;         # don't forget to return a true value from the file

