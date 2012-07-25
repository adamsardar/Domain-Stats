#!/usr/bin/env perl

=head1 NAME

StrainsDomArchSummary.pl<.pl>

=head1 USAGE

 StrainsDomArchSummary.pl -gs 'genome strain to study'

example:../StrainsDomArchSummary.pl -gs 'Escherichia coli'

=head1 SYNOPSIS

A script to take a list of genomes (strains or whatever) and output some summary data regarding the domain architectures in common.

This script is not desperately well written, but it'll do. It outputs a whole bunch of directories detailing summary statistics and percentages regarding
superfamiles, domain architectures and supradomains in common.

=head1 AUTHOR

B<Adam Sardar> - I<adam.sardar@bristol.ac.uk>

=head1 COPYRIGHT

Copyright 2011 Gough Group, University of Bristol.

=cut

# Strict Pragmas
#----------------------------------------------------------------------------------------------------------------
use strict;
use warnings;
#use diagnostics;

# Add Local Library to LibPath
#----------------------------------------------------------------------------------------------------------------
use lib "/home/sardar/bin/perl-libs-custom";


# CPAN Includes
#----------------------------------------------------------------------------------------------------------------
=head1 DEPENDANCY
B<Getopt::Long> Used to parse command line options.
B<Pod::Usage> Used for usage and help output.
B<Data::Dumper> Used for debug output.
=cut
use Getopt::Long;                     #Deal with command line options
use Pod::Usage;                       #Print a usage man page from the POD comments after __END__
use Data::Dumper;                     #Allow easy print dumps of datastructures for debugging
#use XML::Simple qw(:strict);          #Load a config file from the local directory
use DBI;
use Supfam::Utils;
use Supfam::SQLFunc;
use POSIX;

# Command Line Options
#----------------------------------------------------------------------------------------------------------------

my $verbose; #Flag for verbose output from command line opts
my $debug;   #As above for debug
my $help;    #Same again but this time should we output the POD man page defined after __END__
my @GenomesOfInterest; #List of SUPERFAMILY genome ids
my $GenomeStub = 'Escherichia coli'; #Used in SQL statement to extract genome codes, unless codes are already given.
my $OutputStub = 'DomainArchanalysis';

#Set command line flags and parameters.
GetOptions("verbose|v!"  => \$verbose,
           "debug|d!"  => \$debug,
           "help|h!" => \$help,
           "genome|g:s" => \@GenomesOfInterest,
           "genomestub|gs:s" => \$GenomeStub,
           "outputstub|o:s" => \$OutputStub,
        ) or die "Fatal Error: Problem parsing command-line ".$!;

#Print out some help if it was asked for or if no arguments were given.
#pod2usage(-exitstatus => 0, -verbose => 2) if $help;

# Main Script Content
#----------------------------------------------------------------------------------------------------------------

#Possible additional functionality - add genomes from a csv file

my $dbh = dbConnect(); 
my $sth;

mkdir("./GenomeAnalysis");
mkdir("./GenomeAnalysis/DomainCombinations");
mkdir("./GenomeAnalysis/Superfamilies");
mkdir("./GenomeAnalysis/SupradomainCombinations");
mkdir("./GenomeAnalysis/SFFamilies");

unless(scalar(@GenomesOfInterest)){
	
	$sth=$dbh->prepare("SELECT genome.genome FROM genome WHERE name LIKE ?;");
	$sth->execute("%$GenomeStub%") or die $?;
	
	while(my $genomeentry = $sth->fetchrow_array()){ push(@GenomesOfInterest,$genomeentry);};

	$sth->finish;
};

#######Study domain combinations

my $lencombquery = join ("' or len_comb.genome='", @GenomesOfInterest); $lencombquery = "(len_comb.genome='$lencombquery')";# An ugly way to make the query many genomes

my $GenomeCombHash = {}; #Hash structure: $Hash->{genome}{comb}=frequency
my $CombID2ArchDictionary = {};

