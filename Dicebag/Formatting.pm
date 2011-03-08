package Dicebag::Formatting;

use warnings;
use Carp;

require Exporter;
@ISA = (Exporter);
@EXPORT = qw(convert_to_string);

sub convert_to_string
{
	my $delimiter = pop;
	my @array = @_;
	my $count = 0;
	for (@array)
	{
		$_ .= " + " unless $count == $#array;
		$count++;
	}
	my $output = "";
	$output .= $_ for @array;
	return $output;
}
