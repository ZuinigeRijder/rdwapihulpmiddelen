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
# Zuinige Rijder,
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
use JSON qw( decode_json );     # From CPAN
use Data::Dumper;
use File::Copy;

$| = 1; # no output buffering

# declaration of subroutine prototypes
sub myDie($);
sub executeCommand($);
sub round5($);
sub fillPrice($$$$$$$);
sub findHelper($$);
sub showPricesEntries($$);
sub findVariantExact($$$$$);
sub findVariantNearest($$$$$);
sub getVariant($$$$);
sub getPrintLine($);

my $true=1;
my $false=0;
my $DEBUG=$false;
my $DUMP=$false;
my $COUNT=0;

# this contains the pricelist per date and kWh battery and AWD
my @PRICELISTS_DATES;
my %PRICELISTS;

my %VARIANTSCOUNT;
my %VARIANTSCOUNTNOGNIETOPNAAM;

my $COUNTTaxi = 0;
my $taxi = 'Nee';

my $COUNTExport = 0;
my $export = 'Nee';

my $COUNT19INCH = 0;
my $COUNT20INCH = 0;
my $COUNTLounge19INCH = 0;
my $COUNTLounge20INCH = 0;

my $COLORMATTE = 0;
my $COLORMETALLIC = 0;
my $COLORMICA = 0;
my $COLORSOLID = 0;
my $COLORMICAPEARL = 0;