$sth=$dbh->prepare("SELECT genome, comb_id, comb FROM len_comb WHERE $lencombquery;");
$sth->execute();

while(my ($genome,$comb_id,$comb) = $sth->fetchrow_array()){
	
	$GenomeCombHash->{$genome}={} unless(exists($GenomeCombHash->{$genome}));
	$GenomeCombHash->{$genome}{$comb_id}++;
	
	$CombID2ArchDictionary->{$comb_id}=$comb unless(exists($CombID2ArchDictionary->{$comb_id}));
}

open SUMMARY, ">./GenomeAnalysis/DomainCombinations/$OutputStub-Combs-Summary.csv";

print SUMMARY "Genome\t Number of distinct Archs \n";

foreach my $genome_entry (keys(%$GenomeCombHash)){
	
	my @DistinctCombs = keys(%{$GenomeCombHash->{$genome_entry}});
	print SUMMARY $genome_entry."\t".scalar(@DistinctCombs)."\n";
}

close SUMMARY;
# dump out a summary of the comb data


#All against all unique Domain Architectures

my $AllVsAllUniqueSfs = {}; #A hash of the number of unique superfamilies relative to another genome
my $AllVsAllIntersectionSfs = {}; #A hash of the number of unique superfamilies relative to another genome

my $AllVsAllUniqueSfsRatio = {}; 
my $AllVsAllIntersectionSfsRatio = {}; 



foreach my $genome_entry_A (keys(%$GenomeCombHash)){
	
	my @CombIDsA = keys(%{$GenomeCombHash->{$genome_entry_A}});
	$AllVsAllUniqueSfs->{$genome_entry_A} = {};
	$AllVsAllIntersectionSfs->{$genome_entry_A} = {};
	
	foreach my $genome_entry_B (keys(%$GenomeCombHash)){
	
		my @CombIDsB = keys(%{$GenomeCombHash->{$genome_entry_B}});
		my ($Union,$Intersection,$ListAExclusive,$ListBExclusive) = IntUnDiff(\@CombIDsA,\@CombIDsB);
		$AllVsAllUniqueSfs->{$genome_entry_A}{$genome_entry_B} = scalar(@$ListAExclusive);
		$AllVsAllIntersectionSfs->{$genome_entry_A}{$genome_entry_B} = scalar(@$Intersection);
		
		$AllVsAllUniqueSfsRatio->{$genome_entry_A}{$genome_entry_B} = ceil(100*scalar(@$ListAExclusive)/scalar(@CombIDsA));
		$AllVsAllIntersectionSfsRatio->{$genome_entry_A}{$genome_entry_B} = ceil(100*scalar(@$Intersection)/scalar(@CombIDsA));
	}
}

TabSepFile([keys(%$AllVsAllUniqueSfs)],$AllVsAllUniqueSfs,"./GenomeAnalysis/DomainCombinations/$OutputStub-Combs-AllVsAllUnique.dat",undef,0);
TabSepFile([keys(%$AllVsAllIntersectionSfs)],$AllVsAllIntersectionSfs,"./GenomeAnalysis/DomainCombinations/$OutputStub-Combs-AllVsAllIntersection.dat",undef,0);

TabSepFile([keys(%$AllVsAllUniqueSfsRatio)],$AllVsAllUniqueSfsRatio,"./GenomeAnalysis/DomainCombinations/$OutputStub-ratio-Combs-AllVsAllUnique.dat",undef,0);
TabSepFile([keys(%$AllVsAllIntersectionSfsRatio)],$AllVsAllIntersectionSfsRatio,"./GenomeAnalysis/DomainCombinations/$OutputStub-ratio-Combs-AllVsAllIntersection.dat",undef,0);


# Dump $AllVsAllUniqueSfs out to a tab seperated file



##Gapless Dom Arches

