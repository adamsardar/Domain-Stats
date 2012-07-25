#! /usr/bin/perl -w
# Strict Pragmas

use lib "/home/sardar/bin/perl-libs-custom/";

=head1 NAME

Viral_DomArch_Plus_Families.pl

=head1 DESCRIPTION

An extremely specific script, this is to collect superfamily information regarding the 'vl' metagenome in SUPERFAMILY. This is a collection of all viral instances in the NCBI dataset.

The output is a list of all viral instances in NCBI (rows) with abundance data of each domain architecture in SF (file 1) and abundance data for each family (file 2)

=head1 USAGE

Example:

Viral_DomArch_Plus_Families.pl

=head1 DEPENDANCY

B<Data::Dumper> Used for debug output.
B<Supfam::SQLFunc> Useful SUPERFAMILY Functions
B<Supfam::Utils> Function such as Easydumps
B<Supfam::DomainCombs> Seclect functions for extracting per species genome content from SF

=head1 AUTHOR

Adam Sardar - adam.sardar@bris.ac.uk

=head1 HISTORY

See bazaar documentation

=cut


#----------------------------------------------------------------------------------------------------------------
use strict;
use warnings;

use Supfam::Utils;
use Supfam::SQLFunc;
use Supfam::DomainCombs;

# CPAN Includes
#----------------------------------------------------------------------------------------------------------------
use Getopt::Long;                     #Deal with command line options
use Pod::Usage;                       #Print a usage man page from the POD comments after __END__
use Data::Dumper;                     #Allow easy print dumps of datastructures for debugging

my $verbose; #Flag for verbose output from command line opts
my $debug;   #As above for debug
my $help;    #Same again but this time should we output the POD man page
my $OutputFilename = 'NCBIViruses';
my $InputFile;

my $CompleteCombsOnly = 0; # Exclude domain combinations including _gap_? 1 = true

#Set command line flags and parameters.
GetOptions("verbose|v!"  => \$verbose,
           "debug|d!"  => \$debug,
           "help|h!" => \$help,
           "output|o:s" => \$OutputFilename,
        ) or die "Fatal Error: Problem parsing command-line ".$!;

#Get other command line arguments that weren't optional flags.
my ($N)= @ARGV;

my $NCBIgenome = 'vl'; #This is the metagenome that superfamily uses for all viral proteins etc.

#SpeciesCombs

my $SpeciesCombs = {};
#Strucutre of hash: {species => {protein_comb_ids => abundance}}. Function below operates on supplied hash
my $TotalCombsInDataset = splitIntoNCBISpeciesCombsAbundance($NCBIgenome, $SpeciesCombs);

#SpeciesFams

my $SpeciesFams = {};
#Strucutre of hash: {species => {protein_family_ids => abundance}}. Function below operates on supplied hash
my $TotalFamsInDataset = splitIntoNCBISpeciesFamsAbundance($NCBIgenome, $SpeciesFams);

#Output Tab seperated files

my @Families = keys(%$TotalFamsInDataset); #Fields in output file

EasyDump("Families.dat",\@Families);

CommaSepFile(\@Families,$SpeciesFams,"FamAbundanceIn".$OutputFilename,$TotalFamsInDataset,'0');

my @CombIds = keys(%$TotalCombsInDataset); #Fields in output file
CommaSepFile(\@CombIds,$SpeciesCombs,"CombAbundanceIn".$OutputFilename,$TotalCombsInDataset,'0');


__END__

