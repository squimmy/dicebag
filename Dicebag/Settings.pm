package Dicebag::Settings;

use warnings;
use Carp;
require Exporter;
@ISA = (Exporter);
@EXPORT = qw(get_settings);

use strict;


my @file;

open CONFIG, "dicebag.cfg" or die "could not open config file: $!\n";
while (<CONFIG>)
{
	s/#.*//;
	next if /^(\s)*$/;
	chomp;
	push @file, $_;
}
close CONFIG;

my %settings;
my @games;

for (@file)
{
	$settings{maxdice}			= $1 if /maxdice\s*\=\s*(\d+)/i;
	$settings{maxsides}			= $1 if /maxsides\s*\=\s*(\d+)/i;
	$settings{maxbrackets}		= $1 if /maxbrackets\s*\=\s*(\d+)/i;
	$settings{timeout}			= $1 if /timeout\s*\=\s*(\d+)/i;
	$settings{$1}->{input}		= $2 if /format\.\s*(\w+)\:input\s*\=\s*(.*)/i;
	$settings{$1}->{output}		= $2 if /format\.\s*(\w+)\:output\s*\=\s*(.*)/i;
	$settings{$1}->{verbose}	= $2 if /format\.\s*(\w+)\:verbose\s*\=\s*(.*)/i;
	if (/format\.\s*(\w+)\:results\s*\=\s*(.*)/i)
	{
		my @map = split /\s*\,\s*/, $2;
		my @results;
		for (@map)
		{
			my ($t1, $t2) = split /\s*\:\s*/, $_;
			my $temp = {condition	=> $t1,
						value		=> $t2};
			push @results, $temp;
		}
			$settings{$1}->{results} = \@results;
	}

}


$settings{maxdice}			||= 200;		#setting default values for things not found in config
$settings{maxsides}			||= 200;
$settings{maxbrackets}		||= 0;
$settings{timeout}			||= 0;


sub get_settings
{
	return \%settings;
}


1;
