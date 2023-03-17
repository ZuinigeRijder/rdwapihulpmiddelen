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
use File::Copy;
use File::Basename;
use lib dirname (__FILE__);
use rdw_utils;

$| = 1; # no output buffering

my $SUMMARY = $false;
my $OVERVIEW = $false;
my $UPDATE = $false;
if (@ARGV == 1) {
    if ($ARGV[0] =~ /SUMMARY/i) {
       $SUMMARY = $true;
    } elsif ($ARGV[0] =~ /OVERVIEW/i) {
       $OVERVIEW = $true;
    } elsif ($ARGV[0] =~ /UPDATE/i) {
       $UPDATE = $true;
    } else {
       myDie("Usage: rdw [SUMMARY|OVERVIEW|UPDATE]\n");
    }
} elsif (@ARGV != 0) {
    myDie("Invalid number of arguments: Usage: rdw [SUMMARY|OVERVIEW]\n");
}

fillPrices();

my $filename="x.kentekens";
my $cmd;
if (not $SUMMARY and not $OVERVIEW) {
    print "Getting IONIQ5 kentekens\n";
    if (-e $filename) {
        unlink $filename;
    }

    $cmd = 'wget --quiet --output-document=x.kentekens "https://opendata.rdw.nl/api/id/m9d7-ebf2.json?$select=kenteken&$order=`:id`+ASC&$limit=5000&$offset=0&$where=(%60handelsbenaming%60%20%3D%20%27IONIQ5%27)&$$read_from_nbe=true&$$version=2.1"';
    executeCommand($cmd);
    print "Processing IONIQ5 kentekens\n";
}

my @KENTEKENS;
my %KENTEKENS;
my %TENAAMGESTELD;
open(FILE, "$filename") or myDie("Cannot open for read: $filename: $!\n");
while (<FILE>) {
    my $currentLine = $_;
    chomp $currentLine; # get rid of newline
    $currentLine =~ s?^.*"kenteken":"??;
    $currentLine =~ s?"\}??;
    $currentLine =~ s?\]??;
    push (@KENTEKENS, $currentLine);
    print("Adding kentekens dict: [$currentLine]\n") if $DEBUG;
    $KENTEKENS{$currentLine} = 1;
}
close(FILE);

my $opkenteken = @KENTEKENS;

# also add exported known kentekens, if not in list
my %KENTEKENSEXPORTED;
if (not $UPDATE) {
    my $fileexport = "exported.txt";
    open(FILEEXPORT, "$fileexport") or myDie("Cannot open for read: $fileexport: $!\n");
    while (<FILEEXPORT>) {
        my $currentLine = $_;
        chomp $currentLine; # get rid of newline
        if (not exists $KENTEKENS{$currentLine}) {
            print "Adding exported: [$currentLine]\n" if $DEBUG;
            push (@KENTEKENS, $currentLine);
            $KENTEKENS{$currentLine} = 1;
        }
        $KENTEKENSEXPORTED{$currentLine} = 1;
    }
    close(FILEEXPORT);
}

my @sortedKentekens = sort @KENTEKENS;

my $opkentekenzonderexport = 0;

my $registered = '';

my %MISSINGTXT;
my $rewriteMISSINGTXT = $false;
open(MISSINGTXTFILE, "missing.txt") or myDie("Cannot open for read: missing.txt: $!\n");
foreach (<MISSINGTXTFILE>) {
    my $m = $_;
    chomp $m;
    my $k = substr($m, 0, 6);
    chomp $k;
    next if $k eq '';
    print("Adding missing: [$k]\n") if $DEBUG;
    $MISSINGTXT{$k} = $m;
}
close(MISSINGTXTFILE);

my %MISSING;
open(MISSINGFILE, "missing.outfile.txt") or myDie("Cannot open for read: missing.outfile.txt: $!\n");
foreach (<MISSINGFILE>) {
    my $m = $_;
    chomp $m;
    my $k = substr($m, 0, 6);
    $MISSING{$k} = $m;
    
    my $c = substr($m, 16, 10);
    uc $c;
    chomp $c;
    my $add = substr($k, 0, 1) . substr($k, 4, 2) . "$k          " . $c;
    print "Adding registered: [$add]\n" if $DEBUG;
    $registered =  "$registered$add\n";
}
close(MISSINGFILE);

