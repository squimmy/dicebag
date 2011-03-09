package Dicebag::Brain;

use warnings;
use Carp;

require Exporter;
@ISA = (Exporter);
@EXPORT = qw(roll keep_highest keep_lowest recursive_rolling);

use strict;

sub rollthebones
{
	my $dice = shift;
	carp '$dice must be an integer greater than 0' unless (($dice=~/^\d+$/) && ($dice!=0));
	return int(rand $dice)+1;
}

sub roll_lots
{
	my $dice = shift;
	my $sides = shift;
	my @total;
	for (1..$dice)
	{
		push @total, rollthebones($sides);
	}

	return @total;
}

sub recursive_rolling
{
	my $dice		= shift;
	my $sides		= shift;
	my $threshold	= shift;

	push my @rolls, roll_lots($dice, $sides);
	$dice = grep {$_ >= $threshold} @rolls;
	push (@rolls, recursive_rolling($dice, $sides, $threshold)) if $dice;

	return @rolls;
}

sub roll
{
	my $dice = shift;
	croak 'number of dice must be an integer greater than 0' unless (($dice=~/^\d+$/) && ($dice > 0));
	my $sides = shift;
	croak 'number of sides must be an integer greater than 0' unless (($sides=~/^\d+$/) && ($sides > 0));
	my $bonus = shift;
	if ($bonus){croak 'bonus must be an integer' unless ($bonus=~/^\d+$/);}
	my $total;

	my @rolls = roll_lots($dice, $sides);

	$total += $_ for @rolls;
	$total += $bonus if $bonus;

	return
	{
		total	=> $total,
		list	=> \@rolls,
		bonus	=> $bonus
	};
}

sub keep_highest
{
	my $output = keep_x(@_,1);
	return $output;
}
	
sub keep_lowest
{
	my $output = keep_x(@_,-1);
	return $output;
}

sub keep_x
{
	my $dice = shift;
	my $sides = shift;
	my $top = shift;
	my $highlow = shift;
	my @rolls = roll_lots($dice, $sides);
	my @sorted;
	if ($highlow > 0)
	{@sorted = (sort {$b <=> $a}  @rolls);}
	if ($highlow < 0)
	{@sorted = (sort {$a <=> $b}  @rolls);}

	splice @sorted, $top;

	my $total = 0;
	$total += $_ for @sorted;
	return
	{
		total	=> $total,
		list	=> \@rolls
	};
}
1;