#===============================================================================
# die
# parameter 1: die string
#===============================================================================
sub myDie($) {
    my ($txt) = @_;
    print "\n", "?" x 80, "\n";
    print "Error: $txt\n\n";
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

#===============================================================================
# round5
# parameter 1: integer number
#===============================================================================
sub round5($) {
    my ($number) = @_;

    my $remainder = $number % 5;

    if ($remainder < 3) {
        return $number - $remainder; 
    } else {
        return $number - $remainder + 5;
    }
}

#===============================================================================
# fillPrice
# parameter 1: hash reference
# parameter 2: variant
# parameter 3: prijscheck
# parameter 4: batterijgrootte
# parameter 5: AWD
# parameter 6: model2023
# parameter 7: prijslijst
# return variant
#
#  795 V2L (alleen op Style i.c.m. warmtepomp)
# 1200 WP (alleen beschikbaar op Style en Connect)
#  895 Panoramadak (alleen op Lounge)
# 1200 Zonnedak (alleen op Lounge)
# -750 geen FCA-JX en HDA2 (alleen op Connect, Connect+ en Lounge)
#  400 digitale binnenspiegel (2023 model)
# 1400 digitale buitenspiegels (2023 model)
#    0 19 inch wielen i.p.v. 20 inch (alleen Lounge)
#
sub fillPrice($$$$$$$) {
    my $prices = shift;
    my ($variant, $prijscheck, $batterijgrootte, $AWD, $model2023, $prijslijst) = @_;
    print "$variant, $prijscheck, $batterijgrootte, $AWD, $model2023, $prijslijst\n" if $DEBUG;
    my $zonderFCA_HDA2 = ($prijslijst ne "mei 2021");
    $prijslijst = " (prijslijst $prijslijst)";
    #$prijslijst = "";
    my $duurder1500 = $false;
    $batterijgrootte = "$batterijgrootte kWh ";
    my $awd = '';
    if ($AWD) {
        $batterijgrootte .= 'AWD ';
    }
    $$prices{$prijscheck} = $batterijgrootte . $variant . $prijslijst;
    $$prices{$prijscheck+1500} = $batterijgrootte . $variant . $prijslijst . " (1500 euro duurder)" if $duurder1500;
    
    if ($variant eq 'Style') {
        $$prices{$prijscheck+1200} = $batterijgrootte . $variant . " met WP" . $prijslijst;
        $$prices{$prijscheck+1200+795} = $batterijgrootte . $variant . " met WP en V2L" . $prijslijst;
        
        $$prices{$prijscheck+1200+1500} = $batterijgrootte . $variant . " met WP" . $prijslijst . " (1500 euro duurder)"  if $duurder1500;
        $$prices{$prijscheck+1200+795+1500} = $batterijgrootte . $variant . " met WP en V2L" . $prijslijst . " (1500 euro duurder)"  if $duurder1500;
        
    } elsif ($variant eq 'Lounge') {
        $$prices{$prijscheck+895} = $batterijgrootte . $variant . " met Panoramadak" . $prijslijst;
        $$prices{$prijscheck+1200} = $batterijgrootte . $variant . " met Zonnepanelendak" . $prijslijst;
        
        $$prices{$prijscheck+895+1500} = $batterijgrootte . $variant . " met Panoramadak" . $prijslijst . " (1500 euro duurder)"  if $duurder1500;
        $$prices{$prijscheck+1200+1500} = $batterijgrootte . $variant . " met Zonnepanelendak" . $prijslijst . " (1500 euro duurder)"  if $duurder1500;
                
        if ($zonderFCA_HDA2) {
            $$prices{$prijscheck-750} = $batterijgrootte . $variant . " zonder FCA-JX/HDA2" . $prijslijst;
            $$prices{$prijscheck+895-750} = $batterijgrootte . $variant . " met Panoramadak zonder FCA-JX/HDA2" . $prijslijst;
            $$prices{$prijscheck+1200-750} = $batterijgrootte . $variant . " met Zonnepanelendak zonder FCA-JX/HDA2" . $prijslijst;
            
            $$prices{$prijscheck-750+1500} = $batterijgrootte . $variant . " zonder FCA-JX/HDA2" . $prijslijst . " (1500 euro duurder)"  if $duurder1500;
            $$prices{$prijscheck+895-750+1500} = $batterijgrootte . $variant . " met Panoramadak zonder FCA-JX/HDA2" . $prijslijst . " (1500 euro duurder)" if $duurder1500;
            $$prices{$prijscheck+1200-750+1500} = $batterijgrootte . $variant . " met Zonnepanelendak zonder FCA-JX/HDA2" . $prijslijst . " (1500 euro duurder)" if $duurder1500;  
        }
        
        if ($model2023) {
            $$prices{$prijscheck+1400} = $batterijgrootte . $variant . " met digitale buitenspiegels" . $prijslijst;
            $$prices{$prijscheck+895+1400} = $batterijgrootte . $variant . " met Panoramadak en digitale buitenspiegels" . $prijslijst;
            $$prices{$prijscheck+1200+1400} = $batterijgrootte . $variant . " met Zonnepanelendak en digitale buitenspiegels" . $prijslijst;
            
            if ($zonderFCA_HDA2) {
                $$prices{$prijscheck+1400-750} = $batterijgrootte . $variant . " met digitale buitenspiegels zonder FCA-JX/HDA2" . $prijslijst;
                $$prices{$prijscheck+895+1400-750} = $batterijgrootte . $variant . " met Panoramadak en digitale buitenspiegels zonder FCA-JX/HDA2" . $prijslijst;
                $$prices{$prijscheck+1200+1400-750} = $batterijgrootte . $variant . " met Zonnepanelendak en digitale buitenspiegels zonder FCA-JX/HDA2" . $prijslijst;
            }
       }
       
    } elsif ($variant eq 'Connect') {
        $$prices{$prijscheck+1200} = $batterijgrootte . $variant . " met WP" . $prijslijst;
        
        $$prices{$prijscheck+1200+1500} = $batterijgrootte . $variant . " met WP" . $prijslijst . " (1500 euro duurder)"  if $duurder1500;
        
        if ($zonderFCA_HDA2) {
        
            $$prices{$prijscheck-750} = $batterijgrootte . $variant . " zonder FCA-JX/HDA2" . $prijslijst;
            $$prices{$prijscheck+1200-750} = $batterijgrootte . $variant . " met WP zonder FCA-JX/HDA2" . $prijslijst;
            
            $$prices{$prijscheck-750+1500} = $batterijgrootte . $variant . " zonder FCA-JX/HDA2" . $prijslijst . " (1500 euro duurder)"  if $duurder1500;
            $$prices{$prijscheck+1200-750+1500} = $batterijgrootte . $variant . " met WP zonder FCA-JX/HDA2" . $prijslijst . " (1500 euro duurder)"  if $duurder1500;
        }

    } elsif ($variant eq 'Connect+') {
        if ($zonderFCA_HDA2) {
            $$prices{$prijscheck-750} = $batterijgrootte . $variant . " zonder FCA-JX/HDA2" . $prijslijst;
            
            $$prices{$prijscheck-750+1500} = $batterijgrootte . $variant . " zonder FCA-JX/HDA2" . $prijslijst . " (1500 euro duurder)"  if $duurder1500;
        }

    } else {
        myDie("PROGRAMERROR: variant niet bekend: $variant");
    }
}

#===============================================================================
# showPricesEntries
# parameter 1: hash
# parameter 2: kenteken
sub showPricesEntries($$) {
    my $prices = shift;
    my ($kenteken) = @_;
    print("showPricesEntries $kenteken\n");
    while (my ($price, $value) = each (%${prices})) {
        print("$kenteken: prijs=[$price], value=[$value]\n");
    }
}

#===============================================================================
# findVariantExact
# parameter 1: kenteken
# parameter 2: prijs
# parameter 3: variant
# parameter 4: model2023
# parameter 5: date
# return variant
#
sub findVariantExact($$$$$) {
    my ($kenteken, $prijs, $variant, $model2023, $date) = @_;
    
    my $AWD = ($variant eq 'F5E14' or $variant eq 'F5E54');
    my $smallbattery = ($variant eq 'F5E42');
        
    my $result = '';
    
    foreach my $pricelist_date (@PRICELISTS_DATES) {
        if ($date < $pricelist_date) {
            print("Skipping pricelist $pricelist_date for $date\n") if $DEBUG;
            next; # skip registration dates before prijslist date
        }
    
        print("Checking $kenteken pricelist $pricelist_date for $date\n") if $DEBUG;
        #if ("$kenteken" eq "P185VD") {
        #    showPricesEntries($PRICELISTS{$pricelist_date . "_58"}, $kenteken);
        #}
        if ($smallbattery) {
            if ($model2023) {
                if (exists $PRICELISTS{$pricelist_date . "_58_2023"}{$prijs}) {
                    $result = $PRICELISTS{$pricelist_date . "_58_2023"}{$prijs};
                }
            } else {
                if (exists $PRICELISTS{$pricelist_date . "_58"}{$prijs}) {
                    $result = $PRICELISTS{$pricelist_date . "_58"}{$prijs};
                }
            }
        } elsif ($AWD) {
            if ($model2023) {
                if (exists $PRICELISTS{$pricelist_date . "_77AWD"}{$prijs}) {
                    $result = $PRICELISTS{$pricelist_date . "_77AWD"}{$prijs};
                } 
            } else {
                if (exists $PRICELISTS{$pricelist_date . "_73AWD"}{$prijs}) {
                    $result = $PRICELISTS{$pricelist_date . "_73AWD"}{$prijs};
                } 
            }
        } else {
            if ($model2023) {
                if (exists $PRICELISTS{$pricelist_date . "_77"}{$prijs}) {
                    $result = $PRICELISTS{$pricelist_date . "_77"}{$prijs};
                }
            } else {
                if (exists $PRICELISTS{$pricelist_date . "_73"}{$prijs}) {
                    $result = $PRICELISTS{$pricelist_date . "_73"}{$prijs};
                }
            }  
        }
        
        if ($result != '') {
            last; # found result....
        }
    }
    print "findVariantExact $kenteken result $prijs, $AWD, $smallbattery: [$result]\n" if $DEBUG;
    return $result;
}

#===============================================================================
# findHelper
# parameter 1: prices hash
# parameter 2: prijs
# return variant
#
sub findHelper($$) {
    my $prices = shift;
    my ($prijs) = @_;
    my $foundDelta = 9999999;
    my $foundPrice = 0;
    while (my ($price, $value) = each (%${prices})) {
        my $delta = abs($prijs - $price); 
        if ($delta < $foundDelta) {
            $foundDelta = $delta;
            $foundPrice = $price;
        }
    }
    my $result = $$prices{$foundPrice};
    if ($foundDelta != 0) {
        my $delta = $prijs - $foundPrice;
        my $absDelta = abs($delta);
        if ($absDelta == $delta) {
            $result .= " \$(E$absDelta duurder dan prijslijst)";
        } else {
            $result .= " \$(E$absDelta goedkoper dan prijslijst)";
        }
    }
    print "findHelper result $prijs: $result\n" if $DEBUG;
    return $result;
}

#===============================================================================
# findVariantNearest
# parameter 1: kenteken
# parameter 2: prijs
# parameter 3: variant
# parameter 4: model2023
# parameter 5: date
# return variant
#
sub findVariantNearest($$$$$) {
    my ($kenteken, $prijs, $variant, $model2023, $date) = @_;
    
    my $AWD = ($variant eq 'F5E14' or $variant eq 'F5E54');
    my $smallbattery = ($variant eq 'F5E42');
    
    my $result = '';
    
    foreach my $pricelist_date (@PRICELISTS_DATES) {
        if ($date < $pricelist_date) {
            print("Skipping nearest pricelist $pricelist_date for $date\n") if $DEBUG;
            next; # skip registration dates before prijslist date
        }
        
        print("Checking $kenteken pricelist $pricelist_date for $date\n") if $DEBUG;
        if ($smallbattery) {
            if ($model2023) {
                $result = findHelper($PRICELISTS{$pricelist_date . "_58_2023"}, $prijs);  
            } else {
                $result = findHelper($PRICELISTS{$pricelist_date . "_58"}, $prijs);  
            }
        } elsif ($AWD) {
            if ($model2023) {
                $result = findHelper($PRICELISTS{$pricelist_date . "_77AWD"}, $prijs);
            } else {
                $result = findHelper($PRICELISTS{$pricelist_date . "_73AWD"}, $prijs);
            }
        } else {
            if ($model2023) {
                $result = findHelper($PRICELISTS{$pricelist_date . "_77"}, $prijs);
            } else {
                $result = findHelper($PRICELISTS{$pricelist_date . "_73"}, $prijs);
            }
        }
        if ($result != '') {
            last;
        }
    }
    print "findVariantNearest $kenteken result $prijs, $AWD, $smallbattery: [$result]\n" if $DEBUG;
    return $result;
}

#===============================================================================
# getVariant and count variants at the same time
# parameter 1: type
# parameter 2: opNaam
# parameter 3: kenteken
# parameter 4: date
# return type
#
# Legenda:
#
# Typegoedkeuring: 
# e9*2018/858*11054*01 since 20210405 (model 2022)
# e9*2018/858*11054*03 since 20220210 (model 2022.5)
# e9*2018/858*11054*04 since 20220708 (model 2023)
#
# Variant:
# F5E14=72 kWh AWD (model 2022)
# F5E32=72 kWh RWD (model 2022)
# F5E42=58 kWh RWD (model 2022/2023)
# F5E54=77 kWh AWD (model 2023)
# F5E62=77 kWh RWD (model 2023)
#
# Uitvoering:
# E11A11=19 inch
# E11B11=20 inch
#
# Kleuren:
# GEEL  Gravity Gold (Mat)
# ZWART Phantom Black (Mica Parelmoer)
# GROEN Digital Teal (Mica Parelmoer), Mystic Olive (Mica)
# BLAUW Lucid Blue (Mica Parelmoer)
# GRIJS Shooting Star (Mat), Cyber Grey (Metal.), Galactic Gray (Metal.)
# WIT   Atlas White (Solid)
# BRUIN Mystic Olive (Mica) 
#
#  795 V2L (alleen op Style i.c.m. warmtepomp)
# 1200 WP (alleen beschikbaar op Style en Connect)
#  895 Panoramadak (alleen op Lounge)
# 1200 Zonnedak (alleen op Lounge)
# -750 geen FCA-JX en HDA2 (alleen op Connect, Connect+ en Lounge)
#  400 digitale binnenspiegel (2023 model)
# 1400 digitale buitenspiegels (2023 model)
#    0 19 inch wielen i.p.v. 20 inch (alleen Lounge)
#
# Extra prijzen kleuren
#  695 Wit
#  895 Mica/Metallic
# 1095 Matte
#
#===============================================================================
sub getVariant($$$$) {
    my ($fulltype, $opNaam, $kenteken, $date) = @_;
    
    my $value = "ERROR";
    if ($DEBUG) {
        print "#kenteken: $kenteken\n";
        print "#fulltype: $fulltype\n";
        print "#opNaam  : $opNaam\n";
        print "#date    : $date\n";
    }
    if ($date < 20210401 or $date > 20240101) {
        myDie("Unexpected date: $date for $kenteken $fulltype\n");
    }

    my $kleur = 'GRIJS';
    my $inch20 = $true;
    
#F5E14;E11B11;e9*2018/858*11054*01; prijs: 59600 GRIJS
#$variant;$uitvoering;$typegoedkeuring; prijs: $prijs $kleur";
#          1         2         3         4         5         6         7         8
#0123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890
    my ($variant, $uitvoering, $typegoedkeuring, $prijskleur) = split /;/, $fulltype;
    $prijskleur =~ s? +??; # multiple spaces replaced by one
    $prijskleur =~ s? $??; # remove trailing space
    $prijskleur =~ s?^ ??; # remove leading space
    if (not $prijskleur =~ /^prijs: /) {
       myDie("Geen prijs in fulltype: $fulltype");
    }
    if ($variant eq 'F5E14') {
        $value = '73 kWh AWD';
    } elsif ($variant eq 'F5E32') {
        $value = '73 kWh';
    } elsif ($variant eq 'F5E42') {
        $value = '58 kWh';
    } elsif ($variant eq 'F5E54') {
        $value = '77 kWh';
    } elsif ($variant eq 'F5E62') {
        $value = '77 kWh';
    } elsif ($variant eq 'F5E24') {
        $value = '58 kWh';
    } else {
        myDie("ERROR: variant $variant fout voor $kenteken: $fulltype");
    }
    
    if ($uitvoering ne 'E11A11' and $uitvoering ne 'E11B11') {
        myDie("ERROR: uitvoering $uitvoering fout voor $kenteken: $fulltype");
    } 
    $inch20 = $uitvoering eq 'E11B11';
    if ($inch20 and $variant eq 'F5E42') {
        myDie("58 kWh and 20 inch not possible");
    }

    if ($typegoedkeuring ne 'e9*2018/858*11054*01' and $typegoedkeuring ne 'e9*2018/858*11054*03' and $typegoedkeuring ne 'e9*2018/858*11054*04') {
        myDie("ERROR: typegoedkeuring $typegoedkeuring fout voor $kenteken: $fulltype");
    }
    my $model2023 = ($typegoedkeuring eq 'e9*2018/858*11054*04');
    
    $prijskleur =~ s?.*prijs: ??;
    my ($prijs, $tempkleur) = split / /, $prijskleur; 
    $kleur = $tempkleur;
    if ($kleur ne 'WIT' and $kleur ne 'GRIJS' and $kleur ne 'GROEN' and $kleur ne 'ZWART' and $kleur ne 'BLAUW' and $kleur ne 'GEEL' and $kleur ne 'BRUIN') {
        myDie("ERROR: kleur $kleur fout voor $kenteken: $fulltype");
    }
    
    if (($prijs < 42000 or $prijs > 71000) and $prijs != 72300 and $prijs != 37831 and $prijs != 5242655 and $prijs != 78650 and $prijs != 33589) {
        myDie("ERROR: prijs $prijs fout voor $kenteken: $fulltype");
    }
    print "#prijs   : $prijs\n" if $DEBUG;
    # round prijs to multiple of 5 euro
    $prijs = round5($prijs);
    print "#prijs5  : $prijs\n" if $DEBUG;
    print "#kleur   : $kleur\n" if $DEBUG;
    
    my $prijs2 = $prijs;
    if ($variant eq 'F5E14') {
        if ($prijs == 58000) {
            $value = 'PROJECT45';
        } elsif (
            $kenteken eq 'L162KD' or
            $kenteken eq 'L430TK' or
            $kenteken eq 'L431TK' or
            $kenteken eq 'L432TK' or
            $kenteken eq 'N309TK' or
            $kenteken eq 'P229NR') {
# L162KD 20210607 E58895 Digital Teal   PROJECT45$
# L430TK 20210729 E58895 Phantom Black  PROJECT45$
# L431TK 20210802 E58695 Atlas White    PROJECT45$
# L432TK 20210728 E59095 Gravity Gold   PROJECT45$
# N309TK 20211223 E59095 Gravity Gold   PROJECT45$
# P229NR 20220510 E58895 Phantom Black  PROJECT45$
            $value = 'PROJECT45$';
        }
    }
    if ($value ne 'PROJECT45' and $value ne 'PROJECT45$') {
        if ($kleur eq 'WIT') {
            if ($model2023) { # model 2023 heeft mogelijk Atlas White Matte
                $prijs -= 695; # Atlas White Solid
                $prijs2 -= 1095; # Atlas White Matte
            } else {
                $prijs -= 695; # Atlas White Solid
                $prijs2 = 0;
            }
        } elsif ($kleur eq 'ZWART') {
            $prijs -= 895; # Phantom Black Pearl Mica of Abyss Black Pearl Mica
            $prijs2 = 0;
        } elsif ($kleur eq 'BLAUW') {
            if ($date > "20220801") { # model 2023 en mogelijk ook 2022 is (ook) zonder meerprijs
                $prijs2 -= 895;
            } else {
                $prijs -= 895;
                $prijs2 = 0;
            }
        } elsif ($kleur eq 'GEEL') {
            $prijs -= 1095;
            $prijs2 = 0;
        } elsif ($kleur eq 'GRIJS') {
            $prijs -= 895;
            $prijs2 -= 1095;
        } elsif ($kleur eq 'GROEN') {
            $prijs2 -= 895;
        } elsif ($kleur eq 'BRUIN') {
            # Olive
            $prijs2 = 0;
        } else {
            myDie("PROGRAMERROR: kleur $kleur fout voor $kenteken: $fulltype");
        }
        
        if ($DEBUG and $kenteken eq 'R059VH') {
             print "$kenteken, $prijs, $variant, $model2023, $date\n";
        }

        my $foundVariant = findVariantExact($kenteken, $prijs, $variant, $model2023, $date);
        my $foundVariant2 = '';
        if ($prijs != $prijs2 and $prijs2 != 0) {
            $foundVariant2 = findVariantExact($kenteken, $prijs2, $variant, $model2023, $date);
        }
        
        if ($foundVariant eq '' and $foundVariant2 eq '') { # find nearest price
            $foundVariant = findVariantNearest($kenteken, $prijs, $variant, $model2023, $date);
            $foundVariant2 = '';
            if ($prijs != $prijs2 and $prijs2 != 0) {
                $foundVariant2 = findVariantNearest($kenteken, $prijs2, $variant, $model2023, $date);
                # the smallest delta wins
                my $delta1 = 9999999;
                my $delta2 = 9999999;
                #$(E$delta duurder dan prijslijst)
                #$(E$delta goedkoper dan prijslijst)
                if ($foundVariant =~ /dan prijslijst\)/) {
                    my $s = $foundVariant;
                    $s =~ s?.*\$\(E??;
                    $s =~ s? [a-z]+ dan prijslijst\).*??;
                    $delta1 = $s;
                }
                if ($foundVariant2 =~ /dan prijslijst\)/) {
                    my $s = $foundVariant2;
                    $s =~ s?.*\$\(E??;
                    $s =~ s? [a-z]+ dan prijslijst\).*??;
                    $delta2 = $s;
                }
                if (abs($delta2) < abs($delta1)) {
                    $foundVariant = '';
                } else {
                    $foundVariant2 = '';
                }
            }
        }
        if ($foundVariant ne '' and $foundVariant2 ne '') {
            if ($kleur ne 'GROEN') {
                print "WARNING: 2 variants found for $kenteken $kleur: [$foundVariant] and [$foundVariant2]\n" if $DEBUG;
            }
        }

        if ($kleur eq 'GRIJS') {
            if ($foundVariant2 ne '') {
                $foundVariant2 .= ' (Shooting Star)';
                if ($foundVariant ne '') {
                    print "Found DUBBEL GRIJS $kenteken: $fulltype -> [$foundVariant],[$foundVariant2]\n" if $DEBUG;
                    $foundVariant2 = ''; #do not assume shooting star
                }
            }
        } elsif ($kleur eq 'WIT') {
            if ($foundVariant2 ne '') {
                $foundVariant2 .= ' (Atlas White Matte)';
                if ($foundVariant ne '') {
                    print "Found DUBBEL WHITE $kenteken: $fulltype -> [$foundVariant],[$foundVariant2]\n";
                    $foundVariant2 = ''; #do not assume Atlas White Matte
                }
            }
        } elsif ($kleur eq 'GROEN') {
            if ($foundVariant ne '') {
                $foundVariant .= ' (Olive)';
                print "Found OLIVE GROEN $kenteken: $fulltype -> $foundVariant\n" if $DEBUG;
            }
            if ($foundVariant ne '' and $foundVariant2 ne '') {
                if ($foundVariant =~ /Panoramadak/i) {
                    $foundVariant2 .= ' (Digital Teal, Mystic Olive met Panoramadak)';
                    print "Found DUBBEL GROEN $kenteken: $fulltype -> [$foundVariant],[$foundVariant2]\n" if $DEBUG;
                    $foundVariant = ''; 
                } else {
                    print "Found UNEXPECTED DUBBEL GROEN $kenteken: $fulltype -> [$foundVariant],[$foundVariant2]\n" if $DEBUG;
                    $foundVariant = ''; #assume digital teal
                }
            }
        }
        
        if ($foundVariant eq '') {
            $foundVariant = $foundVariant2;
        }
        $value = $foundVariant;
        print "#value=$value\n" if $DEBUG;
    }

    if ($inch20) {
        if (not $value =~ /Lounge/ and not $value =~ /PROJECT45/i) {
            $value .= ' (20 inch banden)';
        }
    } else {
        if ($value =~ /Lounge/ or $value =~ /PROJECT45/i) {
            $value .= ' (19 inch banden)';
        }
    }
    
    if ($inch20) {
        $COUNT20INCH++;
        if ($value =~ /Lounge/i) {
            $COUNTLounge20INCH++;
        }
    } else {
        $COUNT19INCH++;
        if ($value =~ /Lounge/i) {
            $COUNTLounge19INCH++;
        }
    }
    
    if ($taxi eq 'Ja') {
       $value .= ' (Taxi)';
       print "VALUE: $value\n" if $DEBUG;
    }
    
    if ($export eq 'Ja') {
        $value .= ' (geexporteerd)';
        print "VALUE: $value\n" if $DEBUG;
    }
    
    $value .= " ($typegoedkeuring)" if $DEBUG;
    if ($typegoedkeuring eq 'e9*2018/858*11054*01') {
        $value .= " (model 2022)"
    } elsif ($typegoedkeuring eq 'e9*2018/858*11054*03') {
        $value .= " (model 2022.5)"
    } elsif ($typegoedkeuring eq 'e9*2018/858*11054*04') {
        $value .= " (model 2023)"
    }
    
    if ($kleur eq 'WIT') {
        if ($value =~ /\(Atlas White Matte\)/i) {
            $COLORMATTE++;
        } else {
            $COLORSOLID++;
        }
    } elsif ($kleur eq 'ZWART') {
        $COLORMICAPEARL++;
    } elsif ($kleur eq 'BLAUW') {
        $COLORMICAPEARL++;
    } elsif ($kleur eq 'GEEL') {
        $COLORMATTE++;
    } elsif ($kleur eq 'GRIJS') {
        if ($value =~ /\(Shooting Star\)/i) {
            $COLORMATTE++;
        } else {
            $COLORMETALLIC++;
        }
    } elsif ($kleur eq 'GROEN') {
        if ($value =~ /\(Olive\)/i) {
            $COLORMICA++;
        } else {
            $COLORMICAPEARL++;
        }
    } elsif ($kleur eq 'BRUIN') {
        # Olive
        $COLORMICA++;
    } else {
        myDie("PROGRAMERROR: kleur $kleur fout voor $kenteken: $fulltype");
    }
    
    my $stripped = $value;
    $stripped =~ s?\$\(E[0-9]+ [a-z]+ dan prijslijst\)??; # exclude dollar and goedkoper/duurder
    $stripped =~ s?\$??; # exclude dollar in counting
    $stripped =~ s? \(model 202[^)]+\)??i; # exclude model in counting
    $stripped =~ s? \(Taxi\)??i; # exclude taxi in counting
    $stripped =~ s? \(geexporteerd\)??i; # exclude geexporteerd in counting
    $stripped =~ s? \(prijslijst [^)]+\)??i; # exclude prijslijst in counting
    $stripped =~ s? \(1500 euro duurder\)??i; # exclude prijsinfo in counting
    $stripped =~ s? \(1495 euro duurder\)??i; # exclude prijsinfo in counting
    $stripped =~ s? zonder FCA-JX\/HDA2??i; # exclude prijsinfo in counting
    $stripped =~ s? \(19 inch banden\)??i; # exclude bandeninfo in counting
    $stripped =~ s? \(20 inch banden\)??i; # exclude bandeninfo in counting
    $stripped =~ s? \(Digital Teal, Mystic Olive met Panoramadak\)??i; # exclude colorinfo in counting
    $stripped =~ s? \(Olive\)??; # exclude colorinfo in counting
    $stripped =~ s? \(Shooting Star\)??; # exclude colorinfo in counting
    $stripped =~ s? \(Atlas White Matte\)??; # exclude colorinfo in counting
    $stripped =~s?\s+$??; # remove trailing spaces
    if (exists $VARIANTSCOUNT{$stripped}) {
        $VARIANTSCOUNT{$stripped} += 1;
    } else {
        $VARIANTSCOUNT{$stripped} = 1;
    }
    if (not $opNaam) {
        if (exists $VARIANTSCOUNTNOGNIETOPNAAM{$stripped}) {
            $VARIANTSCOUNTNOGNIETOPNAAM{$stripped} += 1;
        } else {
            $VARIANTSCOUNTNOGNIETOPNAAM{$stripped} = 1;
        }
    }   
    print "#RETURN: [$value]\n" if $DEBUG;
    return $value;
}