#All against all unique Domain Architectures

my $AllVsAllGaplessUniqueSfs = {}; #A hash of the number of unique superfamilies relative to another genome
my $AllVsAllGaplessIntersectionSfs = {}; #A hash of the number of unique superfamilies relative to another genome

my $AllVsAllGaplessUniqueSfsRatio = {}; #A hash of the number of unique superfamilies relative to another genome
my $AllVsAllGaplessIntersectionSfsRatio = {}; #A hash of the number of unique superfamilies relative to another genome

foreach my $genome_entry_A (keys(%$GenomeCombHash)){
	
	my $UniqueSFsA = {};
	my @GaplessArchs = map{join(',',(grep{$_ !~ /_gap_/}(split(',',$_))))}@{$CombID2ArchDictionary}{keys(%{$GenomeCombHash->{$genome_entry_A}})};
	map{$UniqueSFsA->{$_}++}@GaplessArchs;
	my @CombsA = keys(%$UniqueSFsA);
	
	$AllVsAllGaplessUniqueSfs->{$genome_entry_A} = {};
	$AllVsAllGaplessIntersectionSfs->{$genome_entry_A} = {};
	
	foreach my $genome_entry_B (keys(%$GenomeCombHash)){
		
		my $UniqueSFsB = {};
		my @GaplessArchs = map{join(',',(grep{$_ !~ /_gap_/}(split(',',$_))))}@{$CombID2ArchDictionary}{keys(%{$GenomeCombHash->{$genome_entry_B}})};
		map{$UniqueSFsB->{$_}++}@GaplessArchs;
		
		my @CombsB = keys(%$UniqueSFsB);
		
		my ($Union,$Intersection,$ListAExclusive,$ListBExclusive) = IntUnDiff(\@CombsA,\@CombsB);
		$AllVsAllGaplessUniqueSfs->{$genome_entry_A}{$genome_entry_B} = scalar(@$ListAExclusive);
		$AllVsAllGaplessIntersectionSfs->{$genome_entry_A}{$genome_entry_B} = scalar(@$Intersection);
		
		$AllVsAllGaplessUniqueSfsRatio->{$genome_entry_A}{$genome_entry_B} = ceil(100*scalar(@$ListAExclusive)/scalar(@CombsA));
		$AllVsAllGaplessIntersectionSfsRatio->{$genome_entry_A}{$genome_entry_B} = ceil(100*scalar(@$Intersection)/scalar(@CombsA));	
	}
}

TabSepFile([keys(%$AllVsAllGaplessUniqueSfs)],$AllVsAllGaplessUniqueSfs,"./GenomeAnalysis/DomainCombinations/$OutputStub-Combs-Gapless-AllVsAllUnique.dat",undef,0);
TabSepFile([keys(%$AllVsAllGaplessIntersectionSfs)],$AllVsAllGaplessIntersectionSfs,"./GenomeAnalysis/DomainCombinations/$OutputStub-Combs-Gapless-AllVsAllIntersection.dat",undef,0);

TabSepFile([keys(%$AllVsAllGaplessUniqueSfsRatio)],$AllVsAllGaplessUniqueSfsRatio,"./GenomeAnalysis/DomainCombinations/$OutputStub-ratio-Combs-Gapless-AllVsAllUnique.dat",undef,0);
TabSepFile([keys(%$AllVsAllGaplessIntersectionSfsRatio)],$AllVsAllGaplessIntersectionSfsRatio,"./GenomeAnalysis/DomainCombinations/$OutputStub-ratio-Combs-Gapless-AllVsAllIntersection.dat",undef,0);

# Dump $AllVsAllUniqueSfs out to a tab seperated file


#######Study Supradomains

my $lensupraquery = join ("' or len_supra.genome='", @GenomesOfInterest); $lensupraquery = "(len_supra.genome='$lensupraquery')";# An ugly way to make the query many genomes

