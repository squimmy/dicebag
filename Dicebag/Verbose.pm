package Dicebag::Verbose;

use warnings;
use Carp;
require Exporter;
@ISA = (Exporter);
@EXPORT = qw(verbose_output return_verbose);

use strict;
my $verboseout;

sub verbose_output
{
	my $dice = shift;
	my $sides = shift;
	my @rolls = @_;
	my $total = 0;
	$total += $_ for @rolls;
	my $outputlist=join(" + ",@rolls);
	$verboseout .= "[".$dice."d".$sides."]: ($outputlist) = ".$total."\n";
}

sub return_verbose
{
	return $verboseout;
}
1;
