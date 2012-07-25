#! /usr/bin/perl -w

=head1 NAME

I<.pl>

=head1 USAGE

 .pl [options -v,-d,-h] <ARGS>

=head1 SYNOPSIS

A script to take a list of genomes (strains or whatever) and output some summary data regarding the domain architectures in common.

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
my $CDHITClusterFile;
my $GenomeFastaDirectory;

#Set command line flags and parameters.
GetOptions("verbose|v!"  => \$verbose,
           "debug|d!"  => \$debug,
           "help|h!" => \$help,
           "clusters|f=s" => \$CDHITClusterFile,
           "genesequencesdir|gd=s" => \$GenomeFastaDirectory,
        ) or die "Fatal Error: Problem parsing command-line ".$!;

#Print out some help if it was asked for or if no arguments were given.
pod2usage(-exitstatus => 0, -verbose => 2) if $help;

# Main Script Content
#----------------------------------------------------------------------------------------------------------------


my $ClusterHash = {}; #A hash of the gene sequence clusters
my $ClusterID; #Predeclaring so that the varaiable remains in scope

my $UniqueGeneNames = {}; #This will be a check that the gene names are unique
my $ClusterGenomeHash = {}; # Translate sequences into genomes and input them into this hash

my $SeqID2Genome={}; #Dictionary of a sequence ID translating to a genome that it contains (this is far too slow if done via a database) 

my @GenomeFastaFiles = glob("$GenomeFastaDirectory/*_seq.fasta");

foreach my $GenomeFile (@GenomeFastaFiles){
	
	my $SeqID;
	
	$GenomeFile =~ m/(\w{2,3})_seq.fasta$/;
	my $Genome = $1;

	open FH, "<$GenomeFile" or die $?;;
	
		while (my $line = <FH>){
			
			next unless($line =~ m/^>(.*)/);
			
			$SeqID = $1;
			die "Nonunique seqids across files" if(exists($SeqID2Genome->{$SeqID}));
			$SeqID2Genome->{$SeqID}=$Genome;
		}
	
	close FH;
}

open CDHITCLUSTER, "<$CDHITClusterFile" or die $?;

while (my $line = <CDHITCLUSTER>){
	
	next if($line =~ m/^#/ || $line =~ m/^$/); #Trim out comments and empty lines
	chomp($line);
	
	if($line =~ m/^>(.*)$/){
		
		$ClusterID = $1;
		$ClusterGenomeHash->{$ClusterID} = {};
		$ClusterHash->{$ClusterID}=[];
		
	}else{
		
		die if ($ClusterID ~~ undef);
		
		print "Line: ".$line."\n";
		
		my ($index,$seqlength,$seqid,$at,$alignmenetdetails) = split(/\s+/,$line);
		
		$seqid =~ s/^>//;
		$seqid =~ s/\.{3}$//; #Trim up the seqid
		
		print "SeqID: ".$seqid."\n";
		die "No genome with sequence id found" unless(exists($SeqID2Genome->{$seqid}));				
		
		my $genome = $SeqID2Genome->{$seqid};
		print "Genome: ".$genome."\n";
		
		$ClusterGenomeHash->{$ClusterID}{$genome}++;

		push(@{$ClusterHash->{$ClusterID}},$seqid);
		$UniqueGeneNames->{$seqid}++;		
	}
}

close CDHITCLUSTER;

#Check that gene names are unique

map{die "Gene names are non-unique!\n" if($UniqueGeneNames->{$_} > 1);}(keys(%$UniqueGeneNames));

#Invert the Cluster hash so that we can treat belonging to a cluster as a genome trait

my $Genome2ClusterHash = {};

foreach my $Cluster (keys(%$ClusterGenomeHash)){

	foreach my $Genome (keys(%{$ClusterGenomeHash->{$Cluster}})){
		
		$Genome2ClusterHash->{$Genome}=[] unless(exists($Genome2ClusterHash->{$Genome}));
		push(@{$Genome2ClusterHash->{$Genome}},$Cluster);
	}
}


########

mkdir("./GeneFamilies");

open SUMMARY, ">./GeneFamilies/Fams-Summary.csv";

print SUMMARY "Genome\t Number of distinct gene families \n";

foreach my $genome_entry (keys(%$Genome2ClusterHash)){
	
	my @DistinctFams= @{$Genome2ClusterHash->{$genome_entry}};
	print SUMMARY $genome_entry."\t".scalar(@DistinctFams)."\n";
}

close SUMMARY;

my $AllVsAllUniqueFams= {};
my $AllVsAllIntersectionFams={};

my $AllVsAllUniqueFamsRatios= {};
my $AllVsAllIntersectionFamsRatios={};

foreach my $genome_entry_A (keys(%$Genome2ClusterHash)){
	
	my @FamsA = @{$Genome2ClusterHash->{$genome_entry_A}};
	$AllVsAllUniqueFams->{$genome_entry_A} = {};
	$AllVsAllIntersectionFams->{$genome_entry_A} = {};
	
	foreach my $genome_entry_B (keys(%$Genome2ClusterHash)){
	
		my @FamsB = @{$Genome2ClusterHash->{$genome_entry_B}};
		my ($Union,$Intersection,$ListAExclusive,$ListBExclusive) = IntUnDiff(\@FamsA,\@FamsB);
		$AllVsAllUniqueFams->{$genome_entry_A}{$genome_entry_B} = scalar(@$ListAExclusive);
		$AllVsAllIntersectionFams->{$genome_entry_A}{$genome_entry_B} = scalar(@$Intersection);
		
		$AllVsAllUniqueFamsRatios->{$genome_entry_A}{$genome_entry_B} = ceil(100*scalar(@$ListAExclusive)/scalar(@FamsA));
		$AllVsAllIntersectionFamsRatios->{$genome_entry_A}{$genome_entry_B} = ceil(100*scalar(@$Intersection)/scalar(@FamsA));
	}
}

TabSepFile([keys(%$AllVsAllUniqueFams)],$AllVsAllUniqueFams,"./GeneFamilies/Fams-AllVsAllUnique.dat",undef,0);
TabSepFile([keys(%$AllVsAllIntersectionFamsRatios)],$AllVsAllIntersectionFamsRatios,"./GeneFamilies/Fams-AllVsAllIntersection.dat",undef,0);

TabSepFile([keys(%$AllVsAllUniqueFamsRatios)],$AllVsAllUniqueFamsRatios,"./GeneFamilies/Fams-AllVsAllUnique-Ratio.dat",undef,0);
TabSepFile([keys(%$AllVsAllIntersectionFamsRatios)],$AllVsAllIntersectionFamsRatios,"./GeneFamilies/Fams-AllVsAllIntersection-Ratio.dat",undef,0);

__END__