my $GenomeSupraHash = {}; #Hash structure: $Hash->{genome}{comb}=frequency

$sth=$dbh->prepare("SELECT len_supra.genome, len_supra.supra_id, comb_index.comb FROM len_supra JOIN comb_index ON len_supra.supra_id = comb_index.id WHERE $lensupraquery;");
$sth->execute();

while(my ($genome,$supra_id,$supradomain) = $sth->fetchrow_array()){
	
	$GenomeSupraHash->{$genome}={} unless(exists($GenomeCombHash->{$genome}));
	$GenomeSupraHash->{$genome}{$supra_id}++;
	
	$CombID2ArchDictionary->{$supra_id}=$supradomain unless(exists($CombID2ArchDictionary->{$supra_id})); ## Supradomains are combs after all, so no need for a seperate hash
}

open SUMMARYSUPRA, ">./GenomeAnalysis/SupradomainCombinations/$OutputStub-Supra-Summary.csv";

print SUMMARYSUPRA "Genome\t Number of distinct SupraDomainss \n";

foreach my $genome_entry (keys(%$GenomeSupraHash)){
	
	my @DistinctSupras = keys(%{$GenomeSupraHash->{$genome_entry}});
	print SUMMARYSUPRA $genome_entry."\t".scalar(@DistinctSupras)."\n";
}

close SUMMARYSUPRA;
# dump out a summary of the comb data

#All against all unique supradomains

my $AllVsAllUniqueSupras = {}; #A hash of the number of unique superfamilies relative to another genome
my $AllVsAllIntersectSupras ={};

my $AllVsAllUniqueSuprasRatio = {};
my $AllVsAllIntersectSuprasRatio ={};

foreach my $genome_entry_A (keys(%$GenomeSupraHash)){
	
	my @SupraIDsA = keys(%{$GenomeSupraHash->{$genome_entry_A}});
	$AllVsAllUniqueSupras->{$genome_entry_A} = {};
	
	
	foreach my $genome_entry_B (keys(%$GenomeSupraHash)){
	
		my @SupraIDsB = keys(%{$GenomeSupraHash->{$genome_entry_B}});
		my ($Union,$Intersection,$ListAExclusive,$ListBExclusive) = IntUnDiff(\@SupraIDsA,\@SupraIDsB);
		$AllVsAllUniqueSupras->{$genome_entry_A}{$genome_entry_B} = scalar(@$ListAExclusive);
		$AllVsAllIntersectSupras->{$genome_entry_A}{$genome_entry_B} = scalar(@$Intersection);
		
		$AllVsAllUniqueSuprasRatio->{$genome_entry_A}{$genome_entry_B} = ceil(100*scalar(@$ListAExclusive)/scalar(@SupraIDsA));
		$AllVsAllIntersectSuprasRatio->{$genome_entry_A}{$genome_entry_B} = ceil(100*scalar(@$Intersection)/scalar(@SupraIDsA));
	}
}

TabSepFile([keys(%$AllVsAllUniqueSupras)],$AllVsAllUniqueSupras,"./GenomeAnalysis/SupradomainCombinations/$OutputStub-Supras-AllVsAll.dat",undef,0);
TabSepFile([keys(%$AllVsAllUniqueSupras)],$AllVsAllIntersectSupras,"./GenomeAnalysis/SupradomainCombinations/$OutputStub-Supras-AllVsAllIntersect.dat",undef,0);

TabSepFile([keys(%$AllVsAllUniqueSuprasRatio)],$AllVsAllUniqueSuprasRatio,"./GenomeAnalysis/SupradomainCombinations/$OutputStub-ratio-Supras-AllVsAll.dat",undef,0);
TabSepFile([keys(%$AllVsAllIntersectSuprasRatio)],$AllVsAllIntersectSuprasRatio,"./GenomeAnalysis/SupradomainCombinations/$OutputStub-ratio-Supras-AllVsAllIntersect.dat",undef,0);

