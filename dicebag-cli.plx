#!/usr/bin/perl
use warnings; use strict;

use Dicebag::Brain;
use Dicebag::Games;
use Dicebag::Parser;
use Dicebag::Verbose;
use Dicebag::Settings;
use Dicebag::Simple;
use Getopt::Long;

my $help = '';

my $settings = get_settings();

GetOptions
	(
	'help|?'				=> \$help
	);


help() if $help;

my $exp1 = shift;
my $exp2 = shift;
my $exp3 = shift;
my $exp4 = shift;
read_input($exp1, $exp2, $exp3, $exp4) if $exp1;
help();

sub read_input
{
	my $exp1 = shift;
	my $exp2 = shift;
	my $exp3 = shift;
	my $exp4 = shift;
	my ($input, $output);
	if (have_settings($exp1))
	{
		$input = $settings->{$exp1}{input};
		$output = $settings->{$exp1}{output};
		($exp1, $exp2, $exp3) = ($exp2, $exp3, $exp4);
		for ($exp1, $exp2, $exp3)
		{
			if ($_)
			{
				die "non-numeric value in variable!\n" if /[^\d]/;
			}
		}
		$input = fillin_expression($input, $exp1, $exp2, $exp3);
	}
	else
	{
		($input, $output) = simplify($exp1);
	}
	$output = fillin_expression($output, $exp1, $exp2, $exp3);

	my $result = parse_expression($input, $output);
	
	handle_output($result);
	exit;
}


sub handle_output
{
	my $output = shift;
	print "$output\n";
}


sub have_settings
{
	my $name = shift;
	for (keys %$settings)
	{
		if ($name eq $_)
		{
			return 1;
		}
	}
	return 0;
}

sub fillin_expression
{
	my $expression = shift;
	my $x = shift;
	my $y = shift;
	my $z = shift;

	if ($expression =~ /%X/)
	{
		if ($x)
		{
			$expression =~ s/%X/$x/g;
		}
		else
		{
			die "not enough expressions!\n";
		}
	}
	if ($expression =~ /%Y/)
	{
		if ($y)
		{
			$expression =~ s/%Y/$y/g;
		}
		else
		{
			die "not enough expressions!\n";
		}
	}
	if ($expression =~ /%Z/)
	{
		if ($z)
		{
			$expression =~ s/%Z/$z/g;
		}
		else
		{
			die "not enough expressions!\n";
		}
	}

	return $expression;
}


sub help
{
	print <<EOF;

Usage: dicebag [arguments] <dice expression>
   or: dicebag --gurps <skill-level>
   or: dicebag --wod <number of dice> <"again" target> [rote]
   or: dicebag --dnd <bonus> <DC>
   or: dicebag --warhammer <number of dice> <target to beat>

Arguments:
	--verbose	gives more information regarding roll outcomes
	--help		displays this help message

Dice expressions are given in the form "XdY+Z"
where:
		X is the number of dice rolled
		Y is the number of sides on each die
		Z is a flat bonus (or penalty) applied to the total
EOF
	exit;
}