#===============================================================================
# getPrintLine
# parameter 1: line
# format:
#           1         2         3         4         5         6         7         8         9         
# 01234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890
# NDHN146DH 20210917 GRIJS      55600    F5E32;E11A11;e9*2018/858*11054*01; prijs: 55600 GRIJS     73 kWh Lounge
# return printLine
#===============================================================================
sub getPrintLine($) {
    my ($line) = @_;
    print "getPrintLine($line)\n" if $DEBUG;
    my $new = substr($line, 3, 16) . substr($line, 39, 54) . substr($line, 97);
    $new =~ s?;e9\*2018\/858\*11054\*0[134];??;
    $new =~ s?prijs: ?E?;
    # Kleuren:
    # GEEL  Gravity Gold (Mat)
    # ZWART Phantom Black (Mica Parelmoer)
    # GROEN Digital Teal (Mica Parelmoer), Mystic Olive (Mica)
    # BLAUW Lucid Blue (Mica Parelmoer)
    # BRUIN Mystic Olive (Mica)
    # GRIJS Shooting Star (Mat), Cyber Grey (Metal.), Galactic Gray (Metal.)
    # WIT   Atlas White (Solid) Atlas White Matte
    $new =~ s?GEEL  ?Gravity Gold   ?;
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
    $new =~ s?BRUIN ?Mystic Olive   ?;
    if ($new =~/GRIJS / and ($new =~ / \(Shooting Star\)/ or $new =~ /PROJECT45/i)) {
        $new =~ s? \(Shooting Star\)??;
        $new =~ s?GRIJS ?Shooting Star  ?;
    } 
    $new =~ s?GRIJS ?Cyber/Galactic ?;
    if ($new =~/WIT / and ($new =~ / \(Atlas White Matte\)/)) {
        $new =~ s?WIT   ?White Matte    ?;
    } else {
        $new =~ s?WIT   ?Atlas White    ?;
    }
    
    # get rid of internal information too, not interesting for end user
    $new =~ s?F5E..;E11.11 ??;
    print "getPrintLine RESULT: [$new]\n" if $DEBUG;
    
    return $new;
}

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
       die("Usage: rdw [SUMMARY|OVERVIEW|UPDATE]\n");
    }
} elsif (@ARGV != 0) {
    die("Invalid number of arguments: Usage: rdw [SUMMARY|OVERVIEW]\n");
}

