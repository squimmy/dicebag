package Dicebag::Brain;

use warnings;
use Carp;
use Dicebag::Verbose;

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

sub roll
{
	my $dice = shift;
	my $sides = shift;
	my $flag = shift;
	my @total;
	for (1..$dice)
	{
		push @total, rollthebones($sides);
	}
	verbose_output($dice, $sides, @total) unless $flag;
	return @total;
}

sub recursive_rolling
{
	my $dice		= shift;
	my $sides		= shift;
	my $threshold	= shift;
	my $sign 		= shift;
	my $count 		= shift;
	my @roll;
	my @total;
	my $initial = $dice;
	while ($dice)
	{
		@roll = roll($dice, $sides, 1);
		push @total, @roll;
		if ($sign == 1)
		{$dice = grep {$_ >= $threshold} @roll;}
		elsif ($sign == -1)
		{$dice = grep {$_ <= $threshold} @roll;}
		else
		{$dice = grep {$_ == $threshold} @roll;}
		if ($count)
		{$count--; last if $count ==0;}
	}

	verbose_output($initial, $sides, @total,);
	return @total;
}

sub roll_old
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
	return keep_x(@_,1);
}
	
sub keep_lowest
{
	return keep_x(@_,-1);
}

sub keep_x
{
	my $highlow = pop;
	my $top = pop;
	my @rolls = @_;
	my @sorted;
	if ($highlow > 0)
	{@sorted = (sort {$b <=> $a}  @rolls);}
	elsif ($highlow < 0)
	{@sorted = (sort {$a <=> $b}  @rolls);}

	splice @sorted, $top;

	return	@sorted;
}
1;
