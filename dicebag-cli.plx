#!/usr/bin/perl
use warnings; use strict;

use Dicebag::Brain;
use Dicebag::Games;
#use Dicebag::Output;
use Getopt::Long;
use Dicebag::Parser;
use Dicebag::Verbose;
my $verbose = '';
my $gurps = '';
my $wod = '';
my $dnd = '';
my $warhammer = '';
my $help = '';


GetOptions
	(
	'gurps'					=> \$gurps,
	'wod'					=> \$wod,
	'dnd|d20'				=> \$dnd,
	'warhammer|40k'			=> \$warhammer,
	'verbose'				=> \$verbose,
	'help|?'				=> \$help
	);

my %games=
(
	wod			=> \&wod,
	gurps		=> \&gurps,
	warhammer	=> \&warhammer,
	dnd			=> \&dnd,
	standard	=> \&standard_roll
);


help() if $help;
check_parameters($gurps,$wod,$warhammer,$dnd);

my $exp1 = shift;
my $exp2 = shift;
my $exp3 = shift;
one_shot($exp1, $exp2, $exp3) if $exp1;
interactive();

sub one_shot
{
	my $exp1 = shift;
	my $exp2 = shift;
	my $exp3 = shift;
	my $gametype = choose_game();
	my $output;
	for (keys %games)
	{$output = $games{$_}->($exp1, $exp2, $exp3) if $_ eq $gametype}
	handle_output($output);
	exit;
}

sub standard_roll
{
	my $expression = shift;# @ARGV;
	my $rolls = parse_expression($expression);
	handle_output($rolls);
	exit;
}

sub handle_output
{
	my $output = shift;
	if ($verbose)
	{
		my $verboseout = return_verbose();
		if ($verboseout)
		{
			$verboseout .="Total: ";
			print $verboseout;
		}
	}
	print $output->{standard};
	print "\n";
}

sub check_parameters
{
	my $count = 0;
	for (@_){$count++ if $_}
	if ($count > 1)
	{
		print "You can only play one game at a time!\n";
		exit;
	}
}

sub choose_game
{
	return "gurps" if $gurps;
	return "wod" if $wod;
	return "dnd" if $dnd;
	return "warhammer" if $warhammer;
	return "standard";
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
