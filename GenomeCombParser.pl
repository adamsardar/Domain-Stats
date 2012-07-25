#! /usr/bin/perl -w
# Strict Pragmas
use lib "/home/sardar/workspace/Oates/lib";

#----------------------------------------------------------------------------------------------------------------
use strict;
use warnings;
#use diagnostics;
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
my $OutputFilename = 'GenomeCombs.dat';
my $InputFile;


#Set command line flags and parameters.
GetOptions("verbose|v!"  => \$verbose,
           "debug|d!"  => \$debug,
           "help|h!" => \$help,
           "output|of:s" => \$OutputFilename,
           "input|if:s" => \$InputFile,
        ) or die "Fatal Error: Problem parsing command-line ".$!;

#Get other command line arguments that weren't optional flags.
my ($N)= @ARGV;

die "No inout file" unless ($InputFile);

#Print out some help if it was asked for or if no arguments were given.
#pod2usage(-exitstatus => 0, -verbose => 2) if not $N or $help;

open INPUT, '<'.$InputFile or die "Error opengn input file";
my @Input = <INPUT>;
close INPUT;

my $GenomeCombHash = {};

foreach my $line (@Input){	
	
	my @line = split("\t", $line);
	my $genome = shift(@line);

	$GenomeCombHash->{$genome} = [] unless ($GenomeCombHash->{$genome});
	chomp(@line);
	push(@{$GenomeCombHash->{$genome}},join("\t",("",@line)));	
}

delete $GenomeCombHash->{'genome'} if ($GenomeCombHash->{'genome'});

open OUTPUT, '>'.$OutputFilename or die "Error opening output file";

while(my ($key, $value) = each(%$GenomeCombHash)){
	
	print OUTPUT $key."\t".join("",@$value)."\n";
	
}

close OUTPUT;


__END__

=head1 NAME

GenomeCombParser.pl

=head1 DESCRIPTION

This script is designed to take a SUPERFAMILY mysql ouput of genome, comb (tab seperated) and
return a file of genome and all domain archtectures within that genome tab seperated (ready for
use with DomainPairCompare). for example, the input file could be from a SUPERFAMILY query
'select genome, comb from comb where genome = '?''

=head1 USAGE

GenomeCombParser.pl -f 'Input file' -o 'Output file'

=head1 DEPENDANCY

B<Data::Dumper> Used for debug output.

=head1 AUTHOR

Adam Sardar - adam.sardar@bris.ac.uk

=head1 HISTORY


=cut