my %TYPES;
my @specialKentekens;
my @gekendOpNaam;
my @nieuwOpNaam;
my $geimporteerd = 0;
foreach my $k (@sortedKentekens) {
    $filename="kentekens/x.$k";
    my $gekendOpNaam = $false;
    my $nieuwOpNaam = $false;
    if ($UPDATE) {
        $cmd = 'wget --quiet --output-document=' . $filename . ' "https://opendata.rdw.nl/api/id/m9d7-ebf2.json?$select=*&$order=`:id`+ASC&$limit=17&$offset=0&$where=(%60kenteken%60%20%3D%20%27' . $k . '%27)&$$read_from_nbe=true&$$version=2.1"';
        executeCommand($cmd);
    } elsif (-e $filename) {
        print "Already exists: Skipping: $filename\n" if $DEBUG;
        if (exists $MISSINGTXT{$k}) {
            print "Deleting from missing.txt: [$k]\n" if $DEBUG;
            delete $MISSINGTXT{$k};
            $rewriteMISSINGTXT = $true;
        }
        if (-e "kentekens/x.missing.$k.html") {
            print "Removing: kentekens/x.missing.$k.html\n";
            unlink "kentekens/x.missing.$k.html";
        }
    } else {
        if (exists $MISSING{$k}) {
            $gekendOpNaam = $true;
            print "$k (gekend kenteken op naam gezet)\n";
        } else {
            $nieuwOpNaam = $true;
            print "$k (nieuw kenteken op naam gezet)\n";
        }
        $cmd = 'wget --quiet --output-document=' . $filename . ' "https://opendata.rdw.nl/api/id/m9d7-ebf2.json?$select=*&$order=`:id`+ASC&$limit=17&$offset=0&$where=(%60kenteken%60%20%3D%20%27' . $k . '%27)&$$read_from_nbe=true&$$version=2.1"';
        executeCommand($cmd);
    }
    
    print "Processing: $filename\n" if $DEBUG;
    open(KENTEKENFILE, "$filename") or myDie("Cannot open for read: $filename: $!\n");
    my $json_text = <KENTEKENFILE>;
    chomp $json_text; # get rid of newline
    close(KENTEKENFILE);
    $TENAAMGESTELD{$k}=1;
    my $fromJSON = decode_json $json_text;
    print "Dump of fromJSON:" . Dumper($fromJSON) if $DUMP;
    my @array = @{ $fromJSON };
    my $hash = $array[0];
    
    $taxi = ${$hash}{'taxi_indicator'};
    if ($taxi eq 'Ja') {
        $COUNTTaxi++;
    }
    
    $export = ${$hash}{'export_indicator'};
    if ($export eq 'Ja') {
        $COUNTExport++;
        if (not exists $KENTEKENSEXPORTED{$k}) {
            $KENTEKENSEXPORTED{$k} = 1;
        }
    } else {
        $opkentekenzonderexport++;
    }
    
    my $kenteken = ${$hash}{'kenteken'};
    if (length($kenteken) != 6) {
        move($filename, "$filename.fout");
        myDie("Kenteken lengte fout: [$filename],[$kenteken]\n");
    }
    my $date = ${$hash}{'datum_eerste_afgifte_nederland'};
    if ($date eq '') {
        $date = ${$hash}{'datum_eerste_tenaamstelling_in_nederland'}; # changed name 31 maart 2022
    }
    my $dateBPM = ${$hash}{'registratie_datum_goedkeuring_afschrijvingsmoment_bpm_dt'};
    if ($dateBPM ne '') {
        if (length($dateBPM) == 23 and substr($dateBPM, 0, 2) eq '20') {
            $dateBPM = substr($dateBPM, 0, 4) . substr($dateBPM, 5, 2) . substr($dateBPM, 8, 2);
            if ($date eq $dateBPM) {
                $dateBPM = '';
            } else {
                print "$k dateBPM: [$dateBPM]\n" if $DEBUG;
            }

        } else {
            print "WARNING: $k dateBPM: [$dateBPM]\n";# if $DEBUG
        }
    }

    if ($date eq '' and $dateBPM ne '') {
       $date = $dateBPM;
       print("date overruled with $dateBPM: [$filename],[$date]\n");
    }
    if (length($date) != 8) {
        myDie("Date lengte fout: [$filename],[$date]\n");
    }
    my $dateToelating = ${$hash}{'datum_eerste_toelating'};
    if ($dateToelating eq '') {
        $dateToelating = $date;
        print("datetoelating overruled with $date: [$filename],[$date]\n");
    }
    if (length($dateToelating) != 8) {
        myDie("Datetoelating lengte fout: [$filename],[$dateToelating]\n");
    }
    if ($date ne $dateToelating) {
        print "Import $k: [$dateToelating] [$date]\n" if $DEBUG;
        $geimporteerd++;
    }
    
    my $kleur = ${$hash}{'eerste_kleur'};
    if ($kleur eq '') {
        myDie("Kleur leeg: [$filename],[$kleur]\n");
    }
    if ($kleur ne 'GROEN' and $kleur ne 'WIT' and $kleur ne 'ZWART' and $kleur ne 'GEEL' and $kleur ne 'GRIJS' and $kleur ne 'BLAUW' and $kleur ne 'BRUIN') { # BRUIN???
        myDie("Kleur onbekend: [$filename],[$kleur]\n");
    }
    $kleur = sprintf("%-10s", $kleur);
    
    my $prijs = ${$hash}{'catalogusprijs'};
    if ($prijs eq '' and $kenteken ne 'R296FL') {
        myDie("Prijs leeg: [$filename],[$prijs]\n");
    }
    if (length($prijs) != 5 and $kenteken ne 'N770TS' and $kenteken ne 'R296FL' and $kenteken ne 'R303XF') {
        myDie("Prijs verkeerd: [$filename],[$prijs]\n");
    }
    
    my $variant = ${$hash}{'variant'};
    my $uitvoering = ${$hash}{'uitvoering'};
    my $typegoedkeuring = ${$hash}{'typegoedkeuringsnummer'};
    if ($kenteken eq 'N331SH') {
        $variant = 'F5E14';
        $uitvoering = 'E11B11';
        $typegoedkeuring = 'e9*2018/858*11054*01';
    } elsif ($kenteken eq 'P085GJ') {
        $variant = 'F5E14';
        $uitvoering = 'E11B11';
        $typegoedkeuring = 'e9*2018/858*11054*01';
    } elsif ($kenteken eq 'N688DR') {
        $variant = 'F5E32';
        $uitvoering = 'E11B11';
        $typegoedkeuring = 'e9*2018/858*11054*01';
    } elsif ($kenteken eq 'P380DR') {
        $variant = 'F5E14';
    } elsif ($kenteken eq 'N770TS') {
        $prijs = 72300;
    } elsif ($kenteken eq 'R296FL') {
        $variant = 'F5E32';
        $uitvoering = 'E11B11';
        $typegoedkeuring = 'e9*2018/858*11054*01';
        $prijs = 55600;
     } elsif ($kenteken eq 'R303XF') { # geen Lounge maar Techniq uitvoering
        $variant = 'F5E42';
        $uitvoering = 'E11A11';
        $typegoedkeuring = 'e9*2018/858*11054*01';
        $prijs = 52426;
     } elsif ($kenteken eq 'R818ZL') { # geen Lounge maar Techniq uitvoering
        $variant = 'F5E42';
        $uitvoering = 'E11A11';
        $typegoedkeuring = 'e9*2018/858*11054*01';
     }
    
    
    if ($variant eq '') {
        myDie("Variant leeg: [$filename],[$variant]\n");
    }
    if ($variant ne 'F5E14' and $variant ne 'F5E32' and $variant ne 'F5P41' and $variant ne 'F5E42' and $variant ne 'F5E54' and $variant ne 'F5E62' and $variant ne 'F5E24') {
        myDie("Variant verkeerd $kenteken: [$filename],[$variant]\n");
    }
    
    if ($uitvoering eq '') {
        myDie("Uitvoering leeg: [$filename],[$uitvoering]\n");
    }
    if ($uitvoering ne 'E11A11' and $uitvoering ne 'E11B11') {
        myDie("Uitvoering onbekend: [$filename],[$uitvoering]\n");
    }
    
    if ($typegoedkeuring eq '') {
        myDie("Typegoedkeuring leeg: [$filename],[$typegoedkeuring]\n");
    }
    if ($typegoedkeuring ne 'e9*2018/858*11054*01' and $typegoedkeuring ne 'e9*2018/858*11054*03' and $typegoedkeuring ne 'e9*2018/858*11054*04') {
        myDie("Typegoedkeuring verkeerd: [$filename],[$typegoedkeuring]\n");
    }
    
    my $type = "$variant;$uitvoering;$typegoedkeuring; prijs: $prijs $kleur";
    my $date20 = $dateToelating;
    $date20 =~ s/\?\?/20/; # nog niet op naam date can start with ??
    if ($dateBPM ne '' and $dateBPM < $dateToelating) {
        $date20 = $dateBPM;
        print "Overruled $kenteken met dateBPM: dateToelating: $dateToelating with dateBPM $dateBPM\n" if $DEBUG;
    }
    $date20 =~ s/\?\?/20/; # nog niet op naam date can start with ??
    if (substr($date20, 0, 3) != "202") {
        print "Invalid toelating date: $date20\n";
        $date20 = substr($date20, 6, 4) . substr($date20, 3,2) . substr($date20, 0,2);
        print "Corrected toalating date: $date20";
    }
    
    if ($DEBUG and $kenteken eq 'R059VH') {
        print "$kenteken, date: $date, datetoelating: $dateToelating, date20: $date20, dateBPM: $dateBPM\n";
    }
    my $value = getVariant($type, $true, $k, $date20); 
    
    if ($value eq 'ERROR') {
        if (-e $filename) {
            unlink $filename;
        }
        next;
    }
    $type = $type . $value;
    if ($date ne $dateToelating) {
        $type .= " ($dateToelating geimporteerd $date)";
    } elsif ($dateBPM ne '' ) {
        $type .= " (aanvraag kenteken $dateBPM)";
    }
    $TYPES{$type} = 1;
    my $specialKenteken = substr($kenteken, 0, 1) . substr ($kenteken, 4, 2) . $kenteken . " " . $date . " " . $kleur . " $prijs    $type";
    print "$specialKenteken\n" if $DEBUG;
    my $tmp = getPrintLine($specialKenteken);
    if ($gekendOpNaam) {
        print "Gekend kenteken op naam gezet:\n";
        #my $tmp = substr($specialKenteken, 3, 16) . substr($specialKenteken, 39);
        #$tmp =~ s?;e9\*2018\/858\*11054\*0[134]; prijs: ? Euro?;
        #print "$tmp\n";
        push @gekendOpNaam, "$tmp\n";
    }
    if ($nieuwOpNaam) {
        #my $tmp = substr($specialKenteken, 3, 16) . substr($specialKenteken, 39);
        #$tmp =~ s?;e9\*2018\/858\*11054\*0[134]; prijs: ? Euro?;
        #print "$tmp\n";
        print "Nieuw kenteken op naam gezet: $tmp\n";
        push @nieuwOpNaam, "$tmp\n";
    }
    push @specialKentekens, $specialKenteken;
}

