package Dicebag::Output;

#########################################
#                                       #
# Module to evaluate output from Parser #
#                                       #
#########################################

use warnings;
use Carp;
require Exporter;
@ISA = (Exporter);
@EXPORT = qw(evaluate_output);
use Dicebag::Brain;
use strict;

# Trees are in the form of an array of arrays.
# the first element describes the type of expression
# subsequent elements are the arguments
#
# Dice rolls are stored in an array, where the first
# element is the type of die (i.e. number of sides)
# and subsequent elements are the roll values

my $roll;

sub evaluate_output
{
	my $reference = pop;
	$roll = shift if $_[0];
	my @tree = @$reference;

	# empty arrays will exit here, rather than continuing
	unless (@tree)
	{
		return [""];
	}

	# arrays containing only another array are evaluated
	# before proceeding (unless they are batches of dice)
	if ($#tree == 0 && ref $tree[0] && ${$tree[0]}[0] =~ /[^\d]/)
	{
		return evaluate_output($tree[0]);
	}

	# hash to match expression names to corresponding functions
	my %functions =
		(
		 rule			=> \&rule,
		 positive		=> \&positive,
		 high_low		=> \&high_low,
		 g_l_than		=> \&g_l_than,
		 value			=> \&unary_negative,
		 product		=> \&sum,
		 sum			=> \&sum,
		 wordsum		=> \&wordsum,
		 wordproduct	=> \&wordproduct,
		 word			=> \&word,
		);

	for (keys %functions)
	{
		if ($tree[0] eq $_)
		{
			shift @tree;
			return &{$functions{$_}}(\@tree);
		}
	}

	# if the expression wasn't matched, the array gets another
	# chance, this time matching against the next element, if
	# it is an array
	# this is required to deal with some of the generic names
	# assigned to simple values by Parse::RecDescent
	if (ref $tree[1])
	{
		return evaluate_output($tree[1]);
	}
	# or is simply returned if it is not an array
	else
	{
		return $tree[1];
	}

	croak "unrecognised expression type in tree!\n";
}



sub convert_dice_to_number
# most expressions require dice batches to be converted
# to their sum total. They can call this routine to do so.
{
	my $value = shift;
	if (ref $value)
	{
		# Dice batches will always have at least 2 elements.
		# a sole number in an array should be returned untouched
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
	# if not an array, return the term as-is
	else
	{
		return $value;
	}
}


sub convert_dice_to_string
# some expressions require dice batches to be converted
# to a string. They can call this routine to do so.
{
	my $value = shift;
	if (ref $value)
	{
		# Dice batches will always have at least 2 elements.
		# a sole number in an array should be returned untouched
		if ($#{$value} == 0)
		{
			return ${$value}[0];
		}
		else
		{
			local $" = ', ';
			my $string = "@{$value}[1 .. $#$value]";
			return $string;
		}
	}
	# if not an array, return the term as-is
	else
	{
		return $value;
	}
}
sub check_value
# This sub will check for values that are not a simple string
# and evaluate them before returning them
# most functions should use this on any terms that are not 
# 100% certain to be strings
{
	my $value = shift;
	if (ref $value)
	{
		$value = evaluate_output($value);
	}
	return $value;
}



sub rule
# top-level rule in the grammar.
# simply returns the total of any remaining dice batches
{

	my $value = shift;
	my @array = @$value;
	# everything should have already been simplified
	# by the time we get here. give a warning if there's
	# any excess terms
	if ($array[1])
	{
		carp "DANGER WILL ROBINSON";
	}
	$value = $array[0];
	$value = check_value($value);

	$value = convert_dice_to_number($value);
	return $value;
}

sub positive
# brackets and parentheses are dealt with here.
{
	my $value = shift;
	my @array;

	# not all terms passed to this sub will be in brackets.
	# dereference them only if they're not a string.
	if (ref $value)
	{
		@array = @$value;
	}
	if ($array[0] eq '%D')
	{
		return $roll;
	}
	for (@array)
	{
		$_ = check_value($_);
	}

	# we only need to check the type of brackets if the array
	# contains more than one element
	if (defined $array[1])
	{
		# parentheses simply return what they contain
		if ($array[0] eq "(")
		{
			return $array[1];
		}
		# square brackets, however, give the some total of any
		# dice batches inside them
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



sub high_low
# remove all but the highest or lowest dice from a batch of rolls
# expression should be in the form:
# "number (optional)", "h or l", "dice array"
{
	my $value = shift;
	my @array = @$value;

	# evaluate elements if necessary
	for (@array)
	{
		$_ = check_value($_);
	}

	# return first element if there are no others
	unless ($array[1])
	{
		return $array[0];
	}

	# default behaviour is to keep the top/bottom value only
	# set the number of dice to keep to 1 if not specified
	${$array[0]}[0] ||= 1;
	my $count = ${$array[0]}[0];

	# drop the first element of the dice batch since it contains
	# the number of sides per die, rather than a roll value
	my @dice = @{$array[2]}[1 .. $#{$array[2]}];

	if ($array[1] eq "h")
	{
		@dice = keep_highest(@dice, $count);
	}
	else
	{
		@dice = keep_lowest(@dice, $count);
	}

	# put the first element back in front of the dice array, so that
	# other functions know what kind of dice we have
	return [${$array[3]}[0], @dice];
}

sub g_l_than
# sub to evaluate comparisons of rolls and/or numbers. e.g. "1d6=4"
{
	my $value = shift;
	my @array = @$value;

	# evaluate elements if necessary
	for (@array)
	{
		$_ = check_value($_);
	}
	my $total = 0;

	# return first element if there are no others
	unless ($array[1])
	{
		return $array[0];
	}

	# '=' is fine as a comparison, but the evaluator
	# doesn't like it. change it to '==' here
	if ($array[1] eq "=")
	{
		$array[1] = "==";
	}

	# if the left-hand side of the comparison is a batch of rolls, we want to
	# compare each roll individually, rather than just comparing the total
	if (ref $array[0])
	{
		for (1 .. $#{$array[0]})
		{
			$total ++ if eval("${$array[0]}[$_] $array[1] $array[2]");
		}
	}
	# if it's not a batch of rolls, we can just feed it straight to the evaluator
	else
	{
		my $string = join('',@array);
		$total = eval("$string");
		$total ||= 0;
	}

	return $total;
}

sub unary_negative
# unary negative is calculated here
{
	my $value = shift;
	my @array = @$value;

	# evaluate elements if necessary
	for (@array)
	{
		$_ = check_value($_);
	}

	# return first element unchanged if there is no unary negative operator
	unless ($array[1])
	{
		return $array[0]
	}

	my $operator = $array[0];
	my $number = $array[1];



	if (ref $number)
	{
		for (1 .. $#{$number})
		{
			$number->[$_] = ($number->[$_])*-1;
		}
	}
	else
	{
		$number = $number*-1;
	}

	return $number;
}

sub sum
# aritmetic (+-*/) is calculated here
{
	my $value = shift;
	my @array = @$value;
	# like the dice expression, is left-associative, so we need to dereference twice
	@array = @{$array[0]};

	# evaluate elements if necessary
	for (@array)
	{
		$_ = check_value($_);
	}
	my $lhs = shift @array;
	while ($array[0])
	{

		my $op = shift @array;
		my $rhs = shift @array;
		$rhs = convert_dice_to_number($rhs);
		if ($op eq "/" && $rhs == 0)
		{
			die "Can't divide by zero!";
		}
		if (ref $lhs)
		{
			for (1 .. $#{$lhs})
			{
				$lhs->[$_] = int(eval("$lhs->[$_] $op $rhs"));
			}
		}
		else
		{
			$lhs = int(eval("$lhs $op $rhs"));
		}
	}

	return $lhs;
}


sub wordsum
{
	my $value = shift;
	my @array = @$value;

	# like the dice expression, is left-associative, so we need to dereference twice
	@array = @{$array[0]};

	for (@array)
	{
		$_ = check_value($_);
	}

	my $result = "";

	for (@array)
	{
		$_ = convert_dice_to_string($_);
		$result .= $_ if defined $_;
	}

	return $result;

}


sub wordproduct
{
	my $value = shift;
	my @array = @$value;

	for (@array)
	{
		$_ = check_value($_);
	}

	if (defined $array[1])
	{
		my $lhs = $array[0];
		my $rhs = $array[2];
		$lhs = convert_dice_to_string($lhs);
		$rhs = convert_dice_to_number($rhs);
		return $lhs x $rhs;
	}
	return $array[0];
}


sub word
{
	my $value = shift;
	my @array = @$value;

	for (@array)
	{
		$_ = check_value($_);
	}

	return $array[2];

}


1;