# Dump $AllVsAllUniqueSfs out to a csv

###Gapless supradomains - so as to prevent A,_gap_,B being treated seperately to A,B

my $AllVsAllGaplessUniqueSupras = {}; #A hash of the number of unique superfamilies relative to another genome
my $AllVsAllGaplessIntersectSupras = {}; #A hash of the number of unique superfamilies relative to another genome

my $AllVsAllGaplessUniqueSuprasRatio = {}; #A hash of the number of unique superfamilies relative to another genome
my $AllVsAllGaplessIntersectSuprasRatio = {}; #A hash of the number of unique superfamilies relative to another genome


foreach my $genome_entry_A (keys(%$GenomeSupraHash)){
	
	my $UniqueSuprasA = {};
	map{$UniqueSuprasA->{$_}++}map{join(',',(grep{$_ !~ /_gap_/}(split(',',$_))))}@{$CombID2ArchDictionary}{keys(%{$GenomeSupraHash->{$genome_entry_A}})};
	my @SuprasA = keys(%$UniqueSuprasA);
	#It does turn my stomach a little seeing the above nested map and grep. It's quite simple though - taking a domain architecture like A,B,_gap_,C it rips out all the _gap_ assignements (if any)
	
	$AllVsAllGaplessUniqueSupras->{$genome_entry_A} = {};
	$AllVsAllGaplessIntersectSupras->{$genome_entry_A} = {};
	
	#print join("\t",@SuprasA);
	#print "\n";
		
	foreach my $genome_entry_B (keys(%$GenomeSupraHash)){
		
		my $UniqueSuprasB = {};
		map{$UniqueSuprasB->{$_}++}map{join(',',(grep{$_ !~ /_gap_/}(split(',',$_))))}@{$CombID2ArchDictionary}{keys(%{$GenomeSupraHash->{$genome_entry_B}})};
		my @SuprasB = keys(%$UniqueSuprasB);
		
		my ($Union,$Intersection,$ListAExclusive,$ListBExclusive) = IntUnDiff(\@SuprasA,\@SuprasB);
		$AllVsAllGaplessUniqueSupras->{$genome_entry_A}{$genome_entry_B} = scalar(@$ListAExclusive);
		$AllVsAllGaplessIntersectSupras->{$genome_entry_A}{$genome_entry_B} = scalar(@$Intersection);
		
		$AllVsAllGaplessUniqueSuprasRatio->{$genome_entry_A}{$genome_entry_B} = ceil(100*scalar(@$ListAExclusive)/scalar(@SuprasA));
		$AllVsAllGaplessIntersectSuprasRatio->{$genome_entry_A}{$genome_entry_B} = ceil(100*scalar(@$Intersection)/scalar(@SuprasA));
	}
}

TabSepFile([keys(%$AllVsAllGaplessUniqueSupras)],$AllVsAllGaplessUniqueSupras,"./GenomeAnalysis/SupradomainCombinations/$OutputStub-Supras-Gapless-AllVsAllUnique.dat",undef,0);
TabSepFile([keys(%$AllVsAllGaplessIntersectSupras)],$AllVsAllGaplessIntersectSupras,"./GenomeAnalysis/SupradomainCombinations/$OutputStub-Supras-Gapless-AllVsAllIntersect.dat",undef,0);

TabSepFile([keys(%$AllVsAllGaplessUniqueSuprasRatio)],$AllVsAllGaplessUniqueSuprasRatio,"./GenomeAnalysis/SupradomainCombinations/$OutputStub-Ratio-Supras-Gapless-AllVsAllUnique.dat",undef,0);
TabSepFile([keys(%$AllVsAllGaplessIntersectSuprasRatio)],$AllVsAllGaplessIntersectSuprasRatio,"./GenomeAnalysis/SupradomainCombinations/$OutputStub-Ratio-Supras-Gapless-AllVsAllIntersect.dat",undef,0);


