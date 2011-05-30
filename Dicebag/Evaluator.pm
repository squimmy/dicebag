package Dicebag::Evaluator;

use warnings;
use Carp;
require Exporter;
@ISA = (Exporter);
@EXPORT = qw(evaluate_tree);

use strict;
use Dicebag::Brain;
use Data::Dumper;

sub evaluate_tree
{
	my $reference = shift;
	my @tree = @$reference;

	unless (@tree)
	{
		return [""];
	}

	if ($#tree == 0 && ref $tree[0] && ${$tree[0]}[0] =~ /[^\d]/)
	{
		return evaluate_tree($tree[0]);
	}

	my %functions =
		(
		 rule		=> \&rule,
		 positive	=> \&positive,
		 roll		=> \&dice,
		 recursive	=> \&recursive,
		 high_low	=> \&high_low,
		 g_l_than	=> \&g_l_than,
		 value		=> \&value,
		 product	=> \&sum,
		 sum		=> \&sum,
		);

	for (keys %functions)
	{
		if ($tree[0] eq $_)
		{
			shift @tree;
			return &{$functions{$_}}(\@tree);
		}
	}
		if (ref $tree[1])
		{
		return evaluate_tree($tree[1]);
		}
		else
		{
			return $tree[1];
		}

	croak "something bad happened!\n";
}



sub convert_dice_to_number
{
	my $value = shift;
	if (ref $value)
	{
		if ($#{$value} == 0)
		{
			return ${$value}[0];
		}
		else
		{
			my $total = 0;
			for (1 .. $#{$value})
			{
				$total += ${$value}[$_];
			}
			return $total;
		}
	}
	else
	{
		return $value;
	}
}

sub rule
{
	my $value = shift;
	my @array = @$value;
	if ($array[1])
	{
		croak "DANGER WILL ROBINSON";
	}
	$value = $array[0];
	$value = check_value($value);

	$value = convert_dice_to_number($value);
	return $value;
}

sub positive
{
	my $value = shift;
	my @array;
	if (ref $value)
	{
		@array = @$value;
	}
	else
	{
		return $value;
	}
	for (@array)
	{
		$_ = check_value($_);
	}

	if ($array[1])
	{
		if ($array[0] eq "(")
		{
			return $array[1];
		}
		else
		{
			return convert_dice_to_number($array[1]);
		}
	}
	else
	{
		return $array[0];
	}
}

sub dice
{
	my $value = shift;
	my @array = @$value;
	@array = @{$array[0]};
	for (@array)
	{
		$_ = check_value($_);
	}
	unless ($array[1])
	{
		return $array[0];
	}
	if (ref $array[0])
	{
		@array = @{$array[0]};
	}

	my $lhs = shift @array;
	while ($array[0])
	{
		$lhs = convert_dice_to_number($lhs);
		my $op = shift @array;
		my $rhs = shift @array;
		$rhs = convert_dice_to_number($rhs);
		if ($op eq 'd' || $op eq 'D')
		{
			my @dice = ($rhs, roll($lhs, $rhs));
			$lhs = \@dice;
		}
	}

	return $lhs;
}

sub recursive
{
	my $value = shift;
	my @array = @$value;
	for (@array)
	{
		$_ = check_value($_);
	}
	unless ($array[1])
	{
		return $array[0];
	}
	if ($array[4] eq "=")
	{
		$array[4] = "==";
	}
	my $sign;
	my $threshold = $array[5];
	my $count = $array[0];
	$count ||= 1;
	if ($array[4] =~ /</)
	{
		$sign = -1;
	}
	elsif ($array[4] =~ />/)
	{
		$sign = 1;
	}
	else
	{
		$sign = 0;
	}
	if ($array[4] !~ /=/)
	{
		$threshold += $sign;
	}

	if ($array[1] eq "r")
	{
		my $dice = 0;
		for (1 .. $#{$array[3]})
		{
			$dice++ if eval("${$array[3]}[$_] $array[4] $array[5]");
		}
		if ($dice)
		{
			push @{$array[3]}, recursive_rolling($#{$array[3]}, ${$array[3]}[0], $threshold, $sign, $count);
		}
	}
	else
	{
		for(1 .. $#{$array[3]})
		{
			my @dice;
			if (eval("${$array[3]}[$_] $array[4] $array[5]"))
			{
				@dice = recursive_rolling(1, ${$array[3]}[0], $threshold, $sign, $count);
				for my $roll (@dice)
				{
					${$array[3]}[$_] += $roll;
				}
			}
		}
	}

	return $array[3];
}

sub high_low
{
	my $value = shift;
	my @array = @$value;
	for (@array)
	{
		$_ = check_value($_);
	}

	unless ($array[1])
	{
		return $array[0];
	}
	${$array[0]}[0] ||= 1;
	my $count = ${$array[0]}[0];
	my @dice = @{$array[2]}[1 .. $#{$array[2]}];

	if ($array[1] eq "h")
	{
		@dice = keep_highest(@dice, $count);
	}
	else
	{
		@dice = keep_lowest(@dice, $count);
	}

	return [${$array[3]}[0], @dice];
}

sub g_l_than
{
	my $value = shift;
	my @array = @$value;
	for (@array)
	{
		$_ = check_value($_);
	}
	my $total = 0;

	unless ($array[1])
	{
		return $array[0];
	}
	if ($array[1] eq "=")
	{
		$array[1] = "==";
	}
	if (ref $array[0])
	{
		for (1 .. $#{$array[0]})
		{
			$total ++ if eval("${$array[0]}[$_] $array[1] $array[2]");
		}
	}
	else
	{
		my $string = join('',@array);
		$total = eval("$string");
		$total ||= 0;
	}

	return $total;
}

sub value
{
	my $value = shift;
	my @array = @$value;
	for (@array)
	{
		$_ = check_value($_);
	}
	unless ($array[1])
	{
		return $array[0]
	}
	$array[1] = convert_dice_to_number($array[1]);

	return ($array[1]*-1);
}

sub sum
{
	my $value = shift;
	my @array = @$value;
	@array = @{$array[0]};
	for (@array)
	{
		$_ = check_value($_);
	}

	for (@array)
	{
		$_ = convert_dice_to_number($_);
	}
	my $total = eval("@array");

	return $total;
}

sub check_value
{
	my $value = shift;
	if (ref $value)
	{
		$value = evaluate_tree($value);
	}
	return $value;
}
1;

