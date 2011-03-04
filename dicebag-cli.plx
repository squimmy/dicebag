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
#	$expression =~ s/\s//g;
#	my @parsed = parse_expression($expression);
#	my @rolls = collate_rolls(@parsed);
	my @rolls = parse_expression($expression);
	print_rolls(@rolls);
	exit;
}

#sub parse_expression
#{
#	my @parsed;
#	
#	for (@_)
#	{
#		if (/([\+\-])?(\d+)d(\d+)/i)
#		{
#			my $sign = "";
#			$sign = $1 if $1;
#			print "$_: $sign\n";
#			my $hash = {
#						sign	=> $sign,
#						dice	=> $2,
#						sides	=> $3
#					};
#			push @parsed, $hash;
#		}
#		elsif (/([\+\-])?(\d)/)
#		{
#			my $sign = "";
#			$sign = $1 if $1;
#			print "$_: $sign\n";
#			my $hash = {
#						sign	=> $sign,
#						bonus	=> $2,
#					};
#			push @parsed, $hash;
#		}
#		else {die "parse_expression() has received a string it shouldn't have!"}
#	}
#	return @parsed;
#}
#
#sub split_expression
#{
#	my $expression = shift;
#	my @split;
#	until ($expression eq "")
#	{
#		print "$expression\n" if $expression;
#		if ($expression =~ /([\-\+]?\d+d\d+)/)
#		{
#			push @split, $1;
#			last if ($' eq "");
#			$expression = $';
#		}
#		elsif ($expression =~ /([\-\+]\d+)/)
#		{
#			push @split, $1;
#			$expression = $';
#		}
#		else
#		{
#			last;
#		}
#
#	}
#	return @split;
#}
#
#sub collate_rolls
#{
#	my @rolls;
#	my $temp;
#	for (@_)
#	{
#		if ($_->{dice})
#		{
#			$temp=roll($_->{dice},$_->{sides});
#			$temp->{sign}=$_{sign};
#			print 
#			push @rolls, $temp;
#		}
#		elsif ($_->{bonus})
#		{
#			@{$temp->{list}} = $_->{bonus};
#			$temp->{total} = $_->{bonus};
#			$temp->{sign} = $_->{sign};
#			push @rolls, $temp;
#		}
#		else {die "this should never happen. check input to collate_rolls()"}
#			
#	}
#	return @rolls;
#}
		
sub print_rolls
{
	my $total = 0;
	if ($verbose)
	{
		for (@_)
		{
			print "$_->{sign} " if $_->{sign};
			print "(",join(', ',@{$_->{list}}),") ";
			if ($_->{sign} && $_->{sign} eq "-")
			{
				$total -= $_->{total};
			}
			else
			{
				$total += $_->{total};
			}
		}
	}
	else
	{
		for (@_)
		{
			print "$_->{sign} " if $_->{sign};
			print "$_->{total} ";
			if ($_->{sign} && $_->{sign} eq "-")
			{
				$total -= $_->{total};
			}
			else
			{
				$total += $_->{total};
			}
		}
	}
	
	print "= $total\n";
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