if (not $UPDATE) {
    open(EXPORTEDTXTFILE, ">exported.txt") or myDie("Cannot open for write: exported.txt: $!\n");
    foreach my $keytxt (sort keys %KENTEKENSEXPORTED) {
        print EXPORTEDTXTFILE "$keytxt\n";
    }
    close(EXPORTEDTXTFILE);
}


open(MISSINGTXTFILE, ">missing.txt") or myDie("Cannot open for write: missing.txt: $!\n");
foreach my $keytxt (sort keys %MISSINGTXT) {
    print MISSINGTXTFILE "$keytxt\n";
}
close(MISSINGTXTFILE);

foreach (<MISSINGTXTFILE>) {
    my $m = $_;
    chomp $m;
    my $k = substr($m, 0, 6);
    chomp $k;
    next if $k eq '';
    $MISSINGTXT{$k} = $m;
}

my $importnietopnaam = 0;
print "REGISTERED: $registered\n" if $DEBUG;
foreach my $item (split /\n/, $registered) {
    my $line = $item;
    chomp $line;
    next if $line eq '';
    print "Checking registered: $line\n" if $DEBUG;
    my $check = substr($line, 3, 6);
    if (exists $TENAAMGESTELD{$check}) {
        print "Already exist: $check\n" if $DEBUG;
        next;
    }
    if (exists $MISSING{$check}) {
        my $m = $MISSING{$check};
        print "Missing: $m\n" if $DEBUG;
        my $comment = $m;
        $comment =~ s?.*#??;
        if ($comment ne '') {
            $importnietopnaam++;
        }
        $m =~ s?\s*#.*??; # remove comment
        my $type = substr($m, 36) . ' ' . substr($m, 16, 10);
        print "Type: [$type]\n" if $DEBUG;
        if (not($type =~ /^F5E14/) and not($type =~ /^F5E32/) and not($type =~ /^F5P41/) and not ($type =~ /^F5E42/) and not ($type =~ /^F5E54/) and not ($type =~ /^F5E62/)) {
            if ($type =~ /^F5E24/) {
                print "Info: unknown type: [$m][$type]\n";
            } else {
                print "Type wrong: [$m][$type]\n";
            }
        }
        my $date20 = substr($m, 7, 8);
        $date20 =~ s/\?\?/20/; # nog niet op naam date can start with ??
        if (substr($date20, 0, 3) != "202") {
            print "Invalid date: $date20\n";
            $date20 = substr($date20, 6, 4) . substr($date20, 3,2) . substr($date20, 0,2);
            print "Corrected date: $date20";
        }
        my $value = getVariant($type, $false, $check, $date20); 
        $type = $type . $value;
        $TYPES{$type} = 1;
        my $tmpSpecial = substr($m, 0, 1) . substr($m, 4, 2) . "$m" . ' ' . substr($m, 16, 10) . $value . $comment;
        print "tmpSpecial = [$tmpSpecial]\n" if $DEBUG;
        push @specialKentekens, $tmpSpecial;
    } else {
        print "Adding special: [$line]\n";
        push @specialKentekens, $line;
    }
}

