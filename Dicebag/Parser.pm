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
	print "expression is currently: $expression\n";
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
			if ($batch =~ /\d+d\d+/)
			{
				my $operators = $&;
				my ($dice, $sides) = parse_operators($operators);
				my $roll = roll($dice, $sides);
				$batch =~ s/$operators/$roll->{total}/;
			}
			elsif ($batch =~ /\d+[\*\/]\d+/)
			{
				my $operators = $&;
				my ($a, $b, $op) = parse_operators($operators);
				my $result;
				$result = $a*$b if $op eq "*";
				$result = int($a/$b) if $op eq "/";
				$operators = sanitiser($operators);
				$batch =~ s/$operators/$result/;
			}
			elsif ($batch =~ /\d+[\-\+]\d+/)
			{
				my $operators = $&;
				my ($a, $b, $op) = parse_operators($operators);
				my $result;
				$result = $a+$b if $op eq "+";
				$result = $a-$b if $op eq "-";
				$operators = sanitiser($operators);
				$batch =~ s/$operators/$result/;
			}
			else
			{
				croak "unexpected operator encountered in expression";
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
