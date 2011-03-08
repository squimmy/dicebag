package Dicebag::Games;

use warnings;
use Carp;

require Exporter;
@ISA = (Exporter);
@EXPORT = qw(gurps wod warhammer dnd);

use Dicebag::Brain;
use Dicebag::Formatting;

use strict;
sub gurps
{

	my $output = roll(3,6);
	my $skill = shift;
	croak 'skill must be an integer' unless ($skill=~/^\d+$/);
	$output->{result}=gurps_crits($output->{total},$skill);
	$output = gurps_formatting($output);
	return $output;
}

sub dnd
{
	my $bonus = shift;
	croak '$bonus must be an integer greater than 0, prepended by an optional + or -' unless (($bonus=~/^[+-]?\s?\d+$/)||($bonus eq ""));
	my $dc = shift;
	croak 'DC must be an integer' unless ($dc=~/^\d+$/);
	my $output = roll(1, 20, $bonus);
	$output->{result}=dnd_passfail($output->{total}, $dc);
	$output->{dc}=$dc;
	$output = dnd_formatting($output);
	return $output;
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

	my $total = grep {$_>=$target}@list;
	my $output = 
	{
		total	=> $total,
		list	=> \@list
	};
	$output = wod_formatting($output);
	return $output;
}

sub warhammer
{
	my $number = shift;
	croak 'number must be an integer greater than 0' unless (($number=~/^\d+$/) && ($number>0));
	my $target = shift;
	croak 'check must be an integer between 2 and 6' unless (($target=~/^\d+$/) && (2<=$target) && ($target<=6));
	
	my $output = roll($number, 6);
	$output->{total} = grep {$_>=$target} @{$output->{list}};

	$output = warhammer_formatting($output);

	return $output;
}

sub gurps_crits
{
	my $roll = shift;
	my $skill = shift;
	my $result;

	if ($roll <= 6 && $roll <= ($skill-10))
	{
		$result = "critical success";
	}
	elsif (($roll >= 17 && ($roll-$skill) >=2)||(($roll-10)>=$skill))
	{
		$result = "critical failure";
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

sub dnd_passfail
{
	my $roll = shift;
	my $dc = shift;
	return "pass" if ($roll>=$dc);
	return "fail" if ($roll<$dc);
}

sub gurps_formatting
{
	my $output = shift;
	$output->{outputlist} = convert_to_string(@{$output->{list}}," + ");
	
	$output->{standard}="$output->{total}: $output->{result}";

	$output->{verbose}="[3d6]: ($output->{outputlist}) = $output->{total}: $output->{result}";

	return $output;
}

sub dnd_formatting
{
	my $output = shift;
	$output->{standard}="$output->{total}: $output->{result}";

	$output->{verbose}="[1d20+$output->{bonus}] = $output->{total} @ DC$output->{dc}: $output->{result}";

	return $output;
}

sub wod_formatting
{
	my $output = shift;

	$output->{outputlist} = convert_to_string(@{$output->{list}},", ");

	$output->{standard} = "$output->{total}";
	$output->{verbose} = "($output->{outputlist}) = $output->{total}";

	return $output;
}

sub warhammer_formatting
{
	my $output = shift;

	$output->{outputlist} = convert_to_string(@{$output->{list}},", ");

	$output->{standard} = "$output->{total}";
	$output->{verbose} = "($output->{outputlist}) = $output->{total}";

	return $output;
}

1;