if (not $OVERVIEW and not $SUMMARY) {
    print "\n\n" . '[h1]Kentekens gesorteerd met tenaamstelling datum, prijs, kleur, uitvoering[/h1]' . "\n";
    print '[code]' . "\n";
}

# totals kleuren en andere statistieken
my $count = 0;
my %COLORS;
my %DATES;

# statistics
my $LONGRANGEBATTERY = 0;
my $RWD = 0;
my $V2L = 0;
my $WP = 0;
my $PANORAMADAK = 0;
my $SOLARDAK = 0;

my $PROJECT45 = 0;
my $LOUNGE = 0;
my $CONNECTPLUS = 0;
my $CONNECT = 0;
my $STYLE = 0;

my $MODEL2022 = 0;
my $MODEL2022_5 = 0;
my $MODEL2023 = 0;

foreach my $k (sort @specialKentekens) {
    $count++;
    my $printLine = getPrintLine($k);
    print "$printLine\n" if not $OVERVIEW and not $SUMMARY;
    if (not $printLine =~ /AWD/i and not $printLine =~ /PROJECT45/i) {
        $RWD++;
    }
    if ($printLine =~ /Model 2023/i) {
        $MODEL2023++;
    } elsif ($printLine =~ /Model 2022\.5/i) {
        $MODEL2022_5++;
    } else {
        $MODEL2022++;
    }
    
    if (not $printLine =~ /58 kWh/i) {
        $LONGRANGEBATTERY++;
    }
    if ($printLine =~ /V2L/i or $printLine =~ /PROJECT45/i or $printLine =~ /Lounge/i or $printLine =~ /Connect/i) {
        $V2L++;
    }
    if ($printLine =~ /WP/i or $printLine =~ /PROJECT45/i or $printLine =~ /Lounge/i or $printLine =~ /Connect\+/i) {
        $WP++;
    }
    if ($printLine =~ /Panoramadak/i and not ($printLine =~ /Olive/i)) {
        $PANORAMADAK++;
    }
    if ($printLine =~ /Zonnepanelen/i) {
        $SOLARDAK++;
    }
    if ($printLine =~ /PROJECT45/i) {
        $SOLARDAK++;
        $PROJECT45++;
    } elsif ($printLine =~ /LOUNGE/i) {
        $LOUNGE++;
    } elsif ($printLine =~ /CONNECT\+/i) {
        $CONNECTPLUS++;
    } elsif ($printLine =~ /CONNECT/i) {
        $CONNECT++;
    } elsif ($printLine =~ /STYLE/i) {
        $STYLE++;
    } else {
        print "ERROR: Model niet gevonden: [$printLine]\n";
    }
    
    my $date = substr($k, 10, 6);
    if ($date =~ /^2/) {
        if (exists $DATES{$date}) {
            $DATES{$date} = $DATES{$date} + 1;
        } else {
            $DATES{$date} = 1;
        }
    }
    my $color = substr($k, 19, 10);
    $color =~ s? *$??;
    print "KLEUR=[$color]\n" if $DEBUG;
    if (exists $COLORS{$color}) {
        $COLORS{$color} = $COLORS{$color} + 1;
    } else {
        $COLORS{$color} = 1;
    }
}
print '[/code]' . "\n\n" if not $OVERVIEW and not $SUMMARY;

