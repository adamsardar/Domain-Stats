#! /usr/bin/perl -w
# Strict Pragmas
use lib "/home/sardar/bin/perl-libs-custom";

#----------------------------------------------------------------------------------------------------------------
use strict;
use warnings;
use Supfam::SQLFunc;
use Supfam::DomainCombs;


# CPAN Includes
#----------------------------------------------------------------------------------------------------------------
use Getopt::Long;                     #Deal with command line options
use Pod::Usage;                       #Print a usage man page from the POD comments after __END__
use Data::Dumper;                     #Allow easy print dumps of datastructures for debugging
#use XML::Simple qw(:strict);          #Load a config file from the local directory
use DBI;

my $verbose; #Flag for verbose output from command line opts
my $debug;   #As above for debug
my $help;    #Same again but this time should we output the POD man page defined after __END__
my $OutputFilename = 'NCBISpeciesCombs.dat';
my $InputFile;
my @NCBIgenome;


#Set command line flags and parameters.
GetOptions("verbose|v!"  => \$verbose,
           "debug|d!"  => \$debug,
           "help|h!" => \$help,
           "output|o:s" => \$OutputFilename,
           "input|i:s" => \$InputFile,
           "genome|g:s" => \@NCBIgenome,
        ) or die "Fatal Error: Problem parsing command-line ".$!;

#Get other command line arguments that weren't optional flags.
my ($N)= @ARGV;

die "Must specify genome" unless (@NCBIgenome);

my $SpeciesCombs = {};

foreach my $entry (@NCBIgenome) {

splitIntoNCBISpeciesCombs($entry, $SpeciesCombs);
}

open OUTPUT, ">".$OutputFilename or die "Can't open output file!";

while (my ($Species, $CombsArray) = each (%$SpeciesCombs)){
	
	print OUTPUT $Species."\t".join("\t",@{$CombsArray})."\n";
}

close OUTPUT;

__END__

=head1 NAME

SplitByNCBIGenome.pl

=head1 DESCRIPTION

This script produces files for use with DomainPairCompare.pl. Given a genome (or list of genomes)
held in SUPERFAMILY which is actually a collection of many NCBI style species (e.g. the genome 'vl' is a 
collection of all the NCBI viral genomes), this script finds all of the domain cobinations and outputs
a file: species 1\tcomb 1\t comb 2\t comb 3...\nspecies 2\t ...^D. This is the format for the command 
line options -qblg and -tblg in DomainPairCompare.pl

The species names are found from the comment field of the protein table. The species name in an NCBI
style entry is kept in [] brackets.

=head1 USAGE

SplitByNCBIGenome.pl [-v verbose (unsupported) -d debug (unsupported) -h help -o output path -i input file listing genomes -g single genome identifier]

=head1 DEPENDANCY

B<Data::Dumper> Used for debug output.
B<Supfam::SQLFunc> Useful SUPERFAMILY Functions

=head1 AUTHOR

Adam Sardar - adam.sardar@bris.ac.uk

=head1 HISTORY

=cut