##### Analyse superfamily content (i.e. each of the assignmenets within a domain architecture)

open SFSUMMARY, ">./GenomeAnalysis/Superfamilies/$OutputStub-Combs-Summary.csv";

print SFSUMMARY "Genome\t Number of distinct SFs \n";

foreach my $genome_entry (keys(%$GenomeCombHash)){
	
	my $SFs = {};
	map{$SFs->{$_}++}map{split(',',$_)}(@{$CombID2ArchDictionary}{(keys(%{$GenomeCombHash->{$genome_entry}}))});
	my @DistinctSFs = keys(%$SFs);
	print SFSUMMARY $genome_entry."\t".scalar(@DistinctSFs)."\n";
}

close SFSUMMARY;
# dump out a summary of the comb data


#All against all unique Domain Architectures

my $AllVsAllUniqueSupFams = {}; #A hash of the number of unique superfamilies relative to another genome
my $AllVsAllIntersectionSupFams = {}; #A hash of the number of unique superfamilies relative to another genome

my $AllVsAllUniqueSupFamsRatios= {}; 
my $AllVsAllIntersectionSupFamsRatios = {}; 

foreach my $genome_entry_A (keys(%$GenomeCombHash)){
	
	my $SFsA = {};
	map{$SFsA->{$_}++}map{split(',',$_)}@{$CombID2ArchDictionary}{keys(%{$GenomeCombHash->{$genome_entry_A}})};
	my @UniqueSFsA = keys(%$SFsA);
	$AllVsAllUniqueSupFams->{$genome_entry_A} = {};
	$AllVsAllIntersectionSupFams->{$genome_entry_A} = {};
	
	foreach my $genome_entry_B (keys(%$GenomeCombHash)){
	
		my $SFsB = {};
		map{$SFsB->{$_}++}map{split(',',$_)}@{$CombID2ArchDictionary}{keys(%{$GenomeCombHash->{$genome_entry_B}})};
		my @UniqueSFsB = keys(%$SFsB);
		
		my ($Union,$Intersection,$ListAExclusive,$ListBExclusive) = IntUnDiff(\@UniqueSFsA,\@UniqueSFsB);
		$AllVsAllUniqueSupFams->{$genome_entry_A}{$genome_entry_B} = scalar(@$ListAExclusive);
		$AllVsAllIntersectionSupFams->{$genome_entry_A}{$genome_entry_B} = scalar(@$Intersection);
	
		$AllVsAllUniqueSupFamsRatios->{$genome_entry_A}{$genome_entry_B} = ceil(100*scalar(@$ListAExclusive)/scalar(@UniqueSFsA));
		$AllVsAllIntersectionSupFamsRatios->{$genome_entry_A}{$genome_entry_B} = ceil(100*scalar(@$Intersection)/scalar(@UniqueSFsA));
	
	}
}

TabSepFile([keys(%$AllVsAllUniqueSupFams)],$AllVsAllUniqueSupFams,"./GenomeAnalysis/Superfamilies/$OutputStub-SFs-AllVsAllUnique.dat",undef,0);
TabSepFile([keys(%$AllVsAllIntersectionSupFams)],$AllVsAllIntersectionSupFams,"./GenomeAnalysis/Superfamilies/$OutputStub-SFs-AllVsAllIntersection.dat",undef,0);

TabSepFile([keys(%$AllVsAllUniqueSupFamsRatios)],$AllVsAllUniqueSupFamsRatios,"./GenomeAnalysis/Superfamilies/$OutputStub-Ratio-SFs-AllVsAllUnique.dat",undef,0);
TabSepFile([keys(%$AllVsAllIntersectionSupFamsRatios)],$AllVsAllIntersectionSupFamsRatios,"./GenomeAnalysis/Superfamilies/$OutputStub-Ratio-SFs-AllVsAllIntersection.dat",undef,0);