if ($OVERVIEW) {
    print "\n\n" . '[h1]Kentekens gesorteerd op kleur/uitvoering/datum[/h1]' . "\n";
    print '[code]' . "\n";
    my @OPALL;
    foreach my $k (sort @specialKentekens) {
        my $printLine = getPrintLine($k);
        push @OPALL, $printLine;
    }
    my @sortedAll = sort { (substr($a, 23) cmp substr($b, 23)) or (substr($a, 7) cmp substr($b, 7)) or (substr($a, 0, 1) cmp substr($b, 0, 1)) or (substr($a, 4, 2) cmp substr($b, 4, 2)) or (substr($a, 1) cmp substr($b, 1))} @OPALL;
    foreach my $s (@sortedAll) {
        print "$s\n"
    }
    print '[/code]' . "\n\n";
    
    print "\n\n" . '[h1]Taxi\'s gesorteerd op kleur/uitvoering/datum[/h1]' . "\n";
    print '[code]' . "\n";
    my @OPTAXI;
    foreach my $k (sort @specialKentekens) {
        my $printLine = getPrintLine($k);
        if ($printLine =~ /\(Taxi\)/) {
            push @OPTAXI, $printLine;
        }
    }
    my @sortedTaxi = sort { (substr($a, 23) cmp substr($b, 23)) or (substr($a, 7) cmp substr($b, 7)) or (substr($a, 0, 1) cmp substr($b, 0, 1)) or (substr($a, 4, 2) cmp substr($b, 4, 2)) or (substr($a, 1) cmp substr($b, 1))} @OPTAXI;
    foreach my $s (@sortedTaxi) {
        print "$s\n";
    }
    print '[/code]' . "\n\n";
    
    print "\n\n" . '[h1]geexporteerd gesorteerd op kleur/uitvoering/datum[/h1]' . "\n";
    print '[code]' . "\n";
    my @OPEXPORT;
    foreach my $k (sort @specialKentekens) {
        my $printLine = getPrintLine($k);
        if ($printLine =~ /\(geexporteerd\)/) {
            push @OPEXPORT, $printLine;
        }
    }
    my @sortedExport = sort { (substr($a, 23) cmp substr($b, 23)) or (substr($a, 7) cmp substr($b, 7)) or (substr($a, 0, 1) cmp substr($b, 0, 1)) or (substr($a, 4, 2) cmp substr($b, 4, 2)) or (substr($a, 1) cmp substr($b, 1))} @OPEXPORT;
    foreach my $s (@sortedExport) {
        print "$s\n";
    }
    print '[/code]' . "\n\n";
}

my %MONTHS;
$MONTHS{'01'} = 'januari';
$MONTHS{'02'} = 'februari';
$MONTHS{'03'} = 'maart';
$MONTHS{'04'} = 'april';
$MONTHS{'05'} = 'mei';
$MONTHS{'06'} = 'juni';
$MONTHS{'07'} = 'juli';
$MONTHS{'08'} = 'augustus';
$MONTHS{'09'} = 'september';
$MONTHS{'10'} = 'oktober';
$MONTHS{'11'} = 'november';
$MONTHS{'12'} = 'december';

