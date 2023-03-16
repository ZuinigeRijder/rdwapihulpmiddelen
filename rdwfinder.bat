@rem = '--*-Perl-*--
@echo off
if "%OS%" == "Windows_NT" goto WinNT
perl -x -S "%0" %1 %2 %3 %4 %5 %6 %7 %8 %9
goto endofperl
:WinNT
perl -x -S %0 %*
if NOT "%COMSPEC%" == "%SystemRoot%\system32\cmd.exe" goto endofperl
if %errorlevel% == 9009 echo You do not have Perl in your PATH.
if errorlevel 1 goto script_failed_so_exit_with_non_zero_val 2>nul
goto endofperl
@rem ';
#!C:\Perl\Bin\perl.exe -w
#line 15
#
# 
#
# Zuinige Rijder
# 
# 
#
#2345678901234567890123456789012345678901234567890123456789012345678901234567890
#===============================================================================
#@description
#
# rdw: Rick's get IONIQ 5 rdw kenteken data
#
#===============================================================================
#use diagnostics;
use strict;
use Carp;
use POSIX qw/strftime/;
use JSON qw( decode_json );     # From CPAN
use Data::Dumper;

$| = 1; # no output buffering

# declaration of subroutine prototypes
sub myDie($);
sub executeCommand($);


my $true=1;
my $false=0;
my $DEBUG=$false;
my $TOGGLE=$true;
my $COUNT=0;

#===============================================================================
# die
# parameter 1: die string
#===============================================================================
sub myDie($) {
    my ($txt) = @_;
    print "\n", "?" x 80, "\n";
    print "Error: $txt\n\n";
    croak("$txt\n\n");
    exit 1;
}

#===============================================================================
# execute command
# parameter 1: command
# parameter 2: redirect
# return errorlevel
#===============================================================================
sub executeCommand($) {
    my ($command) = @_;

    my $try = 5;
    my $rc;
    do {
    if ($try < 5) {
        print "Retry: $try\n";
    }
    $try--;
    $COUNT++;
    #$command = correctSlashes($command);
    # Perl with Nutcracker should have double DOS slashes
    # ActivePerl does not care
    print "Before: $command 2>&1\n" if $DEBUG;
    #$command =~ s?/?\\\\?g;  # change single / into double \\
    #$command =~ s?\\?\\\\?g; # change single \ into double \\
    #$command =~ s?\\\\\\\\?\\\\?g; # change multiple \\ into single \\
    #print "After: $command 2>&1\n" if $DEBUG;
    $rc = 0xffff & system("$command 2>&1");
    if ($rc == 0) {
        # everything Ok
        return 0;
    } elsif ($rc == 0xff00) {
        print "ERROR: Command [$command] failed: $!\n";
    } elsif ($rc > 0x80) {
        $rc >>= 8;
        print "ERROR: Command [$command] exited with non-zero exit status: $rc\n";
    } else {
        print "ERROR: Command [$command] exited with ";
        if ($rc & 0x80) {
            $rc &= ~0x80;
            print "coredump from ";
        }
        print "signal $rc\n";
    }
    } while ($rc != 0 and $try > 0);
    return $rc;
}

if (@ARGV != 5) {
   myDie("Usage: rdwfinder BEGINLETTER ENDLETTERS FROM TO INCREMENT, e.g. rdwfinder R LF 510 560 1");
}
my $BEGINLETTER = $ARGV[0];
my $LETTERS = $ARGV[1];
my $from = $ARGV[2];
my $to = $ARGV[3];
if ($to < $from) {
   my $tmp = $to;
   $to = $from;
   $from = $tmp;
}
my $increment = $ARGV[4];
uc $BEGINLETTER;
uc $LETTERS;

