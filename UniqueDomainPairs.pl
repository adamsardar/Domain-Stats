#! /usr/bin/perl -w
# Strict Pragmas

#----------------------------------------------------------------------------------------------------------------
use strict;
use warnings;
use diagnostics;

# Add Local Library to LibPath
#----------------------------------------------------------------------------------------------------------------
#use lib
#qw(
#/home/user/perl/lib32/perl5/5.8.8/module  #An example only uncomment/edit if you did need to add local modules
#);

# CPAN Includes
#----------------------------------------------------------------------------------------------------------------
use Getopt::Long;                     #Deal with command line options
use Pod::Usage;                       #Print a usage man page from the POD comments after __END__
use Data::Dumper;                     #Allow easy print dumps of datastructures for debugging
#use XML::Simple qw(:strict);          #Load a config file from the local directory
use DBI;
use Math::Combinatorics;
use Term::ProgressBar;


my $verbose; #Flag for verbose output from command line opts
my $debug;   #As above for debug
my $help;    #Same again but this time should we output the POD man page defined after __END__
my $input_filename;
my $output_filename = "UniqueDomains.dat"; # Default is UniqueDomains.dat
my $force_print_to_STDOUT; # Might be useful is running as part of another script. Prints plain data out

#Set command line flags and parameters.
GetOptions("verbose|v!"  => \$verbose,
           "debug|d!"  => \$debug,
           "help|h!" => \$help,
           "file|f:s" => \$input_filename,
           "output|o:s" => \$output_filename,
           "forceoutput|p" => \$force_print_to_STDOUT,
        ) or die "Fatal Error: Problem parsing command-line ".$!;

#Get other command line arguments that weren't optional flags.
my $N = @ARGV;

die "You need to specify an input file" unless ($input_filename);

open INPUTFILE, "<".$input_filename or die $!;
my @UnsortedDomainCombs = <INPUTFILE>;
close INPUTFILE;
#UnsortedDomainCombs is a list of comma seperated domain architectures, one per line.

my $UniqueDomainsHash = {};

my $no_lines = @UnsortedDomainCombs;

my $progress = Term::ProgressBar->new({name => 'Finding Unique Domain Pairs',count => $no_lines , ETA => 'linear',});
  $progress->minor(0);
  my $next_update = 0;
#Initialise a progress bar

my $count = 0;

foreach my $line (@UnsortedDomainCombs){
	
$count++;
	
	unless($line =~ m/^#.*/){
		
		my @Domains = split(',',$line);
		chomp(@Domains);
		my @TrimmedDomains = grep(!/^_gap_/, @Domains);
		
		if(scalar(@TrimmedDomains) >= 2){
			
		my @DomainCombinations = combine(2, @TrimmedDomains);

					foreach my $DomainPairRef (@DomainCombinations){
						
						my @SortedDomainComb = sort {$a <=> $b} @$DomainPairRef;	
						my $DomainPair = join(',', @SortedDomainComb);
						
						$UniqueDomainsHash->{$DomainPair}++;
			}
		}	
	}	
	
	$next_update = $progress->update($count) if $count >= $next_update;
}

$progress->update($no_lines);

# An overview of what's happening here - strip out all comments from the inout file, for each line (a single proteins
#domain arcitechture), remove the '_gap_' entries and then, if there are at least 2 known domains, find all the 
# domain pairings (combinations, so independant of order) and then perform a simpe count.

if ($force_print_to_STDOUT){
	
	while (my ($key, $value) = each(%$UniqueDomainsHash)){
	
     print $key."-".$value."\n";
	}
}else{

open OUTPUT, ">$output_filename" or die $!;

my $NumberOfUniqueDomainPairs = keys(%$UniqueDomainsHash);
print OUTPUT  "# There are ".$NumberOfUniqueDomainPairs." unique domain pairs in input list of domain architectures \n";

	while (my ($key, $value) = each(%$UniqueDomainsHash)){
	
     		print OUTPUT "Domain: ".$key.", Number:".$value."\n";
		}
		
close OUTPUT;		
}

__END__

=head1 NAME

UniqueDomainPairs<.pl>

=head1 DESCRIPTION

This script finds all of the unique domain pairs within an input list of domain architectures extracted from the
SUPERFAMILY database. Unassigned domains (_gap_ in SUPERFAMILY) are obviously ignored. Also, proteins of only one
domain are ommitted, as they aren't in a pair!

The following options are available:

-f REQUIRED The filename of the input text containing domain architectures - one on each line
-o Optional flag specifying output file location. Default is UniqueDomains.dat.
-p Force output to STDOUT. Unique domain pair IDs and frequency within input file outputed to STDOUT.

=head1 USAGE

 UniqueDomainPairs.pl [options -f -o -p]

=head1 DEPENDANCY

B<Data::Dumper> Used for debug output.
B<Math::Combinatorics> Needed for finding pairs of domains efficiently
B<Term::ProgressBar>  Used for created a progress bar

=head1 AUTHOR

Adam Sardar - adam.sardar@bris.ac.uk

=head1 HISTORY

15 Nov 2010 - v1.0.0 

=cut