# pricelists of jan 2023, sept 2022, mei 2022, maart 2022, mei 2021
@PRICELISTS_DATES = ("20230101", "20220901", "20220501", "20220301", "20210501");

#========== model2022 ============================================================
# model 2022 prijslijst mei 2021 (prijslijst mei 2022 1500 euro duurder)
my %pricesmei2021_small_battery;
my %pricesmei2021_big_battery;
my %pricesmei2021_big_battery_AWD;

fillPrice(\%pricesmei2021_small_battery, 'Style', 42505, 58, $false, $false, "mei 2021");
fillPrice(\%pricesmei2021_small_battery, 'Connect', 46505, 58, $false, $false, "mei 2021");
fillPrice(\%pricesmei2021_small_battery, 'Connect+', 49505, 58, $false, $false, "mei 2021");
fillPrice(\%pricesmei2021_small_battery, 'Lounge', 51705, 58, $false, $false, "mei 2021");

fillPrice(\%pricesmei2021_big_battery, 'Style', 45505, 73, $false, $false, "mei 2021");
fillPrice(\%pricesmei2021_big_battery, 'Connect', 49505, 73, $false, $false, "mei 2021");
fillPrice(\%pricesmei2021_big_battery, 'Connect+', 52505, 73, $false, $false, "mei 2021");
fillPrice(\%pricesmei2021_big_battery, 'Lounge', 54705, 73, $false, $false, "mei 2021");
        
