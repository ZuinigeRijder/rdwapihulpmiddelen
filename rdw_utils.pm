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
package rdw_utils;
#use diagnostics;
use strict;
use Carp;
use JSON qw( decode_json );     # From CPAN
use Data::Dumper;
use File::Copy;
use Exporter;

use vars qw(@ISA @EXPORT);
@ISA = qw(Exporter);
@EXPORT = qw(fillPrices getVariant getPrintLine executeCommand myDie $DEBUG $true $false $DUMP $COUNT $COUNTTaxi $taxi $COUNTExport $export $COUNT19INCH $COUNT20INCH $COUNTLounge19INCH $COUNTLounge20INCH $COLORMATTE $COLORMETALLIC $COLORMICA $COLORSOLID $COLORMICAPEARL @PRICELISTS_DATES %PRICELISTS %VARIANTSCOUNT %VARIANTSCOUNTNOGNIETOPNAAM);

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
sub fillPrices();

# global variables
our $true=1;
our $false=0;
our $DEBUG=$false;
our $DUMP=$false;
our $COUNT=0;

our $COUNTTaxi = 0;
our $taxi = 'Nee';

our $COUNTExport = 0;
our $export = 'Nee';

our $COUNT19INCH = 0;
our $COUNT20INCH = 0;
our $COUNTLounge19INCH = 0;
our $COUNTLounge20INCH = 0;

our $COLORMATTE = 0;
our $COLORMETALLIC = 0;
our $COLORMICA = 0;
our $COLORSOLID = 0;
our $COLORMICAPEARL = 0;

our @PRICELISTS_DATES = ("20230101", "20220901", "20220501", "20220301", "20210501");
our %PRICELISTS;

our %VARIANTSCOUNT;
our %VARIANTSCOUNTNOGNIETOPNAAM;

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
    if ($foundDelta != 0 and $foundDelta != 9999999) {
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
        
        print("Checking nearest pricelist $kenteken pricelist $pricelist_date for $date\n") if $DEBUG;
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
                    if ($model2023) {
                        $foundVariant = ''; #do assume Atlas White Matte
                    } else {
                        $foundVariant2 = ''; #do not assume Atlas White Matte
                    }
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
    print("clean variant before: [$stripped]\n") if $DEBUG;
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
    print("clean variant after: [$stripped]\n") if $DEBUG;
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


#===============================================================================
# fillPrices
# return %PRICELISTS
#===============================================================================
sub fillPrices() {    
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
    
    return \%PRICELISTS;
}

1;  # don't forget to return a true value from the file
