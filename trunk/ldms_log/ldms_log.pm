package ldms_log;

use strict;
use warnings;
use Carp;
use File::Basename;
use File::Tail;
use Win32::GUI ();

BEGIN {
    use Exporter ();
    our ( $VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS );

    # set the version for version checking
    $VERSION = 1.0.3;
    @ISA     = qw(Exporter);
    @EXPORT  = qw(&NewLog &Log &LogWarn &LogDie &SetupTail &DoTail
      &BuildWindow &LocateAutoNamedFiles);
    %EXPORT_TAGS = ();    # eg: TAG => [ qw!name1 name2! ],

    # your exported package globals go here,
    # as well as any optionally exported functions
    @EXPORT_OK = qw($prog $LOG $logfile $DEBUG @files @logfiles $timeout);
}
our @EXPORT_OK;

# exported package globals go here
our ( $prog, $ver, $LOG, $logfile, $DEBUG, @files, @logfiles, $timeout, $Main );
our $ldms_log_icon =
  new Win32::GUI::Icon("red.ico");    # replace default camel icon with my own

our $ldms_log_class =
  new Win32::GUI::Class(  # set up a class to use my icon throughout the program
    -name => "ldms_log Class",
    -icon => $ldms_log_icon,
  );

# non-exported package globals go here
my ( $RegKey, $FILE, $ldmain, $ldlog, $lpmdir, $ldlogon, );
my ( $Wintext, $desk, $dw, $dh, $wx, $wy, $ncw, $nch, $h, $w );

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
    if ($DEBUG) { print "$msg\n"; }
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

### Prepare all these tail handles subroutine ###############################
sub SetupTail {
    foreach (@logfiles) {
        push(
            @files,
            File::Tail->new(
                name               => "$_",
                debug              => $DEBUG,
                ignore_nonexistant => 1,
                tail               => 1,
            )
        );
    }
    return 0;
}

### See what's on Tail subroutine ###########################################
sub DoTail {
    my ( $nfound, $timeleft, @pending ) =
      File::Tail::select( undef, undef, undef, $timeout, @files );
    Win32::GUI::DoEvents();
    unless ($nfound) {
        Win32::GUI::DoEvents();

        # timeout - do something else here, if you need to
        &Log("-- MARK --");
        &Display("-- MARK --\n");
    }
    else {
        foreach (@pending) {
            Win32::GUI::DoEvents();
            my $filename = basename( $_->{"input"} );
            my $message  = $filename . ": " . $_->read;
            Win32::GUI::DoEvents();
            &Log($message);
            &Display($message);
        }
    }
    return 0;
}

### BuildWindow subroutine #################################################
sub BuildWindow {

    $Main = new Win32::GUI::Window(
        -left        => 341,
        -top         => 218,
        -width       => 800,
        -height      => 600,
        -name        => "Main",
        -text        => "$prog $ver",
        -class       => $ldms_log_class,
        -dialogui    => 1,
        -onTerminate => \&Window_Terminate,
        -onResize    => \&Main_Resize,
        -onTimer     => \&T1_Timer,

    );

    $Wintext = $Main->AddRichEdit(
        -text        => "",
        -name        => "Wintext",
        -width       => $Main->Width() - 8,
        -height      => $Main->Height() - 10,
        -vscroll     => 1, 
        -autovscroll => 1,
        -readonly    => 1,
        -multiline   => 1,
        -LimitText   => 2**31 - 1, 
        -AutoURLDetect => 1, 
        -ShowScrollBar => 1, 
    );

    # calculate its size
    $ncw = $Main->Width() - $Main->ScaleWidth();
    $nch = $Main->Height() - $Main->ScaleHeight();
    $w   = $Wintext->Width() + $ncw;
    $h   = $Wintext->Height() + $nch;

    # Don't let it get smaller than it should be
    $Main->Change( -minsize => [ $w, $h ] );

    # calculate its centered position
    # Assume we have the main window size in ($w, $h) as before
    $desk = Win32::GUI::GetDesktopWindow();
    $dw   = Win32::GUI::Width($desk);
    $dh   = Win32::GUI::Height($desk);
    $wx   = ( $dw - $w ) / 2;
    $wy   = ( $dh - $h ) / 2;

    # Resize, position and display
    $Main->Resize( $w, $h );
    $Main->Move( $wx, $wy );

    return 0;
}

### Display in the Window subroutine ########################################
sub Display {
    my $text = shift;
    $Main->Show();
    $Main->BringWindowToTop();
    $Main->Update();
    $Wintext->SetSel(-1, -1);
    $Wintext->ReplaceSel($text);
    $Wintext->Update();
}

### Resize the Main Window ##################################################
sub Main_Resize {
    $Wintext->Resize( $Main->Width() - 8, $Main->Height() - 10);
    return 0;
}

### Universal Window Termination ############################################
sub Window_Terminate {
    return -1;
}

### Window timer ############################################################
sub T1_Timer {
    &DoTail;
}

### Locate auto-named log files #############################################
sub LocateAutoNamedFiles {
    my ( $dir, $pattern ) = @_;
    if ( !-e $dir ) {
        &LogWarn("Directory $dir doesn't exist");
        return 1;
    }
    my $regex = eval { qr/$pattern/i };
    &LogDie("Invalid pattern $pattern specified: $@") if $@;
    my $timefloor = eval(time() - 86400);
    my $DIR;
    opendir( $DIR, "$dir" ) or &LogDie("Can't open $dir - $!");
    while ( my $candidate = readdir($DIR) ) {

        # Next file if we're at the top
        next if $candidate =~ /^       # from the beginning of the line
                            \.\.?   # two dots then anything
                            $       # to the end of the line
                            /x;

        if ( $candidate =~ m/$regex/ ) {

            # stat, 7 is SIZE, 8 is ATIME, 9 is MTIME, 10 is CTIME
            my $mtime = ( stat($dir . "\\" .$candidate) )[9]
              or &LogWarn("stat($candidate) failed: $!");
            if ( $mtime > $timefloor ) {
                if ($DEBUG) {
                    &Log("monitoring $candidate");
                }
                push @ldms_log::logfiles, $candidate;
            }
            else {
                if ($DEBUG) {
                    &Log("skipping $candidate");
                }
            }
        }
    }
    closedir($DIR);
    return 0;
}
END { }    # module clean-up code here (global destructor)

1;         # don't forget to return a true value from the file