my @results;
my $current = $from;
my $count = 0;
my $start_time = time();
my $BEGIN_TIME = time();
print strftime('%Y-%m-%d %H:%M:%S',localtime);
print "\n";
while ($current <= $to and $current <= 1000 and $current >= 0) {
    my $currentNumber = sprintf("%03s", $current);
    my $kenteken = "$BEGINLETTER$currentNumber" . "$LETTERS";
    $current += $increment;
    print "Getting details of kenteken: $kenteken\n" if $DEBUG;
    my $filename="x.rdwfind.html";
    if (-e $filename) {
        unlink $filename;
    }
    my $cmd = 'curl -X POST -d "__VIEWSTATE=%2FwEPDwUKMTE1NDI3MDEyOQ9kFgJmD2QWAgIDD2QWBAIBD2QWAgIJDxYCHgdWaXNpYmxlaGQCAw9kFgICAw9kFghmD2QWAmYPZBYMZg9kFgICAQ9kFgJmDxQrAAIPFgIeC18hSXRlbUNvdW50AgxkZGQCAQ9kFgICAQ9kFgJmDxQrAAIPFgIfAQIFZGRkAgIPZBYCAgEPZBYCZg8UKwACDxYCHwECB2RkZAIDD2QWAgIBD2QWAmYPFCsAAg8WAh8BAgNkZGQCBA9kFgICAQ9kFgJmDxQrAAIPFgIfAQIFZGRkAgUPZBYCAgEPZBYCZg8UKwACDxYCHwECAWRkZAIBD2QWAmYPZBYGZg9kFgICAQ9kFgJmDxQrAAIPFgIfAQIEZGRkAgEPZBYCAgEPZBYCZg8UKwACDxYCHwECDmRkZAICD2QWAgIBD2QWAmYPFCsAAg8WAh8BAgtkZGQCAg9kFgJmD2QWBGYPZBYCAgEPZBYCZg8UKwACDxYCHwECBmRkZAIBD2QWAgIBD2QWAmYPFCsAAg8WAh8BAgdkZGQCAw9kFgJmD2QWAmYPZBYCAgEPZBYCZg8UKwACDxYCHwECA2RkZBgMBRdjdGwwMCRNYWluQ29udGVudCRjdGwyNg8UKwAOZGRkZGRkZDwrAAYAAgZkZGRmAv%2F%2F%2F%2F8PZAUXY3RsMDAkTWFpbkNvbnRlbnQkY3RsMTQPFCsADmRkZGRkZGQUKwABZAIBZGRkZgL%2F%2F%2F%2F%2FD2QFF2N0bDAwJE1haW5Db250ZW50JGN0bDIwDxQrAA5kZGRkZGRkPCsADgACDmRkZGYC%2F%2F%2F%2F%2Fw9kBRdjdGwwMCRNYWluQ29udGVudCRjdGwwNg8UKwAOZGRkZGRkZDwrAAUAAgVkZGRmAv%2F%2F%2F%2F8PZAUXY3RsMDAkTWFpbkNvbnRlbnQkY3RsMjIPFCsADmRkZGRkZGQ8KwALAAILZGRkZgL%2F%2F%2F%2F%2FD2QFF2N0bDAwJE1haW5Db250ZW50JGN0bDEwDxQrAA5kZGRkZGRkFCsAA2RkZAIDZGRkZgL%2F%2F%2F%2F%2FD2QFF2N0bDAwJE1haW5Db250ZW50JGN0bDMyDxQrAA5kZGRkZGRkFCsAA2RkZAIDZGRkZgL%2F%2F%2F%2F%2FD2QFF2N0bDAwJE1haW5Db250ZW50JGN0bDEyDxQrAA5kZGRkZGRkPCsABQACBWRkZGYC%2F%2F%2F%2F%2Fw9kBRdjdGwwMCRNYWluQ29udGVudCRjdGwwOA8UKwAOZGRkZGRkZDwrAAcAAgdkZGRmAv%2F%2F%2F%2F8PZAUXY3RsMDAkTWFpbkNvbnRlbnQkY3RsMTgPFCsADmRkZGRkZGQ8KwAEAAIEZGRkZgL%2F%2F%2F%2F%2FD2QFF2N0bDAwJE1haW5Db250ZW50JGN0bDA0DxQrAA5kZGRkZGRkPCsADAACDGRkZGYC%2F%2F%2F%2F%2Fw9kBRdjdGwwMCRNYWluQ29udGVudCRjdGwyOA8UKwAOZGRkZGRkZDwrAAcAAgdkZGRmAv%2F%2F%2F%2F8PZNmHhgdEC2dk11hzIudYxHwUwGfK4eXG%2Fo9Cu8qdtlVL&__VIEWSTATEGENERATOR=CA0B0334&__EVENTVALIDATION=%2FwEdAALw6Ljfck63rzOJzJwmCORy851Fq81QBiZgFEttEk2eePY91dYtbp8ZA%2BHq0kU34KFnAvRU3Nv8x3coJguc2YKX&ctl00%24TopContent%24txtKenteken=' . "$kenteken" . '" https://ovi.rdw.nl/default.aspx > x.rdwfind.html';
    #my $cmd = 'curl -X GET https://www.autoweek.nl/kentekencheck/' . "$kenteken" . '/ > ' . $filename;
    print "$count: Checking $kenteken\n";
    executeCommand($cmd);
    
    open(KENTEKENFILE, "$filename") or myDie("Cannot open for read: $filename: $!\n");
    my $match = $false;
    my $matchHyundai = $false;
    while (<KENTEKENFILE>) {
        my $line = "$_";
        chomp $line;
        if ($line =~ 'IONIQ5') {
            print "MATCH IONIQ5: $kenteken\n";
            push @results, $kenteken;
            $match = $true;
            $matchHyundai = $true;
            $count++;
            last;
        } elsif ($line =~ 'HYUNDAI') {
           #print "MATCH HYUNDAI: $kenteken\n" if not $matchHyundai;
           $matchHyundai = $true;
        } elsif ($line =~ 'Het maximaal aantal opvragingen per dag' or $line =~ 'dienst ontzegd') {
           print "$line\n";
           sleep(30);
           $current -= $increment;
        } elsif ($line =~ 'Er zijn geen gegevens gevonden voor het ingevulde kenteken') {
           print "GEEN GEGEVENS: $kenteken\n";
        }
    }
    close(KENTEKENFILE);
    #if ($match) {
    #    rename "$filename", "$filename.match.html" or myDie "Cannot rename file: $!";
    #}
    my $stop_time = time();
    my $diff_time = $stop_time - $start_time;
    $TOGGLE = not $TOGGLE;
    my $wait_time;
    if ($TOGGLE) {
        $wait_time = 3 - $diff_time; # at least wait some seconds
    } else {
        $wait_time = 2 - $diff_time; # at least wait some seconds
    }
    print "Diff: [$diff_time], Wait: [$wait_time]\n" if $DEBUG;
    if ($wait_time > 0) {
        sleep($wait_time);
    }
    $start_time = time();
}

print "\n\nAlle detail resultaten:\n\n";
foreach (sort @results) {
    print "$_\n";
}
print "Totaal aantal IONIQ5: $count\n";
print strftime('%Y-%m-%d %H:%M:%S',localtime);
my $END_TIME = time();
my $ELAPSED_TIME = $END_TIME - $BEGIN_TIME;
print "  Elapsed: [$ELAPSED_TIME]\n";
__END__
:endofperl
