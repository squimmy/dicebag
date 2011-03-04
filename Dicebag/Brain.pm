package Dicebag::Brain;

use warnings;
use Carp;

require Exporter;
@ISA = (Exporter);
@EXPORT = qw(roll gurps wod warhammer);

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
		list	=> \@rolls
	};
}

sub gurps
{

	my $roll = roll(3,6);
	my $skill = shift;
	carp 'skill must be an integer' unless ($skill=~/^\d+$/);

	my $result=gurps_crits($roll->{total},$skill);
	
	return
	{
		result	=> $result,
		total	=> $roll->{total},
		list	=> \@{$roll->{list}}
	};
}

sub dnd
{
	my $bonus = shift;
	carp '$bonus must be an integer greater than 0, prepended by an optional + or -' unless (($bonus=~/^[+-]?\s?\d+$/)||($bonus eq ""));
	my $dc = shift;
	carp 'DC must be an integer' unless ($dc=~/^\d+$/);
	my $roll = roll(1, 20, $bonus);
	my $result;

	if ($roll->{total}>=$dc)
	{
		$result = "pass";
	}
	else
	{
		$result = "fail";
	}

	$roll->{result}=$result;

	return $roll;
}


sub wod
{
		my $dice	= shift;
		my $again	= shift;
		my $rote	= shift;
		my $target	= 7;

	croak '"X-again" must be an integer between 8 and 10' unless (($again=~/^\d+$/) && (8 <= $again) && ($again <= 10));
	croak 'number of dice must be an integer' unless ($dice=~/^\d+$/);

 	if ($dice <= 0)
 	{
 		$again = 10;
 		$dice = 1;
 		$target = 10;
 	}


	my @list = recursive_rolling($dice,10,$again);
	if (defined $rote)
	{
		if ($rote =~ /r(?:ote)?/i)
		{
			my $rote = grep{$_<$target} ($list[0]..$list[$dice-1]);
			push @list, (recursive_rolling($rote,10,$again)) if $rote > 0;
			undef $rote;
		}
		else
		{
			carp 'for "rote" rolls, append "r" or "rote"' unless $rote eq "";
		}
	}

	$target = grep {$_>=$target}@list;
	return 
	{
		total	=> $target,
		list	=> \@list
	};
}







sub warhammer
{
	my $number = shift;
	croak 'number must be an integer greater than 0' unless (($number=~/^\d+$/) && ($number>0));
	my $target = shift;
	croak 'check must be an integer between 2 and 6' unless (($target=~/^\d+$/) && (2<=$target) && ($target<=6));
	
	my $roll = roll($number, 6);
	$roll->{total} = grep {$_>=$target} @{$roll->{list}};

	return $roll;
}

sub gurps_crits
{
	my $roll = shift;
	my $skill = shift;
	my $result;

	if ($roll <= 6 && $roll <= ($skill-10))
	{
		$result = "critical";
	}
	elsif (($roll >= 17 && ($roll-$skill) >=2)||(($roll-10)>=$skill))
	{
		$result = "critical fail";
	}
	elsif ($roll <= $skill)
	{
		$result = "pass";
	}
	else
	{
		$result = "fail";
	}

	return $result;
}

1;
