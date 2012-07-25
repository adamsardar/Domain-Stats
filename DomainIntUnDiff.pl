#! /usr/bin/perl -w
# Strict Pragmas


#----------------------------------------------------------------------------------------------------------------
use strict;
use warnings;
#use diagnostics;

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
use Term::ProgressBar;


sub writeDependencyFile($$) {
my ($filename,$references) = @_;
ref $references eq 'ARRAY' or warn "Expected an arrayref.";
	open(DEP_FILE, '>'.$filename) or die "couldn't open for write";
	print DEP_FILE Dumper($references);
	close(DEP_FILE);
}

sub writeDependencyFileSTDOUT($) {
my ($references) = $_[0];
ref $references eq 'ARRAY' or warn "Expected an arrayref.";
	print Dumper($references);
}

my $verbose; #Flag for verbose output from command line opts
my $debug;   #As above for debug
my $help;    #Same again but this time should we output the POD man page defined after __END__
my $ForceWriteToStdOut; #Flag to output to STDOUT
my @InputFiles; # List of domains 

#Set command line flags and parameters.
GetOptions("verbose|v!"  => \$verbose,
           "debug|d!"  => \$debug,
           "help|h!" => \$help,
           "file|f:s" =>  \@InputFiles,
           "forceoutput|p" => \$ForceWriteToStdOut,
        ) or die "Fatal Error: Problem parsing command-line ".$!;

#Get other command line arguments that weren't optional flags.
my ($N)= @ARGV;

die 'Expected two file inputs (use -f file1 file2)' if (@InputFiles != 2);


my @DomainsA;
my @DomainsB;
# The two lists of unique domains piars with which we are going to compute the Union, 
# the Intersection and the Difference 

open INPUTFILE1, "<".$InputFiles[0] or die $!;
my @InputA = <INPUTFILE1>;
close INPUTFILE1;

foreach my $line (@InputA){
	
	$line =~ /(\d*,\d*)/;
	my $domains = $1;
	push  (@DomainsA , $domains);
}


open INPUTFILE2, "<".$InputFiles[1] or die $!;
my @InputB = <INPUTFILE2>;
close INPUTFILE2;

foreach my $line (@InputB){
	
	$line =~ /(\d*,\d*)/;
	my $domains = $1;
	push (@DomainsB , $domains);
}


my $IntersectionHashRef = {};
my $UnionHashRef = {};
my $UniqueA = {};
my $UniqueB ={};

my $no_lines = @DomainsA + @DomainsB;

my $progress = Term::ProgressBar->new({name => 'Calculating Intersection of Domain Pairs',count => 2*$no_lines});
  $progress->minor(0);
  my $next_update = 0;
#Initialise a progress bar

my $count = 0;

foreach my $elementA (@DomainsA){
	no warnings 'uninitialized';
	$count ++;
	$next_update = $progress->update($count) if $count >= $next_update;
	
	$UnionHashRef->{$elementA}++;
} 

foreach my $elementB (@DomainsB){
	no warnings 'uninitialized';
	$count ++;
	$next_update = $progress->update($count) if $count >= $next_update;
	
	if($UnionHashRef->{$elementB}){
		
		$IntersectionHashRef->{$elementB}++;
	}else{
		
	    $UniqueB->{$elementB}++;
	}
	
	$UnionHashRef->{$elementB}++;
} 

foreach my $elementA (@DomainsA){
	no warnings 'uninitialized';
	$count ++;
	$next_update = $progress->update($count) if $count >= $next_update;	
		
	$UniqueA->{$elementA}++ unless($IntersectionHashRef->{$elementA}) ;
}

$progress->update(2*$no_lines);

if (!$ForceWriteToStdOut){

writeDependencyFile('SetData.dump',[$IntersectionHashRef,$UnionHashRef,$UniqueA,$UniqueB]);
} else{
	
writeDependencyFileSTDOUT([$IntersectionHashRef,$UnionHashRef,$UniqueA,$UniqueB]);	
}

print "\n\nTotal Points:".$no_lines
."\nIntersection:".scalar(keys(%$IntersectionHashRef))
."\nUnion:".scalar(keys(%$UnionHashRef))
."\nSet A : ".scalar(@DomainsA)
."\nSet B : ".scalar(@DomainsB)
."\nA Unique: ".scalar(keys(%$UniqueA))
."\nB Unique: ".scalar(keys(%$UniqueB))."\n";

__END__

=head1 NAME

I<.pl>

=head1 DESCRIPTION

This script finds all of the unique domain pairs within an input list of domain architectures (an array).


=head1 USAGE

 .pl [options -v,-d,-h] <ARGS>

=head1 DEPENDANCY

B<Data::Dumper> Used for debug output.

=head1 AUTHOR

Adam Sardar - adam.sardar@bris.ac.uk

=head1 HISTORY


sub DomainSetsStats($$) {
my ($DomainsOneRef, $DomainsTwoRef) = @_;
my $DomainsARef;
my $DomainsBRef;

if ((@$DomainsOneRef) <= (@$DomainsTwoRef)){
	#my ($DomainsARef,$DomainsBRef) = ($DomainsOneRef, $DomainsTwoRef) ;
	$DomainsARef = $DomainsOneRef;
	$DomainsBRef = $DomainsTwoRef;
	
}else{
	#my ($DomainsBRef,$DomainsARef) = qw ($DomainsOneRef $DomainsTwoRef);
	$DomainsARef = $DomainsOneRef;
	$DomainsBRef = $DomainsTwoRef;
}

my @DomainsA = @$DomainsARef;
my @DomainsB = @$DomainsBRef;

my $IntersectionHashRef = {};
my $UnionHashRef = {};
my $UniqueA = {};
my $UniqueB ={};

foreach my $elementA (@DomainsA){
	no warnings 'uninitialized';
	$UnionHashRef->{$elementA}++;
} 

foreach my $elementB (@DomainsB){
	no warnings 'uninitialized';

	if($UnionHashRef->{$elementB}++){
		$IntersectionHashRef->{$elementB}++;
	}else{
	    $UniqueB->{$elementB}++;
	}
} 

foreach my $elementA (@DomainsA){
	no warnings 'uninitialized';
	$UniqueA->{$elementA}++ unless($IntersectionHashRef->{$elementA}) ;

}
my $Sets = [$UnionHashRef, $IntersectionHashRef, $UniqueA , $UniqueB];

return $Sets;
}

=cut