# Dump $AllVsAllUniqueSfs out to a tab seperated file





########

#######Study domain combinations

my $lenfamquery = join ("' or len_family.genome='", @GenomesOfInterest); $lenfamquery = "(len_family.genome='$lenfamquery')";# An ugly way to make the query many genomes

my $GenomeFamHash = {}; #Hash structure: $Hash->{genome}{comb}=frequency

$sth=$dbh->prepare("SELECT genome,fa FROM len_family WHERE $lenfamquery;");
$sth->execute();

while(my ($genome,$family) = $sth->fetchrow_array()){
	
	$GenomeFamHash->{$genome}={} unless(exists($GenomeCombHash->{$genome}));
	$GenomeFamHash->{$genome}{$family}++;
}

open SUMMARYFAM, ">./GenomeAnalysis/SFFamilies/Fams-Summary.csv";

print SUMMARYFAM "Genome\t Number of distinct families \n";

foreach my $genome_entry (keys(%$GenomeCombHash)){
	
	my @DistinctFams = keys(%{$GenomeFamHash->{$genome_entry}});
	print SUMMARYFAM $genome_entry."\t".scalar(@DistinctFams)."\n";
}

close SUMMARYFAM;
# dump out a summary of the comb data


#All against all unique Domain Architectures

my $AllVsAllUniqueFams = {}; #A hash of the number of unique superfamilies relative to another genome
my $AllVsAllIntersectionFams = {}; #A hash of the number of unique superfamilies relative to another genome

my $AllVsAllUniqueFamsRatio = {}; 
my $AllVsAllIntersectionFamsRatio = {}; 


foreach my $genome_entry_A (keys(%$GenomeCombHash)){
	
	my @FamsA = keys(%{$GenomeFamHash->{$genome_entry_A}});
	$AllVsAllUniqueFams->{$genome_entry_A} = {};
	$AllVsAllIntersectionFams->{$genome_entry_A} = {};
	
	foreach my $genome_entry_B (keys(%$GenomeCombHash)){
	
		my @FamsB = keys(%{$GenomeFamHash->{$genome_entry_B}});
		my ($Union,$Intersection,$ListAExclusive,$ListBExclusive) = IntUnDiff(\@FamsA,\@FamsB);
		$AllVsAllUniqueFams->{$genome_entry_A}{$genome_entry_B} = scalar(@$ListAExclusive);
		$AllVsAllIntersectionFams->{$genome_entry_A}{$genome_entry_B} = scalar(@$Intersection);
		
		$AllVsAllUniqueFamsRatio->{$genome_entry_A}{$genome_entry_B} = ceil(100*scalar(@$ListAExclusive)/scalar(@FamsA));
		$AllVsAllIntersectionFamsRatio->{$genome_entry_A}{$genome_entry_B} = ceil(100*scalar(@$Intersection)/scalar(@FamsA));
	}
}

TabSepFile([keys(%$AllVsAllUniqueFams)],$AllVsAllUniqueFams,"./GenomeAnalysis/SFFamilies/Fams-AllVsAllUnique.dat",undef,0);
TabSepFile([keys(%$AllVsAllIntersectionFams)],$AllVsAllIntersectionFams,"./GenomeAnalysis/SFFamilies/Fams-AllVsAllIntersection.dat",undef,0);

TabSepFile([keys(%$AllVsAllUniqueFamsRatio)],$AllVsAllUniqueFamsRatio,"./GenomeAnalysis/SFFamilies/Ratio-Fams-AllVsAllUnique.dat",undef,0);
TabSepFile([keys(%$AllVsAllIntersectionFamsRatio)],$AllVsAllIntersectionFamsRatio,"./GenomeAnalysis/SFFamilies/Ratio-Fams-AllVsAllIntersection.dat",undef,0);


# Dump $AllVsAllUniqueSfs out to a tab seperated file







__END__