# overview of kentekens per month
foreach my $key (sort keys %DATES) {
    my $jaar = substr($key, 0, 4);
    my $maand = substr($key, 4, 2);
    if ($OVERVIEW) {
        next;
    }
    if (not $SUMMARY) {
        print "Skipping maand: $maand in mode without parameters\n";
        next;
    }
    #if ($jaar <= 2021 or $maand <= 1) { # do not give overviews after this month
    #    print "Skipping maand: $maand\n";
    #    next;
    #}
    my $maandstring = $MONTHS{$maand};
    print "\n\n" . "[h1]Kentekens op naam in $maandstring $jaar, kleur/uitvoering[/h1]\n";
    print '[code]' . "\n";
    my @OPNAAM;
    foreach my $k (sort @specialKentekens) {
        my $printLine = getPrintLine($k);
        my $date = substr($k, 10, 6);
        if ($date eq $key) {
            print "$printLine\n" if $DEBUG;
            push @OPNAAM, $printLine;
        }
    }
    my @sortedOPNAAM = sort { substr($a, 23) cmp substr($b, 23) } @OPNAAM;
    foreach my $s (@sortedOPNAAM) {
        print "$s\n"
    }
    print '[/code]' . "\n\n";
}
print "\n";

my $countNogNietOpNaam  = 0;
my @NOGNIETOPNAAM;
foreach my $k (sort @specialKentekens) {
    my $printLine = getPrintLine($k);
    my $date = substr($k, 10, 6);
    if (not ($date =~ /^2/)) {
        $countNogNietOpNaam++;
        print "$printLine\n" if $DEBUG;
        $printLine =~ s/ \?\?/ 20/;
        push @NOGNIETOPNAAM, $printLine;
    }
}    
if (not $OVERVIEW and not $SUMMARY) {
    #N445FT ???????? E48395 D
    #012345678901234567890123
    my @sortedNOGNIETOPNAAM = sort { substr($a, 23) cmp substr($b, 23) } @NOGNIETOPNAAM;
    print "\n\n" . '[h1]Kentekens nog niet op naam gesorteerd op kleur/uitvoering (datum is registratiedatum)[/h1]' . "\n";
    print '[code]' . "\n";
    foreach my $s (@sortedNOGNIETOPNAAM) {
        print "$s\n"
    }
    print '[/code]' . "\n\n";
}

if (@gekendOpNaam > 0) {
    print "Eerder gevonden kenteken op naam gezet:\n[code]\n";
    my @sortedGekendOpNaam = sort { (substr($a, 23) cmp substr($b, 23)) or (substr($a, 7) cmp substr($b, 7)) or (substr($a, 0, 1) cmp substr($b, 0, 1)) or (substr($a, 4, 2) cmp substr($b, 4, 2)) or (substr($a, 1) cmp substr($b, 1))} @gekendOpNaam;
    print @sortedGekendOpNaam;
    print "[/code]\n\n";
}
if (@nieuwOpNaam > 0) {
    print "Nieuw kenteken op naam gezet:\n[code]\n";
    my @sortedNieuwOpNaam = sort { (substr($a, 23) cmp substr($b, 23)) or (substr($a, 7) cmp substr($b, 7)) or (substr($a, 0, 1) cmp substr($b, 0, 1)) or (substr($a, 4, 2) cmp substr($b, 4, 2)) or (substr($a, 1) cmp substr($b, 1))} @nieuwOpNaam;
    print @sortedNieuwOpNaam;
    print "[/code]\n\n";
}

print "Totaal aantal IONIQ5 op (ooit) gekend kenteken: $count\n";

if ($countNogNietOpNaam > 0) {
    print "Kenteken op naam RDW API: $opkenteken, zonder geexporteerd: $opkentekenzonderexport, $geimporteerd geimporteerd en $COUNTExport geexporteerd\n"; 
    print '[url=' . "https://gathering.tweakers.net/forum/list_message/69802884#69802884" . ']' . "Kenteken nog niet op naam: $countNogNietOpNaam" . '[/url]'. ", waarvan $importnietopnaam geimporteerd" . "\n\n"; 
}

my $pMODEL2022 = $MODEL2022 / $count * 100;
my $pMODEL2022_5 = $MODEL2022_5 / $count * 100;
my $pMODEL2023 = $MODEL2023 / $count * 100;
printf("%4.1f %% model 2022   ($MODEL2022 maal)\n", $pMODEL2022);
printf("%4.1f %% model 2023   ($MODEL2023 maal)\n", $pMODEL2023);
printf("%4.1f %% model 2022.5 ($MODEL2022_5 maal)\n", $pMODEL2022_5);
print "\n";

