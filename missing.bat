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
use JSON qw( decode_json );     # From CPAN
use Data::Dumper;
use File::Basename;
use lib dirname (__FILE__);
use rdw_utils;

$| = 1; # no output buffering


fillPrices();

my $filename="missing.txt";
print "Processing $filename\n";
my @KENTEKENS;
my %TENAAMGESTELD;
open(FILE, "$filename") or myDie("Cannot open for read: $filename: $!\n");
my @LINES;
while (<FILE>) {
    my $currentLine = $_;
    chomp $currentLine; # get rid of newline
    $currentLine =~ s? .*??; # get rid of spaces till end of line
    next if $currentLine eq "";
    print "currentLine=[$currentLine]\n" if $DEBUG;
    push (@KENTEKENS, $currentLine);
}
close(FILE);
my $opkenteken = @KENTEKENS;

my @results;
my @errors;
my %TYPES;
my @specialKentekens;
my @newMissing;
open(OUTFILE, ">missing.outfile.txt") or myDie("Cannot open for write: missing.outfile.txt: $!\n");
my $start_time = time();
foreach my $k (@KENTEKENS) {

    $filename="kentekens/x.missing.$k.html";
    my $exists = -e $filename;
    if (@ARGV > 0) {
        print "Forced Skipping: $k\n" if $DEBUG;  
        $exists = $false;
    }
    if ($exists) {
        print "Skipping: $k\n" if $DEBUG;    
        # skip already asked missing kentekens
    }
    if (not $exists) {
        $filename="x.missing";
        print "Getting details of missing kenteken: $k\n";    
        my $cmd = 'curl -s -X POST -d "__VIEWSTATE=%2FwEPDwUKMTE1NDI3MDEyOQ9kFgJmD2QWAgIDD2QWBAIBD2QWAgIJDxYCHgdWaXNpYmxlaGQCAw9kFgICAw9kFghmD2QWAmYPZBYMZg9kFgICAQ9kFgJmDxQrAAIPFgIeC18hSXRlbUNvdW50AgxkZGQCAQ9kFgICAQ9kFgJmDxQrAAIPFgIfAQIFZGRkAgIPZBYCAgEPZBYCZg8UKwACDxYCHwECB2RkZAIDD2QWAgIBD2QWAmYPFCsAAg8WAh8BAgNkZGQCBA9kFgICAQ9kFgJmDxQrAAIPFgIfAQIFZGRkAgUPZBYCAgEPZBYCZg8UKwACDxYCHwECAWRkZAIBD2QWAmYPZBYGZg9kFgICAQ9kFgJmDxQrAAIPFgIfAQIEZGRkAgEPZBYCAgEPZBYCZg8UKwACDxYCHwECDmRkZAICD2QWAgIBD2QWAmYPFCsAAg8WAh8BAgtkZGQCAg9kFgJmD2QWBGYPZBYCAgEPZBYCZg8UKwACDxYCHwECBmRkZAIBD2QWAgIBD2QWAmYPFCsAAg8WAh8BAgdkZGQCAw9kFgJmD2QWAmYPZBYCAgEPZBYCZg8UKwACDxYCHwECA2RkZBgMBRdjdGwwMCRNYWluQ29udGVudCRjdGwyNg8UKwAOZGRkZGRkZDwrAAYAAgZkZGRmAv%2F%2F%2F%2F8PZAUXY3RsMDAkTWFpbkNvbnRlbnQkY3RsMTQPFCsADmRkZGRkZGQUKwABZAIBZGRkZgL%2F%2F%2F%2F%2FD2QFF2N0bDAwJE1haW5Db250ZW50JGN0bDIwDxQrAA5kZGRkZGRkPCsADgACDmRkZGYC%2F%2F%2F%2F%2Fw9kBRdjdGwwMCRNYWluQ29udGVudCRjdGwwNg8UKwAOZGRkZGRkZDwrAAUAAgVkZGRmAv%2F%2F%2F%2F8PZAUXY3RsMDAkTWFpbkNvbnRlbnQkY3RsMjIPFCsADmRkZGRkZGQ8KwALAAILZGRkZgL%2F%2F%2F%2F%2FD2QFF2N0bDAwJE1haW5Db250ZW50JGN0bDEwDxQrAA5kZGRkZGRkFCsAA2RkZAIDZGRkZgL%2F%2F%2F%2F%2FD2QFF2N0bDAwJE1haW5Db250ZW50JGN0bDMyDxQrAA5kZGRkZGRkFCsAA2RkZAIDZGRkZgL%2F%2F%2F%2F%2FD2QFF2N0bDAwJE1haW5Db250ZW50JGN0bDEyDxQrAA5kZGRkZGRkPCsABQACBWRkZGYC%2F%2F%2F%2F%2Fw9kBRdjdGwwMCRNYWluQ29udGVudCRjdGwwOA8UKwAOZGRkZGRkZDwrAAcAAgdkZGRmAv%2F%2F%2F%2F8PZAUXY3RsMDAkTWFpbkNvbnRlbnQkY3RsMTgPFCsADmRkZGRkZGQ8KwAEAAIEZGRkZgL%2F%2F%2F%2F%2FD2QFF2N0bDAwJE1haW5Db250ZW50JGN0bDA0DxQrAA5kZGRkZGRkPCsADAACDGRkZGYC%2F%2F%2F%2F%2Fw9kBRdjdGwwMCRNYWluQ29udGVudCRjdGwyOA8UKwAOZGRkZGRkZDwrAAcAAgdkZGRmAv%2F%2F%2F%2F8PZNmHhgdEC2dk11hzIudYxHwUwGfK4eXG%2Fo9Cu8qdtlVL&__VIEWSTATEGENERATOR=CA0B0334&__EVENTVALIDATION=%2FwEdAALw6Ljfck63rzOJzJwmCORy851Fq81QBiZgFEttEk2eePY91dYtbp8ZA%2BHq0kU34KFnAvRU3Nv8x3coJguc2YKX&ctl00%24TopContent%24txtKenteken=' . "$k" . '" https://ovi.rdw.nl/default.aspx > x.missing';
        executeCommand($cmd);
        my $stop_time = time();
        my $diff_time = $stop_time - $start_time;
        my $wait_time = 3 - $diff_time; # at least wait some seconds
        print "Diff: [$diff_time], Wait: [$wait_time]\n" if $DEBUG;
        if ($wait_time > 0) {
            sleep($wait_time);
        }
        $start_time = time();
    }
    
    my $prijs;
    my $kleur;
    my $uitvoering;
    my $variant;
    my $typegoedkeuring;
    my $AfgDatKent;
    my $DatumGdk = "????????";
    my $EersteToelatingsdatum;
    print("reading=$filename\n") if $DEBUG;
    open(KENTEKENFILE, "$filename") or myDie("Cannot open for read: $filename: $!\n");
    my $OpNaam = "????????";
    while (<KENTEKENFILE>) {
        my $line = "$_";
        chomp $line;
        my $tmp;
        if ($line =~ 'Het maximaal aantal opvragingen per dag' or $line =~ 'dienst ontzegd') {
            print "$line\n";
            next;
        }
        if ($line =~ 'id="CatalogusPrijs"') {
            $tmp = $line;
            $tmp =~ s?.*id="CatalogusPrijs"??;
            $tmp =~ s?\</div\>.*??; 
            $tmp =~ s?\>.* ??;
            print "CatalogusPrijs: $tmp\n" if $DEBUG;
            $prijs = $tmp;
        }
        if ($line =~ 'id="Kleur"') {
            $tmp = $line;
            $tmp =~ s?.*id="Kleur"??;
            $tmp =~ s?\</div\>.*??; 
            $tmp =~ s?\>??;
            print "Kleur: $tmp\n" if $DEBUG;
            $kleur = uc $tmp;
            $kleur = sprintf("%-10s", $kleur);
        }
        if ($line =~ 'id="Uitvoering"') {
            $tmp = $line;
            $tmp =~ s?.*id="Uitvoering"??;
            $tmp =~ s?\</div\>.*??; 
            $tmp =~ s?\>??;
            print "Uitvoering: $tmp\n" if $DEBUG;
            $uitvoering = $tmp;
        }
        if ($line =~ 'id="Variant"') {
            $tmp = $line;
            $tmp =~ s?.*id="Variant"??;
            $tmp =~ s?\</div\>.*??; 
            $tmp =~ s?\>??;
            print "Variant: $tmp\n" if $DEBUG;
            $variant = $tmp;
        }
        if ($line =~ 'id="Typegoedkeuring"') {
            $tmp = $line;
            $tmp =~ s?.*id="Typegoedkeuring"??;
            $tmp =~ s?\</div\>.*??; 
            $tmp =~ s?\>??;
            print "Typegoedkeuring: $tmp\n"  if $DEBUG;
            $typegoedkeuring = $tmp;
        }
        
        if ($line =~ 'id="EersteToelatingsdatum"') {
            $tmp = $line;
            $tmp =~ s?.*id="EersteToelatingsdatum"??;
            $tmp =~ s?\</div\>.*??; 
            $tmp =~ s?\>??;
            print "$filename EersteToelatingsdatum: $tmp\n" if $DEBUG;
            $EersteToelatingsdatum = $tmp;
        }
        if ($line =~ 'id="AfgDatKent"') {
            $tmp = $line;
            $tmp =~ s?.*id="AfgDatKent"??;
            $tmp =~ s?\</div\>.*??; 
            $tmp =~ s?\>??;
            print "$filename AfgDatKent: $tmp\n" if $DEBUG;
            $AfgDatKent = $tmp;
        }
        if ($line =~ 'id="EersteAfgifteNederland"') {
            $tmp = $line;
            $tmp =~ s?.*id="EersteAfgifteNederland"??;
            $tmp =~ s?\</div\>.*??; 
            $tmp =~ s?\>??;
            print "$filename EersteAfgifteNederland: $tmp\n" if $DEBUG;
            $AfgDatKent = $tmp;
        }
        if ($line =~ 'id="DatumAanvangTenaamstelling"') {
            $tmp = $line;
            $tmp =~ s?.*id="DatumAanvangTenaamstelling"??;
            $tmp =~ s?\</div\>.*??; 
            $tmp =~ s?\>??;
            print "$filename DatumAanvangTenaamstelling: $tmp\n" if $DEBUG;
            if ($tmp =~ /Niet geregistreerd/i) {
                $OpNaam = "????????";
            } else {
                print "OpNaam: [$tmp]\n" if $DEBUG;
                $OpNaam = substr($tmp, 6, 4) . substr($tmp, 3, 2) . substr($tmp, 0, 2);
            }
        }
        if ($line =~ 'id="DatumGdk"') {
            $tmp = $line;
            $tmp =~ s?.*id="DatumGdk"??;
            $tmp =~ s?\</div\>.*??; 
            $tmp =~ s?\>??;
            $DatumGdk = "??" . substr($tmp, 8, 2) . substr($tmp, 3, 2) . substr($tmp, 0, 2);
            print "$filename DatumGdk: $DatumGdk\n" if $DEBUG;
        }
    }
    if ($OpNaam eq "????????") {
        $OpNaam = $DatumGdk;
    }
    print "OpNaam: $OpNaam\n" if $DEBUG;
    close(KENTEKENFILE);
    my $type = "$variant;$uitvoering;$typegoedkeuring; prijs: $prijs $kleur";
    my $date20 = $EersteToelatingsdatum;
    if ($date20 eq 'Niet geregistreerd') {
        $date20 = $AfgDatKent;
    }
    if ($date20 eq 'Niet geregistreerd') {
        $date20 = $DatumGdk;
    }
    $date20 =~ s/\?\?/20/; # get rid of ??
    if (substr($date20, 0, 3) != "202") {
        print "Invalid date: $date20 $EersteToelatingsdatum, $AfgDatKent, $DatumGdk\n" if $DEBUG;
        $date20 = substr($date20, 6, 4) . substr($date20, 3,2) . substr($date20, 0,2);
        print "Corrected date: $date20\n" if $DEBUG;
    }
    print "date20=$date20      $EersteToelatingsdatum, $AfgDatKent, $DatumGdk\n" if $DEBUG;
    my $value = getVariant($type, $false, $k, $date20);
    if ($value eq 'ERROR') {
        my $msg = "ERROR: kenteken $k [$type]\n";
        push @errors, $msg;
        print $msg;
        next;
    }
    if (not $exists) {
        $filename="kentekens/x.missing.$k.html";
        rename 'x.missing', $filename or myDie("Cannot rename file: $!");
    }
    $type =~ s?\s*$??; # get rid of spaces at the end
    $type =~ s?;e9\*2018\/858\*11054\*0[134]; prijs: ? Euro?;
    my $new = "$type $value";
    # Kleuren:
    # GEEL  Gravity Gold (Mat)
    # ZWART Phantom Black (Mica Parelmoer)
    # GROEN Digital Teal (Mica Parelmoer), Mystic Olive (Mica)
    # BLAUW Lucid Blue (Mica Parelmoer)
    # GRIJS Shooting Star (Mat), Cyber Grey (Metal.), Galactic Gray (Metal.)
    # WIT   Atlas White (Solid)
    $new =~ s?GEEL ?Gravity Gold   ?;
    $new =~ s?ZWART ?Phantom Black  ?;
    if ($new =~ /GROEN / and $new =~ / \(Olive\)/) {
        $new =~ s? \(Olive\)??;
        $new =~ s?GROEN ?Mystic Olive   ?;
    }
    if ($new =~ /GROEN / and not $new =~ /Olive/) {
        $new =~ s?GROEN ?Digital Teal   ?;
    }
    $new =~ s?GROEN ?GROEN          ?;
    $new =~ s?BLAUW ?Lucid Blue     ?;
    if ($new =~/GRIJS / and $new =~ / \(Shooting Star\)/) {
        $new =~ s? \(Shooting Star\)??;
        $new =~ s?GRIJS ?Shooting Star  ?;
    } 
    $new =~ s?GRIJS ?Cyber/Galactic ?;
    $new =~ s?WIT ?Atlas White    ?;
    
    # get rid of internal information too, not interesting for end user
    $new =~ s?F5E..;E11.11 ??;
    
    my $import = '';
    if ($EersteToelatingsdatum ne "Niet geregistreerd" and $EersteToelatingsdatum ne $AfgDatKent) {
        print "EersteToelatingsdatum = $EersteToelatingsdatum, AfgDatKent = $AfgDatKent\n" if $DEBUG;
        my $yymmdd = substr($EersteToelatingsdatum, 6, 4) . substr($EersteToelatingsdatum, 3, 2) . substr($EersteToelatingsdatum, 0, 2);
        my $yymmddimport = substr($AfgDatKent, 6, 4) . substr($AfgDatKent, 3, 2) . substr($AfgDatKent, 0, 2);
        $import = " ($yymmdd geimporteerd $yymmddimport)";
        $new = $new . $import;
    }
    my $newMissing = "$k $OpNaam $new\n";
    print "$newMissing";
    if (not $exists) {
        push @newMissing, $newMissing;
    }
    print OUTFILE "$k $OpNaam " . $kleur . " $prijs    $variant;$uitvoering;$typegoedkeuring; prijs: $prijs #$import\n";
}
close(OUTFILE);

print "\n\nNieuw gevonden gescande kentekens:\n[code]\n";
my @sorted = sort { (substr($a, 23) cmp substr($b, 23)) or (substr($a, 7) cmp substr($b, 7)) or (substr($a, 0, 1) cmp substr($b, 0, 1)) or (substr($a, 4, 2) cmp substr($b, 4, 2)) or (substr($a, 1) cmp substr($b, 1))} @newMissing;
print @sorted;
print "[/code]\n\n";
print "ERRORS\n";
print @errors;
__END__
:endofperl
