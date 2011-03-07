package Dicebag::Parser;

use warnings;
use Carp;

require Exporter;
@ISA = (Exporter);
@EXPORT = qw(parse_expression);

use strict;
use Dicebag::Brain;


sub parse_expression
{
	my $expression = shift;
	$expression =~ s/\s//g; # remove whitespace from dice expression
	croak "Unmatched parentheses in dice expression" unless check_parens($expression);
	my $result = interpret_expression($expression);
	return $result;
}

sub check_parens
{
	my $expression = shift;
	my $count = 0;
	while ($expression =~ /([\(\)])/g)
	{
		$count++ if $1 eq "(";
		$count-- if $1 eq ")";
		return 0 if $count<0;
	}
	return ($count==0)?1:0;
}

sub interpret_expression
{
	my $expression = shift;
	$expression =~ s/\)\(/)*(/g;
	$expression =~ s/\d(?=\()/$&*/g;	# lazy way to do implied multiplication
	
	my %diceroutine			=	(	"match",	qr#\d+d\d+#,
									"function",	\&parse_roll,
								);
	my %multiplierroutine	=	(	"match",	qr#\d+[\*\/]\d+#,
									"function",	\&parse_multiplication,
								);
	my %additionroutine		=	(	"match",	qr#\d+[\+\-]\d+#,
									"function",	\&parse_addition,
								);
	my @subroutines = (\%diceroutine,\%multiplierroutine,\%additionroutine);

	until ($expression =~ /^\-?\d+$/)
	{	

		my ($batch, $temp);
		$batch = $expression unless $expression =~ /\(/;

		my $re;
		$re = qr#\(([^\(\)]+|(??{$re}))\)#;	# finds deepest brackets in expression
		if ($expression =~ /$re/)	# this is giving a warning... apparently using an anonymous sub should fix it?
		{
			$batch = $1;
		}
		$temp = sanitiser($batch);
		until ($batch =~/^\d$/)
		{
			INNER: for (@subroutines)
			{
				if ($batch=~$_->{match})
				{
					my $operators = $&;

					my $result = &{$_->{function}}($operators);
					
					$operators = sanitiser($operators);
					$batch =~ s/$operators/$result/;
					last INNER;
				}
			}
			$expression =~ s/$temp/$batch/;
			last if $batch =~ /^\-?\d+$/;
		}
	
		$expression =~ s/\((\d+)\)/$1/;
		last if $expression =~ /^\-?\d+$/;
	}

	return $expression;
}




sub parse_operators
{
	my $expression = shift;
	$expression =~ /(\d+)([d\*\/\+\-])(\d+)/;
	return ($1, $3, $2);
}

sub sanitiser
{
	my $expression = shift;
	$expression =~ s/[\.\(\)\+\?\*\{\}\[\]\|\\\^\$]/\\$&/g;
	return $expression;
}

sub parse_roll
{
	my $expression = shift;
	my ($dice, $sides) = parse_operators($expression);
	my $result = roll($dice, $sides);
	return $result->{total};
}

sub parse_multiplication
{
	my $expression = shift;
	my ($a, $b, $op) = parse_operators($expression);
	return ($a*$b) if $op eq "*";
	return (int($a/$b)) if $op eq "/";
}

sub parse_addition
{
	my $expression = shift;
	my ($a, $b, $op) = parse_operators($expression);
	return ($a+$b) if $op eq "+";
	return ($a-$b) if $op eq "-";
}