fillPrice(\%pricesmei2021_big_battery_AWD, 'Connect', 53505, 73, $true, $false, "mei 2021");
fillPrice(\%pricesmei2021_big_battery_AWD, 'Connect+', 56505, 73, $true, $false, "mei 2021");
fillPrice(\%pricesmei2021_big_battery_AWD, 'Lounge', 58705, 73, $true, $false, "mei 2021");

$PRICELISTS{"20210501_58"} = \%pricesmei2021_small_battery;
$PRICELISTS{"20210501_73"} = \%pricesmei2021_big_battery;
$PRICELISTS{"20210501_73AWD"} = \%pricesmei2021_big_battery_AWD;

# model 2022 prijslijst maart 2022:
my %pricesmaart2022_small_battery;
my %pricesmaart2022_big_battery;
my %pricemaart2022_big_battery_AWD;

fillPrice(\%pricesmaart2022_small_battery, 'Style', 42805, 58, $false, $false, "maart 2022");
fillPrice(\%pricesmaart2022_small_battery, 'Connect', 46905, 58, $false, $false, "maart 2022");
fillPrice(\%pricesmaart2022_small_battery, 'Connect+', 49905, 58, $false, $false, "maart 2022");
fillPrice(\%pricesmaart2022_small_battery, 'Lounge', 52305, 58, $false, $false, "maart 2022");

fillPrice(\%pricesmaart2022_big_battery, 'Style', 46405, 73, $false, $false, "maart 2022");
fillPrice(\%pricesmaart2022_big_battery, 'Connect', 50505, 73, $false, $false, "maart 2022");
fillPrice(\%pricesmaart2022_big_battery, 'Connect+', 53505, 73, $false, $false, "maart 2022");
fillPrice(\%pricesmaart2022_big_battery, 'Lounge', 55905, 73, $false, $false, "maart 2022");
        
fillPrice(\%pricemaart2022_big_battery_AWD, 'Connect', 54505, 73, $true, $false, "maart 2022");
fillPrice(\%pricemaart2022_big_battery_AWD, 'Connect+', 57505, 73, $true, $false, "maart 2022");
fillPrice(\%pricemaart2022_big_battery_AWD, 'Lounge', 59905, 73, $true, $false, "maart 2022");

