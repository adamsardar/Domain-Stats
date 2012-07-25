#! /usr/bin/perl -w
# Strict Pragmas
use lib "/home/sardar/workspace/Oates/lib/";

#----------------------------------------------------------------------------------------------------------------
use strict;
use warnings;
#use diagnostics;
use Supfam::SQLFunc;
use Supfam::DomainCombs;
use Supfam::TreeFuncs;


# CPAN Includes
#----------------------------------------------------------------------------------------------------------------
use Getopt::Long;                     #Deal with command line options
use Pod::Usage;                       #Print a usage man page from the POD comments after __END__
use Data::Dumper;                     #Allow easy print dumps of datastructures for debugging
#use XML::Simple qw(:strict);          #Load a config file from the local directory
use DBI;
use Supfam::Utils;
use Supfam::TreeFuncs;

my $verbose; #Flag for verbose output from command line opts
my $debug;   #As above for debug
my $help;    #Same again but this time should we output the POD man page defined after __END__
my $OutputFilename = 'vlSuperFamiliesByViralDistinction.dat';
my $InputFile;

my $CompleteCombsOnly = 0; # Exclude domain combinations including _gap_?

#Set command line flags and parameters.
GetOptions("verbose|v!"  => \$verbose,
           "debug|d!"  => \$debug,
           "help|h!" => \$help,
           "output|o:s" => \$OutputFilename,
        ) or die "Fatal Error: Problem parsing command-line ".$!;

#Get other command line arguments that weren't optional flags.
my ($N)= @ARGV;

my $NCBIgenome = 'vl'; #This is the metagenome that superfamily uses for all NCBI viral proteins etc.
#Usage = ./ViralSFByTaxonNCBI

my $Viruses_id = 10239; #This is the taxon_id corresponding to Viruses in the NCBI tree. The direct children of this node will be used to seperate the data in the output file 

my $SpeciesCombs = {};
#Strucutre of hash: NCBI species name => [list of domain combinationss]

if(-e './.NCBIvlSpeciesComb.dat'){
	$SpeciesCombs = EasyUnDump('./.NCBIvlSpeciesComb.dat');
}else{
	splitIntoNCBISpeciesCombs($NCBIgenome, $SpeciesCombs);
	EasyDump('./.NCBIvlSpeciesComb.dat',$SpeciesCombs);
} 

my $dbh = dbConnect();
my $sth;
        
my $TaxIDs_SFs = {};
#This will be a hash detailing TaxonIDs and the corresponding superfamilies. Structure: TaxID => [list of unique SFs]

foreach my $ViralSpecie (keys(%$SpeciesCombs)){
	
	$sth = $dbh->prepare_cached("SELECT taxon_id FROM ncbi_names WHERE name = ?") or die "Can't get a taxon_id for the current species name $ViralSpecie";
    $sth->execute($ViralSpecie);
    
	my $TaxID = $sth->fetchrow_array();
	die "More SQL lines outputted than expected $sth->fetchrow_array() from $ViralSpecie" if ($sth->rows != 1);
	#There should only be one line of output, so the if statement should give false
	
	my $Superfamilies = {};
	#A simple hash count of SF=>no. times observer
	my @Combs = @{$SpeciesCombs->{$ViralSpecie}};

		foreach my $comb (@Combs){
				
				unless($comb =~ /_gap_/ && $CompleteCombsOnly){
				
					my $query = $dbh->prepare_cached("SELECT sf FROM ass JOIN comb ON ass.protein=comb.protein WHERE comb = ?") or die;	    			
	    		
	    			$query->execute($comb);
					
					my $SFClass = $query->fetchrow_array();
					$query->finish;
					
					$Superfamilies->{$SFClass}++;			
				}
		}	
		
	#die 'Multiple species names giving the same TaxID - unexpected behaviour!' if ($TaxIDs_SFs->{$TaxID});	
	#You could easily have two species giving the same species due to alternative names in the ncbi_names table
	
	my $Lineage = CalculateLineage('',$TaxID,$Viruses_id, $dbh);
	
	my @SupFams = keys(%$Superfamilies);

	unless (scalar(@SupFams) == 1 && $SupFams[0] =~ /\-/){
	@SupFams = grep(/[a-z]{1}\./, @SupFams);
	}else{
	$SupFams[0] = 0;
	}
	
	$TaxIDs_SFs->{$TaxID}= [$Lineage,[sort(@SupFams)]];	
	
	$sth -> finish;
}

