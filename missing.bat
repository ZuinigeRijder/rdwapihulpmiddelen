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
use JSON qw( decode_json );     # From CPAN
use Data::Dumper;

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
    die("$txt\n\n");
    exit 1;
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
        #if ($date < $pricelist_date) {
        #    print("Skipping pricelist $pricelist_date for $date\n") if $DEBUG;
        #    next; # skip registration dates before prijslist date
        #}
    
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
    if ($date < 20210401 or $date > 20230101) {
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
    
    if (($prijs < 42500 or $prijs > 69000) and $prijs != 72300 and $prijs != 37831) {
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


# pricelists of sept 2022, mei 2022, maart 2022, mei 2021
@PRICELISTS_DATES = ("20220901", "20220501", "20220301", "20210501");

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

fillPrice(\%pricesmaart2022_big_battery, 'Style', 46405-1000, 73, $false, $false, "maart 2022 E1000 korting");
fillPrice(\%pricesmaart2022_big_battery, 'Connect', 50505-1000, 73, $false, $false, "maart 2022 E1000 korting");
fillPrice(\%pricesmaart2022_big_battery, 'Connect+', 53505-1000, 73, $false, $false, "maart 2022 E1000 korting");
fillPrice(\%pricesmaart2022_big_battery, 'Lounge', 55905-1000, 73, $false, $false, "maart 2022 E1000 korting");
        
fillPrice(\%pricemaart2022_big_battery_AWD, 'Connect', 54505-1000, 73, $true, $false, "maart 2022 E1000 korting");
fillPrice(\%pricemaart2022_big_battery_AWD, 'Connect+', 57505-1000, 73, $true, $false, "maart 2022 E1000 korting");
fillPrice(\%pricemaart2022_big_battery_AWD, 'Lounge', 59905-1000, 73, $true, $false, "maart 2022 E1000 korting");

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

fillPrice(\%pricesmei2022_big_battery, 'Style', 47905-1000, 73, $false, $false, "mei 2022 E1000 korting");
fillPrice(\%pricesmei2022_big_battery, 'Connect', 52005-1000, 73, $false, $false, "mei 2022 E1000 korting");
fillPrice(\%pricesmei2022_big_battery, 'Connect+', 55005-1000, 73, $false, $false, "mei 2022 E1000 korting");
fillPrice(\%pricesmei2022_big_battery, 'Lounge', 57405-1000, 73, $false, $false, "mei 2022 E1000 korting");
        
fillPrice(\%pricesmei2022_big_battery_AWD, 'Connect', 56005-1000, 73, $true, $false, "mei 2022 E1000 korting");
fillPrice(\%pricesmei2022_big_battery_AWD, 'Connect+', 59005-1000, 73, $true, $false, "mei 2022 E1000 korting");
fillPrice(\%pricesmei2022_big_battery_AWD, 'Lounge', 61405-1000, 73, $true, $false, "mei 2022 E1000 korting");

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


fillPrice(\%pricessept2022_big_battery, 'Style', 49400-1000, 73, $false, $false, "sept 2022 E1000 korting");
fillPrice(\%pricessept2022_big_battery, 'Connect', 53500-1000, 73, $false, $false, "sept 2022 E1000 korting");
fillPrice(\%pricessept2022_big_battery, 'Connect+', 56500-1000, 73, $false, $false, "sept 2022 E1000 korting");
fillPrice(\%pricessept2022_big_battery, 'Lounge', 58900-1000, 73, $false, $false, "sept 2022 E1000 korting");
        
fillPrice(\%pricessept2022_big_battery_AWD, 'Connect', 57500-1000, 73, $true, $false, "sept 2022 E1000 korting");
fillPrice(\%pricessept2022_big_battery_AWD, 'Connect+', 60500-1000, 73, $true, $false, "sept 2022 E1000 korting");
fillPrice(\%pricessept2022_big_battery_AWD, 'Lounge', 62900-1000, 73, $true, $false, "sept 2022 E1000 korting");

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

my $filename="missing.txt";
print "Processing $filename\n";
my @KENTEKENS;
my %TENAAMGESTELD;
open(FILE, "$filename") or die("Cannot open for read: $filename: $!\n");
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
open(OUTFILE, ">missing.outfile.txt") or die("Cannot open for write: missing.outfile.txt: $!\n");
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
    open(KENTEKENFILE, "$filename") or die("Cannot open for read: $filename: $!\n");
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
        print "Corrected date: $date20" if $DEBUG;
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
        rename 'x.missing', $filename or die "Cannot rename file: $!";
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