# also take into account korting
fillPrice(\%pricesmaart2022_small_battery, 'Style', 42805-300, 58, $false, $false, "maart 2022 E300 korting");
fillPrice(\%pricesmaart2022_small_battery, 'Connect', 46905-400, 58, $false, $false, "maart 2022 E400 korting");
fillPrice(\%pricesmaart2022_small_battery, 'Connect+', 49905-400, 58, $false, $false, "maart 2022 E400 korting");
fillPrice(\%pricesmaart2022_small_battery, 'Lounge', 52305-600, 58, $false, $false, "maart 2022 E600 korting");

fillPrice(\%pricesmaart2022_big_battery, 'Style', 46405-900, 73, $false, $false, "maart 2022 E900 korting");
fillPrice(\%pricesmaart2022_big_battery, 'Connect', 50505-1000, 73, $false, $false, "maart 2022 E1000 korting");
fillPrice(\%pricesmaart2022_big_battery, 'Connect+', 53505-1000, 73, $false, $false, "maart 2022 E1000 korting");
fillPrice(\%pricesmaart2022_big_battery, 'Lounge', 55905-1200, 73, $false, $false, "maart 2022 E1200 korting");
        
fillPrice(\%pricemaart2022_big_battery_AWD, 'Connect', 54505-1000, 73, $true, $false, "maart 2022 E1000 korting");
fillPrice(\%pricemaart2022_big_battery_AWD, 'Connect+', 57505-1000, 73, $true, $false, "maart 2022 E1000 korting");
fillPrice(\%pricemaart2022_big_battery_AWD, 'Lounge', 59905-1200, 73, $true, $false, "maart 2022 E1200 korting");

$PRICELISTS{"20220301_58"} = \%pricesmaart2022_small_battery;
$PRICELISTS{"20220301_73"} = \%pricesmaart2022_big_battery;
$PRICELISTS{"20220301_73AWD"} = \%pricemaart2022_big_battery_AWD;

# model 2022 prijslijst mei 2022: 1500 euro duurder dan jan 2022
my %pricesmei2022_small_battery;
my %pricesmei2022_big_battery;
my %pricesmei2022_big_battery_AWD;

fillPrice(\%pricesmei2022_small_battery, 'Style', 44305, 58, $false, $false, "mei 2022");
fillPrice(\%pricesmei2022_small_battery, 'Connect', 48405, 58, $false, $false, "mei 2022");
fillPrice(\%pricesmei2022_small_battery, 'Connect+', 51405, 58, $false, $false, "mei 2022");
fillPrice(\%pricesmei2022_small_battery, 'Lounge', 53805, 58, $false, $false, "mei 2022");

fillPrice(\%pricesmei2022_big_battery, 'Style', 47905, 73, $false, $false, "mei 2022");
fillPrice(\%pricesmei2022_big_battery, 'Connect', 52005, 73, $false, $false, "mei 2022");
fillPrice(\%pricesmei2022_big_battery, 'Connect+', 55005, 73, $false, $false, "mei 2022");
fillPrice(\%pricesmei2022_big_battery, 'Lounge', 57405, 73, $false, $false, "mei 2022");
        
fillPrice(\%pricesmei2022_big_battery_AWD, 'Connect', 56005, 73, $true, $false, "mei 2022");
fillPrice(\%pricesmei2022_big_battery_AWD, 'Connect+', 59005, 73, $true, $false, "mei 2022");
fillPrice(\%pricesmei2022_big_battery_AWD, 'Lounge', 61405, 73, $true, $false, "mei 2022");

# also take into account korting
fillPrice(\%pricesmei2022_small_battery, 'Style', 44305-300, 58, $false, $false, "mei 2022 E300 korting");
fillPrice(\%pricesmei2022_small_battery, 'Connect', 48405-400, 58, $false, $false, "mei 2022 E400 korting");
fillPrice(\%pricesmei2022_small_battery, 'Connect+', 51405-400, 58, $false, $false, "mei 2022 E400 korting");
fillPrice(\%pricesmei2022_small_battery, 'Lounge', 53805-600, 58, $false, $false, "mei 2022 E600 korting");

fillPrice(\%pricesmei2022_big_battery, 'Style', 47905-900, 73, $false, $false, "mei 2022 E900 korting");
fillPrice(\%pricesmei2022_big_battery, 'Connect', 52005-1000, 73, $false, $false, "mei 2022 E1000 korting");
fillPrice(\%pricesmei2022_big_battery, 'Connect+', 55005-1000, 73, $false, $false, "mei 2022 E1000 korting");
fillPrice(\%pricesmei2022_big_battery, 'Lounge', 57405-1200, 73, $false, $false, "mei 2022 E1200 korting");
        
fillPrice(\%pricesmei2022_big_battery_AWD, 'Connect', 56005-1000, 73, $true, $false, "mei 2022 E1000 korting");
fillPrice(\%pricesmei2022_big_battery_AWD, 'Connect+', 59005-1000, 73, $true, $false, "mei 2022 E1000 korting");
fillPrice(\%pricesmei2022_big_battery_AWD, 'Lounge', 61405-1200, 73, $true, $false, "mei 2022 E1200 korting");

$PRICELISTS{"20220501_58"} = \%pricesmei2022_small_battery;
$PRICELISTS{"20220501_73"} = \%pricesmei2022_big_battery;
$PRICELISTS{"20220501_73AWD"} = \%pricesmei2022_big_battery_AWD;

# model 2022 prijslijst september: 1495 euro duurder dan mei 2022
my %pricessept2022_small_battery;
my %pricessept2022_big_battery;
my %pricessept2022_big_battery_AWD;

fillPrice(\%pricessept2022_small_battery, 'Style', 45800, 58, $false, $false, "sept 2022");
fillPrice(\%pricessept2022_small_battery, 'Connect', 49900, 58, $false, $false, "sept 2022");
fillPrice(\%pricessept2022_small_battery, 'Connect+', 52900, 58, $false, $false, "sept 2022");
fillPrice(\%pricessept2022_small_battery, 'Lounge', 55300, 58, $false, $false, "sept 2022");

fillPrice(\%pricessept2022_big_battery, 'Style', 49400, 73, $false, $false, "sept 2022");
fillPrice(\%pricessept2022_big_battery, 'Connect', 53500, 73, $false, $false, "sept 2022");
fillPrice(\%pricessept2022_big_battery, 'Connect+', 56500, 73, $false, $false, "sept 2022");
fillPrice(\%pricessept2022_big_battery, 'Lounge', 58900, 73, $false, $false, "sept 2022");
        
fillPrice(\%pricessept2022_big_battery_AWD, 'Connect', 57500, 73, $true, $false, "sept 2022");
fillPrice(\%pricessept2022_big_battery_AWD, 'Connect+', 60500, 73, $true, $false, "sept 2022");
fillPrice(\%pricessept2022_big_battery_AWD, 'Lounge', 62900, 73, $true, $false, "sept 2022");

# also take into account korting
fillPrice(\%pricessept2022_small_battery, 'Style', 45800-300, 58, $false, $false, "sept 2022 E300 korting");
fillPrice(\%pricessept2022_small_battery, 'Connect', 49900-400, 58, $false, $false, "sept 2022 E400 korting");
fillPrice(\%pricessept2022_small_battery, 'Connect+', 52900-400, 58, $false, $false, "sept 2022 E400 korting");
fillPrice(\%pricessept2022_small_battery, 'Lounge', 55300-600, 58, $false, $false, "sept 2022 E600 korting");


