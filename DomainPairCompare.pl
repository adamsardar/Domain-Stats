#! /usr/bin/perl -w

=head1 NAME

23andmeParser_SNPposition2ProteinID<.pl>

=head1 USAGE

 23andmeParser_SNPposition2ProteinID.pl [options -v,-d,-h] <gene locations file>

=head1 SYNOPSIS

A script to...

=head1 AUTHOR

B<Adam Sardar> - I<adam.sardar@bris.ac.uk>

=head1 COPYRIGHT

Copyright 2011 Gough Group, University of Bristol.

=head1 EDIT HISTORY

3-Jan-2011 Initial Entry

=cut

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
=head1 DEPENDANCY
B<Getopt::Long> Used to parse command line options.
B<Pod::Usage> Used for usage and help output.
B<Data::Dumper> Used for debug output.
=cut
use Getopt::Long;                     #Deal with command line options
use Pod::Usage;                       #Print a usage man page from the POD comments after __END__
use Data::Dumper;                     #Allow easy print dumps of datastructures for debugging
#use XML::Simple qw(:strict);          #Load a config file from the local directory

# Command Line Options
#----------------------------------------------------------------------------------------------------------------

my $verbose; #Flag for verbose output from command line opts
my $debug;   #As above for debug
my $help;    #Same again but this time should we output the POD man page defined after __END__

#Set command line flags and parameters.
GetOptions("verbose|v!"  => \$verbose,
           "debug|d!"  => \$debug,
           "help|h!" => \$help,
        ) or die "Fatal Error: Problem parsing command-line ".$!;

#Get other command line arguments that weren't optional flags.
my ($file)= @ARGV;

#Print out some help if it was asked for or if no arguments were given.
pod2usage(-exitstatus => 0, -verbose => 2) if not $file or $help;

# Sub definitions
#----------------------------------------------------------------------------------------------------------------
=head1 DESCRIPTION

Detailed info about the script goes here

=head2 Methods
=over 4
=cut

=item * func
Function to do something
=cut
sub func {
	return 1;
}

# Main Script Content
#----------------------------------------------------------------------------------------------------------------

#Attempt to populate the CONFIG variable from a local XML file.
#my $CONFIG = XMLin("config.xml", ForceArray => 0, KeyAttr => [ ])
#    or warn "Can't open local XML config file.";

#Database parameters get these from a local config.xml, or give defaults
#my $host=(not ref $CONFIG->{'database'}->{'host'})?$CONFIG->{'database'}->{'host'}:'hostname.co.uk';
#my $user=(not ref $CONFIG->{'database'}->{'user'})?$CONFIG->{'database'}->{'user'}:'db_username';
#my $password=(not ref $CONFIG->{'database'}->{'password'})?$CONFIG->{'database'}->{'password'}:'db_password';

__END__