$sth = $dbh->prepare_cached("SELECT name,left_id,right_id FROM ncbi_taxonomy WHERE parent_id = ?");
$sth->execute($Viruses_id);


open OUTPUT, ">".$OutputFilename or die "Can't open output file!";

my $No_Of_Species_Total = keys(%$TaxIDs_SFs);

	while(my($Distinction,$left_id,$right_id) = $sth->fetchrow_array()){
		
		my $query = $dbh->prepare_cached("SELECT taxon_id FROM ncbi_taxonomy WHERE left_id > ? AND right_id < ?;");
		$query->execute($left_id,$right_id);
		
			print OUTPUT "\n".'>'.$Distinction."\n\n";
		
			while(my ($CladeSpeciesID) = $query->fetchrow_array()){
				
				if(exists($TaxIDs_SFs->{$CladeSpeciesID})){
			
					my $SFsInSpecie = join(',',@{$TaxIDs_SFs->{$CladeSpeciesID}[1]});
					my $TaxLineage = $TaxIDs_SFs->{$CladeSpeciesID}[0];
					
					$SFsInSpecie  = 0 unless(exists($TaxIDs_SFs->{$CladeSpeciesID}[1][0]));
					
					print OUTPUT $CladeSpeciesID."\t".$TaxLineage."\t".$SFsInSpecie."\n";
					
					delete $TaxIDs_SFs->{$CladeSpeciesID};
				}
			}
			
$query-> finish;
	}
	
$sth -> finish;

my $No_Of_Species_Unassigned = keys(%$TaxIDs_SFs);

print OUTPUT "\n>Viral Species Not Classified Under Any Of the Viral Distinctions Above But Still In Genome Set $NCBIgenome.\n";
	
	foreach my $unassigned (keys(%$TaxIDs_SFs)){
		
		my $SupFamsInSpecie = join(',',@{$TaxIDs_SFs->{$unassigned}[1]});
		my $TaxonomyLineage = $TaxIDs_SFs->{$unassigned}[0];
		
		print OUTPUT $unassigned."\t".$TaxonomyLineage."\t".$SupFamsInSpecie."\n";	
	}
	
close OUTPUT;


__END__

=head1 NAME

SplitByNCBIGenome.pl

=head1 DESCRIPTION

An extremely specific script, this is to collect superfamily information regarding the 'vl' metagenome in SUPERFAMILY. This is a collection of all viral instances in the NCBI dataset.

The output is a list of all viral instances in SUPERFAMILY, their taxon_ids, thier full taxonomy and a list of the superfamilies contained within. This list is broken down by viral classification
(ssRNA, dsDNA etc), taken from the children nodes of the Viruses node in the NCBI taxonomy tree.

=head1 USAGE

ViralSFOfvlInsuperfamily.pl

=head1 DEPENDANCY

B<Data::Dumper> Used for debug output.
B<Supfam::SQLFunc> Useful SUPERFAMILY Functions
B<Supfam::Utils> Function such as Easydump
B<Supfam::TreeFuncs> Tree parsing functions and operations

=head1 AUTHOR

Adam Sardar - adam.sardar@bris.ac.uk

=head1 HISTORY

25.01.2011 Initial creation of script
27.03.2011 Modification of script so that it will output  (HMM model) sf ids rather than scop superfamiliy ids.

=cut