fillPrice(\%pricessept2022_big_battery, 'Style', 49400-900, 73, $false, $false, "sept 2022 E900 korting");
fillPrice(\%pricessept2022_big_battery, 'Connect', 53500-1000, 73, $false, $false, "sept 2022 E1000 korting");
fillPrice(\%pricessept2022_big_battery, 'Connect+', 56500-1000, 73, $false, $false, "sept 2022 E1000 korting");
fillPrice(\%pricessept2022_big_battery, 'Lounge', 58900-1200, 73, $false, $false, "sept 2022 E1200 korting");
        
fillPrice(\%pricessept2022_big_battery_AWD, 'Connect', 57500-1000, 73, $true, $false, "sept 2022 E1000 korting");
fillPrice(\%pricessept2022_big_battery_AWD, 'Connect+', 60500-1000, 73, $true, $false, "sept 2022 E1000 korting");
fillPrice(\%pricessept2022_big_battery_AWD, 'Lounge', 62900-1200, 73, $true, $false, "sept 2022 E1200 korting");

$PRICELISTS{"20220901_58"} = \%pricessept2022_small_battery;
$PRICELISTS{"20220901_73"} = \%pricessept2022_big_battery;
$PRICELISTS{"20220901_73AWD"} = \%pricessept2022_big_battery_AWD;

#========== model2023 ============================================================
# model 2023 prijslijst maart 2022
my %pricesmaart2022_small_battery_2023;
my %pricesmaart2022_big_battery_2023;
my %pricesmaart2022_big_battery_AWD_2023;

fillPrice(\%pricesmaart2022_small_battery_2023, 'Style', 44305, 58, $false, $true, "maart 2022");
fillPrice(\%pricesmaart2022_small_battery_2023, 'Connect', 48405, 58, $false, $true, "maart 2022");
fillPrice(\%pricesmaart2022_small_battery_2023, 'Connect+', 51405, 58, $false, $true, "maart 2022");
fillPrice(\%pricesmaart2022_small_battery_2023, 'Lounge', 53805, 58, $false, $true, "maart 2022");

fillPrice(\%pricesmaart2022_big_battery_2023, 'Style', 47905, 77, $false, $true, "maart 2022");
fillPrice(\%pricesmaart2022_big_battery_2023, 'Connect', 52005, 77, $false, $true, "maart 2022");
fillPrice(\%pricesmaart2022_big_battery_2023, 'Connect+', 55005, 77, $false, $true, "maart 2022");
fillPrice(\%pricesmaart2022_big_battery_2023, 'Lounge', 57405, 77, $false, $true, "maart 2022");
        
fillPrice(\%pricesmaart2022_big_battery_AWD_2023, 'Connect', 56005, 77, $true, $true, "maart 2022");
fillPrice(\%pricesmaart2022_big_battery_AWD_2023, 'Connect+', 59005, 77, $true, $true, "maart 2022");
fillPrice(\%pricesmaart2022_big_battery_AWD_2023, 'Lounge', 61405, 77, $true, $true, "maart 2022");

$PRICELISTS{"20220301_58_2023"} = \%pricesmaart2022_small_battery_2023;
$PRICELISTS{"20220301_77"} = \%pricesmaart2022_big_battery_2023;
$PRICELISTS{"20220301_77AWD"} = \%pricesmaart2022_big_battery_AWD_2023;

# model 2023 prijslijst mei 2022
my %pricesmei2022_small_battery_2023;
my %pricesmei2022_big_battery_2023;
my %pricesmei2022_big_battery_AWD_2023;

fillPrice(\%pricesmei2022_small_battery_2023, 'Style', 44305, 58, $false, $true, "mei 2022");
fillPrice(\%pricesmei2022_small_battery_2023, 'Connect', 48405, 58, $false, $true, "mei 2022");
fillPrice(\%pricesmei2022_small_battery_2023, 'Connect+', 51405, 58, $false, $true, "mei 2022");
fillPrice(\%pricesmei2022_small_battery_2023, 'Lounge', 53805, 58, $false, $true, "mei 2022");

fillPrice(\%pricesmei2022_big_battery_2023, 'Style', 47905, 77, $false, $true, "mei 2022");
fillPrice(\%pricesmei2022_big_battery_2023, 'Connect', 52005, 77, $false, $true, "mei 2022");
fillPrice(\%pricesmei2022_big_battery_2023, 'Connect+', 55005, 77, $false, $true, "mei 2022");
fillPrice(\%pricesmei2022_big_battery_2023, 'Lounge', 57405, 77, $false, $true, "mei 2022");
        
fillPrice(\%pricesmei2022_big_battery_AWD_2023, 'Connect', 56005, 77, $true, $true, "mei 2022");
fillPrice(\%pricesmei2022_big_battery_AWD_2023, 'Connect+', 59005, 77, $true, $true, "mei 2022");
fillPrice(\%pricesmei2022_big_battery_AWD_2023, 'Lounge', 61405, 77, $true, $true, "mei 2022");

$PRICELISTS{"20220501_58_2023"} = \%pricesmei2022_small_battery_2023;
$PRICELISTS{"20220501_77"} = \%pricesmei2022_big_battery_2023;
$PRICELISTS{"20220501_77AWD"} = \%pricesmei2022_big_battery_AWD_2023;

# model 2023 prijslijst september: 1495 euro duurder dan mei 2022
my %pricessept2022_small_battery_2023;
my %pricessept2022_big_battery_2023;
my %pricessept2022_big_battery_AWD_2023;

fillPrice(\%pricessept2022_small_battery_2023, 'Style', 45800, 58, $false, $true, "sept 2022");
fillPrice(\%pricessept2022_small_battery_2023, 'Connect', 49900, 58, $false, $true, "sept 2022");
fillPrice(\%pricessept2022_small_battery_2023, 'Connect+', 52900, 58, $false, $true, "sept 2022");
fillPrice(\%pricessept2022_small_battery_2023, 'Lounge', 55300, 58, $false, $true, "sept 2022");

fillPrice(\%pricessept2022_big_battery_2023, 'Style', 49400, 77, $false, $true, "sept 2022");
fillPrice(\%pricessept2022_big_battery_2023, 'Connect', 53500, 77, $false, $true, "sept 2022");
fillPrice(\%pricessept2022_big_battery_2023, 'Connect+', 56500, 77, $false, $true, "sept 2022");
fillPrice(\%pricessept2022_big_battery_2023, 'Lounge', 58900, 77, $false, $true, "sept 2022");
        
fillPrice(\%pricessept2022_big_battery_AWD_2023, 'Connect', 57500, 77, $true, $true, "sept 2022");
fillPrice(\%pricessept2022_big_battery_AWD_2023, 'Connect+', 60500, 77, $true, $true, "sept 2022");
fillPrice(\%pricessept2022_big_battery_AWD_2023, 'Lounge', 62900, 77, $true, $true, "sept 2022");

$PRICELISTS{"20220901_58_2023"} = \%pricessept2022_small_battery_2023;
$PRICELISTS{"20220901_77"} = \%pricessept2022_big_battery_2023;
$PRICELISTS{"20220901_77AWD"} = \%pricessept2022_big_battery_AWD_2023;

# model 2023 prijslijst januari 2023: 1400 euro duurder dan september 2022
my %pricesjan2023_small_battery_2023;
my %pricesjan2023_big_battery_2023;
my %pricesjan2023_big_battery_AWD_2023;