if ($OVERVIEW or $SUMMARY) {
    print "Kentekens op naam gezet per maand:\n";
    my %HREF;

    $HREF{"juni 2021"} = 'https://gathering.tweakers.net/forum/list_message/69800422#69800422';
    $HREF{"juli 2021"} = 'https://gathering.tweakers.net/forum/list_message/69800430#69800430';
    $HREF{"augustus 2021"} = 'https://gathering.tweakers.net/forum/list_message/69800436#69800436';
    $HREF{"september 2021"} = 'https://gathering.tweakers.net/forum/list_message/69800444#69800444';
    $HREF{"oktober 2021"} = 'https://gathering.tweakers.net/forum/list_message/69800446#69800446';
    $HREF{"november 2021"} = 'https://gathering.tweakers.net/forum/list_message/69800456#69800456';
    $HREF{"december 2021"} = 'https://gathering.tweakers.net/forum/list_message/69800460#69800460';
    $HREF{"januari 2022"} = 'https://gathering.tweakers.net/forum/list_message/70090920#70090920';
    $HREF{"februari 2022"} = 'https://gathering.tweakers.net/forum/list_message/70788736#70788736';
    $HREF{"maart 2022"} = 'https://gathering.tweakers.net/forum/list_message/71123634#71123634';
    $HREF{"april 2022"} = 'https://gathering.tweakers.net/forum/list_message/71393214#71393214';
    $HREF{"mei 2022"} = 'https://gathering.tweakers.net/forum/list_message/71723406#71723406';
    $HREF{"juni 2022"} = 'https://gathering.tweakers.net/forum/list_message/72031366#72031366';
    $HREF{"juli 2022"} = 'https://gathering.tweakers.net/forum/list_message/72300528#72300528';
    $HREF{"augustus 2022"} = 'https://gathering.tweakers.net/forum/list_message/72624024#72624024';
    $HREF{"september 2022"} = 'https://gathering.tweakers.net/forum/list_message/72989402#72989402';
    $HREF{"oktober 2022"} = 'https://gathering.tweakers.net/forum/list_message/73324494#73324494';
    $HREF{"november 2022"} = 'https://gathering.tweakers.net/forum/list_message/73660348#73660348';
    $HREF{"december 2022"} = 'https://gathering.tweakers.net/forum/list_message/73984554#73984554';
    $HREF{"januari 2023"} = 'https://gathering.tweakers.net/forum/list_message/74335278#74335278';
    $HREF{"februari 2023"} = 'https://gathering.tweakers.net/forum/list_message/74650990#74650990';

    my %YEARS;
    foreach my $key (sort keys %DATES) {
        my $count = $DATES{$key};
        my $countstring = sprintf("%3d", $count);
        my $jaar = substr($key, 0, 4);
        if (exists $YEARS{$jaar}) {
            $YEARS{$jaar} = $count + $YEARS{$jaar};
        } else {
            $YEARS{$jaar} = $count
        }
        my $maand = substr($key, 4, 2);
        my $maandjaarstring = $MONTHS{$maand} . " $jaar";
        if (exists $HREF{$maandjaarstring}) {
            print '[url='. $HREF{$maandjaarstring} . "]$countstring op naam gezet in $maandjaarstring" . '[/url]' ."\n";
        } else {
            print "$countstring op naam gezet in $maandjaarstring\n";
        }
    }
    print "\n";
    foreach my $key (sort keys %YEARS) {
        my $count = $YEARS{$key};
        print "$count op naam gezet in $key\n";
    }
    print "\n";

    print "Statistieken van totaal $count maal IONIQ 5:\n";
    
    my $pLONGRANGEBATTERY  = $LONGRANGEBATTERY / $count * 100;
    my $pRWD = $RWD / $count * 100;
    my $pV2L = $V2L / $count * 100;
    my $pWP = $WP / $count * 100;
    my $pPANORAMADAK = $PANORAMADAK / $count * 100;
    my $pSOLARDAK = $SOLARDAK / $count * 100;

    my $pPROJECT45 = $PROJECT45 / $count * 100;
    my $pLOUNGE = $LOUNGE / $count * 100;
    my $pCONNECTPLUS = $CONNECTPLUS / $count * 100;
    my $pCONNECT = $CONNECT / $count * 100;
    my $pSTYLE = $STYLE / $count * 100;

    printf("%4.1f %% warmtepomp (standaard vanaf Connect+, $WP maal)\n", $pWP);
    printf("%4.1f %% grote batterij ($LONGRANGEBATTERY maal)\n", $pLONGRANGEBATTERY);
    printf("%4.1f %% vehicle to load (standaard vanaf Connect, $V2L maal)\n", $pV2L);
    printf("%4.1f %% achterwielaandrijving ($RWD maal)\n", $pRWD);
    printf("%4.1f %% panoramadak ($PANORAMADAK maal)\n", $pPANORAMADAK);
    printf("%4.1f %% zonnepanelendak (alleen op PROJECT45, $SOLARDAK maal)\n", $pSOLARDAK);
    print "\n";
    printf("%4.1f %% Lounge ($LOUNGE maal)\n", $pLOUNGE);
    printf("%4.1f %% Style ($STYLE maal)\n", $pSTYLE);
    printf("%4.1f %% Connect+ ($CONNECTPLUS maal)\n", $pCONNECTPLUS);
    printf("%4.1f %% Connect ($CONNECT maal)\n", $pCONNECT);
    printf("%4.1f %% Project45 ($PROJECT45 maal)\n", $pPROJECT45);
    print "\n";

    my $pExport = $COUNTExport / $count * 100;
    printf("%4.1f %% geexporteerd ($COUNTExport maal)\n", $pExport);
    print "\n";

    my $pTaxi = $COUNTTaxi / $count * 100;
    printf("%4.1f %% Taxi ($COUNTTaxi maal)\n", $pTaxi);
    print "\n";

    my $p19 = $COUNT19INCH / $count * 100;
    my $p20 = $COUNT20INCH / $count * 100;
    my $loungeCount = $COUNTLounge19INCH + $COUNTLounge20INCH;
    my $pLounge19 = $COUNTLounge19INCH / $loungeCount * 100;
    my $pLounge20 = $COUNTLounge20INCH / $loungeCount * 100;
    printf("%4.1f %% 19 inch banden ($COUNT19INCH maal)\n", $p19);
    printf("%4.1f %% 20 inch banden ($COUNT20INCH maal)\n", $p20);
    printf("%4.1f %% Lounge 20 inch banden ($COUNTLounge20INCH maal)\n", $pLounge20);
    printf("%4.1f %% Lounge 19 inch banden ($COUNTLounge19INCH maal)\n", $pLounge19);
    print "\n";

    my %LEGENDA;
    $LEGENDA{'WIT'}   = 'Atlas White (Solid), Atlas White (Mat)';
    $LEGENDA{'GRIJS'} = 'Shooting Star (Mat), Cyber Grey (Metal.), Galactic Gray (Metal.)';
    $LEGENDA{'GROEN'} = 'Digital Teal (Mica Parelmoer), Mystic Olive (Mica)';
    $LEGENDA{'ZWART'} = 'Phantom Black (Mica Parelmoer), Abyss Black (Mica Parelmoer)';
    $LEGENDA{'BLAUW'} = 'Lucid Blue (Mica Parelmoer)';
    $LEGENDA{'GEEL'}  = 'Gravity Gold (Mat)';
    $LEGENDA{'BRUIN'} = 'Mystic Olive (Mica)';

    my @colorsoutput;
    foreach my $key (sort keys %COLORS) {
        my $number = $COLORS{$key};
        my $perc = int(($number / $count * 100) + 0.5);
        my $legenda = $LEGENDA{$key};
        my $p = sprintf("%2d", $perc);
        my $c = sprintf("%6s", $key);
        my $cnt = sprintf("%3d", $number);
        push @colorsoutput,"$p% $c ($cnt maal) $legenda\n";
    }
    print "[code]\n";
    my @sorted = sort { $b <=> $a } @colorsoutput;
    print @sorted;

    my $pCOLORMATTE = $COLORMATTE / $count * 100;
    my $pCOLORMETALLIC = $COLORMETALLIC / $count * 100;
    my $pCOLORMICA = $COLORMICA / $count * 100;
    my $pCOLORSOLID = $COLORSOLID / $count * 100;
    my $pCOLORMICAPEARL = $COLORMICAPEARL / $count * 100;

    print "\n";
    printf("%4.1f %% Mica Parelmoer kleur ($COLORMICAPEARL maal)\n", $pCOLORMICAPEARL);
    printf("%4.1f %% Mat kleur ($COLORMATTE maal)\n", $pCOLORMATTE);
    printf("%4.1f %% Metallic kleur ($COLORMETALLIC maal)\n", $pCOLORMETALLIC);
    printf("%4.1f %% Mica Kleur ($COLORMICA maal)\n", $pCOLORMICA);
    printf("%4.1f %% Solid kleur ($COLORSOLID maal)\n", $pCOLORSOLID);

    print "[/code]\n\n";

    my @variants_count_list;
    while (my ($k, $v) = each %VARIANTSCOUNT) {
        my $line = sprintf("%4d %s", $v, $k);
        print("line=[$line], k=[$k], count_str=[$v]\n") if $DEBUG;
        push @variants_count_list, $line;
    }
    my @sorted = reverse sort @variants_count_list;
    foreach my $item (@sorted) {
        my $line = $item;
        $line =~ s/^\s+//;
        my ($count_str, $k) = split(/ /, $line, 2);
        print("line=[$line], k=[$k], count_str=[$count_str]\n") if $DEBUG;
        print "key: [$k]\n" if $DEBUG;
        my $count = $VARIANTSCOUNT{$k};
        print "$count maal op gekend kenteken variant: $k\n";
        if (exists $VARIANTSCOUNTNOGNIETOPNAAM{$k}) {
            my $countNogNietOpNaam = $VARIANTSCOUNTNOGNIETOPNAAM{$k};
            if ($countNogNietOpNaam > 0) {
                print "waarvan $countNogNietOpNaam maal kenteken nog niet op naam\n";
            }
        }
        print "\n";
    }
}

__END__
:endofperl
