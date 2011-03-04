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
	$expression =~ s/\s//g;
	croak "Unmatched parentheses in dice expression" unless check_parens($expression);
	my @split = split_expression($expression);
	my @parsed = interpret_expression(@split);
	my @rolls = collate_rolls(@parsed);
	return @rolls;
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
	$expression =~ s/\)\(/)*(/g; ### this feels like cheating but I don't care

	while ($expression =~ /[\(\)]/)
	{
		
	}










		
#sub split_expression
#{
#	my $expression = shift;
#	my @split;
#	until ($expression eq "")
#	{
#		print "$expression\n" if $expression; ### need to remove this later
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
#			push @rolls, $temp;
#		}
#		elsif ($_->{bonus})
#		{
#			@{$temp->{list}} = $_->{bonus};
#			$temp->{total} = $_->{bonus};
#			$temp->{sign} = $_->{sign};
#			push @rolls, $temp;
#		}
#		else {croak "this should never happen. check input to collate_rolls()"}
#			
#	}
#	return @rolls;
#}

#sub interpret_expression
#{
#	my @parsed;
#	
#	for (@_)
#	{
#		if (/([\+\-])?(\d+)d(\d+)/i)
#		{
#			my $sign = "";
#			$sign = $1 if $1;
#			print "$_: $sign\n";  ### need to remove this later
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
#			print "$_: $sign\n";### need to remove this later
#			my $hash = {
#						sign	=> $sign,
#						bonus	=> $2,
#					};
#			push @parsed, $hash;
#		}
#		else {croak "parse_expression() has received a string it shouldn't have!"}
#	}
#	return @parsed;
#}