fillPrice(\%pricesjan2023_small_battery_2023, 'Style', 47200, 58, $false, $true, "jan 2023");
fillPrice(\%pricesjan2023_small_battery_2023, 'Connect', 51300, 58, $false, $true, "jan 2023");
fillPrice(\%pricesjan2023_small_battery_2023, 'Connect+', 54300, 58, $false, $true, "jan 2023");
fillPrice(\%pricesjan2023_small_battery_2023, 'Lounge', 56700, 58, $false, $true, "jan 2023");

fillPrice(\%pricesjan2023_big_battery_2023, 'Style', 50800, 77, $false, $true, "jan 2023");
fillPrice(\%pricesjan2023_big_battery_2023, 'Connect', 54900, 77, $false, $true, "jan 2023");
fillPrice(\%pricesjan2023_big_battery_2023, 'Connect+', 57900, 77, $false, $true, "jan 2023");
fillPrice(\%pricesjan2023_big_battery_2023, 'Lounge', 60300, 77, $false, $true, "jan 2023");
        
fillPrice(\%pricesjan2023_big_battery_AWD_2023, 'Connect', 58900, 77, $true, $true, "jan 2023");
fillPrice(\%pricesjan2023_big_battery_AWD_2023, 'Connect+', 61900, 77, $true, $true, "jan 2023");
fillPrice(\%pricesjan2023_big_battery_AWD_2023, 'Lounge', 64300, 77, $true, $true, "jan 2023");

$PRICELISTS{"20230101_58_2023"} = \%pricesjan2023_small_battery_2023;
$PRICELISTS{"20230101_77"} = \%pricesjan2023_big_battery_2023;
$PRICELISTS{"20230101_77AWD"} = \%pricesjan2023_big_battery_AWD_2023;

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
open(FILE, "$filename") or die("Cannot open for read: $filename: $!\n");
while (<FILE>) {
    my $currentLine = $_;
    chomp $currentLine; # get rid of newline
    $currentLine =~ s?^.*"kenteken":"??;
    $currentLine =~ s?"\}??;
    $currentLine =~ s?\]??;
    push (@KENTEKENS, $currentLine);
    $KENTEKENS{$currentLine} = 1;
}
close(FILE);

my $opkenteken = @KENTEKENS;

# also add exported known kentekens, if not in list
my %KENTEKENSEXPORTED;
if (not $UPDATE) {
    my $fileexport = "exported.txt";
    open(FILEEXPORT, "$fileexport") or die("Cannot open for read: $fileexport: $!\n");
    while (<FILEEXPORT>) {
        my $currentLine = $_;
        chomp $currentLine; # get rid of newline
        if (not exists $KENTEKENS{$currentLine}) {
            print "Adding $currentLine\n" if $DEBUG;
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
open(MISSINGTXTFILE, "missing.txt") or die("Cannot open for read: missing.txt: $!\n");
foreach (<MISSINGTXTFILE>) {
    my $m = $_;
    chomp $m;
    my $k = substr($m, 0, 6);
    chomp $k;
    next if $k eq '';
    $MISSINGTXT{$k} = $m;
}
close(MISSINGTXTFILE);

my %MISSING;
open(MISSINGFILE, "missing.outfile.txt") or die("Cannot open for read: missing.outfile.txt: $!\n");
foreach (<MISSINGFILE>) {
    my $m = $_;
    chomp $m;
    my $k = substr($m, 0, 6);
    $MISSING{$k} = $m;
    
    my $c = substr($m, 16, 10);
    uc $c;
    chomp $c;
    my $add = substr($k, 0, 1) . substr($k, 4, 2) . "$k          " . $c;
    print "Adding: $add\n" if $DEBUG;
    $registered =  "$registered$add\n";
    print "registered: $registered\n" if $DEBUG;
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
    open(KENTEKENFILE, "$filename") or die("Cannot open for read: $filename: $!\n");
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
        die("Kenteken lengte fout: [$filename],[$kenteken]\n");
    }
    my $date = ${$hash}{'datum_eerste_afgifte_nederland'};
    if ($date eq '') {
        $date = ${$hash}{'datum_eerste_tenaamstelling_in_nederland'}; # changed name 31 maart 2022
    }
    if (length($date) != 8) {
        die("Date lengte fout: [$filename],[$date]\n");
    }
    my $dateToelating = ${$hash}{'datum_eerste_toelating'};
    if (length($dateToelating) != 8) {
        die("Date lengte fout: [$filename],[$dateToelating]\n");
    }
    if ($date ne $dateToelating) {
        print "Import $k: [$dateToelating] [$date]\n" if $DEBUG;
        $geimporteerd++;
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

    my $kleur = ${$hash}{'eerste_kleur'};
    if ($kleur eq '') {
        die("Kleur leeg: [$filename],[$kleur]\n");
    }
    if ($kleur ne 'GROEN' and $kleur ne 'WIT' and $kleur ne 'ZWART' and $kleur ne 'GEEL' and $kleur ne 'GRIJS' and $kleur ne 'BLAUW' and $kleur ne 'BRUIN') { # BRUIN???
        die("Kleur onbekend: [$filename],[$kleur]\n");
    }
    $kleur = sprintf("%-10s", $kleur);
    
    my $prijs = ${$hash}{'catalogusprijs'};
    if ($prijs eq '' and $kenteken ne 'R296FL') {
        die("Prijs leeg: [$filename],[$prijs]\n");
    }
    if (length($prijs) != 5 and $kenteken ne 'N770TS' and $kenteken ne 'R296FL' and $kenteken ne 'R303XF') {
        die("Prijs verkeerd: [$filename],[$prijs]\n");
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
    }
    
    if ($variant eq '') {
        die("Variant leeg: [$filename],[$variant]\n");
    }
    if ($variant ne 'F5E14' and $variant ne 'F5E32' and $variant ne 'F5P41' and $variant ne 'F5E42' and $variant ne 'F5E54' and $variant ne 'F5E62' and $variant ne 'F5E24') {
        die("Variant verkeerd $kenteken: [$filename],[$variant]\n");
    }
    
    if ($uitvoering eq '') {
        die("Uitvoering leeg: [$filename],[$uitvoering]\n");
    }
    if ($uitvoering ne 'E11A11' and $uitvoering ne 'E11B11') {
        die("Uitvoering onbekend: [$filename],[$uitvoering]\n");
    }
    
    if ($typegoedkeuring eq '') {
        die("Typegoedkeuring leeg: [$filename],[$typegoedkeuring]\n");
    }
    if ($typegoedkeuring ne 'e9*2018/858*11054*01' and $typegoedkeuring ne 'e9*2018/858*11054*03' and $typegoedkeuring ne 'e9*2018/858*11054*04') {
        die("Typegoedkeuring verkeerd: [$filename],[$typegoedkeuring]\n");
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
    open(EXPORTEDTXTFILE, ">exported.txt") or die("Cannot open for write: exported.txt: $!\n");
    foreach my $keytxt (sort keys %KENTEKENSEXPORTED) {
        print EXPORTEDTXTFILE "$keytxt\n";
    }
    close(EXPORTEDTXTFILE);
}


open(MISSINGTXTFILE, ">missing.txt") or die("Cannot open for write: missing.txt: $!\n");
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
        print "Adding: $line\n";
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

    foreach my $k (reverse sort { $VARIANTSCOUNT{$a} <=> $VARIANTSCOUNT{$b} } keys %VARIANTSCOUNT) {
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
