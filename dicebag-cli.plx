#!/usr/bin/perl
use warnings; use strict;

use Dicebag::Brain;
use Getopt::Long;
use Dicebag::Parser;
my $verbose = '';
my $gurps = '';
my $wod = '';
my $dnd = '';
my $warhammer = '';
my $help = '';


GetOptions
	(
	'gurps'					=> \$gurps,
	'wod|mage|vampire'		=> \$wod,
	'dnd|d20'				=> \$dnd,
	'warhammer|40k'			=> \$warhammer,
	'verbose'				=> \$verbose,
	'help'					=> \$help
	);

help() if $help;
standard_roll();


sub standard_roll
{
	my $expression = shift @ARGV;
	my $rolls = parse_expression($expression);
	handle_output($rolls);
	exit;
}

sub print_rolls
{
	my $result = shift;
	print "$result\n";
}
		
sub handle_output
{
#	my $total = 0;
#	if ($verbose)		#revamped parser has broken verbose output :(
#	{
#		for (@_)
#		{
#			print "$_->{sign} " if $_->{sign};
#			print "(",join(', ',@{$_->{list}}),") ";
#			if ($_->{sign} && $_->{sign} eq "-")
#			{
#				$total -= $_->{total};
#			}
#			else
#			{
#				$total += $_->{total};
#			}
#		}
#	}
#	else
#	{
#		for (@_)
#		{
#			print "$_->{sign} " if $_->{sign};
#			print "$_->{total} ";
#			if ($_->{sign} && $_->{sign} eq "-")
#			{
#				$total -= $_->{total};
#			}
#			else
#			{
#				$total += $_->{total};
#			}
#		}
#	}
	my $output = shift;
	print "$output\n";
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
