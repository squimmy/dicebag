package Dicebag::Simple;

#############################################
#                                           #
#  Module to allow simple-syntax dice-rolls #
#                                           #
#############################################

use warnings;
use Carp;
require Exporter;
@ISA = (Exporter);
@EXPORT = qw(simplify);
use strict;

sub simplify
{
	my $expression = shift;
	
	$expression =~ s/\Dd|^d/1d/g;		#default number of dice is 1
	$expression =~ s/d\D|d$/d6/g;		#default number of sides is 6
	$expression =~ s/\s//g;						#remove whitespace

	if ($expression =~ /^(\d+)d(\d+)([\+\-\*\/])(\d+)$/)
	# handle expressions similar to '2d6+1'
	{
		return (qq|$1d$2|, qq|"[";%D;"] $3 ";$4;" = ";[%D]$3$4|);
	}
	if ($expression =~ /^(\d+)([\+\-\*\/])(\d+)d(\d+)$/)
	# handle expressions similar to '6-1d6'
	{
		return (qq|$3d$4|, qq|"$1 $2 [";%D;"] = ";$1$2%D|);
	}
	elsif ($expression =~ /^(\d+)d(\d+)$/)
	# handle expressions similar to '2d10'
	{
		return (qq|$1d$2|, qq|"[";%D;"] = ";[%D]|);
	}
	else
	# handle everything else
	{
		$expression =~ s/(\d+d\d+)/[$1]/g;
		return (qq|$expression|, qq|%D|);
	}
}
