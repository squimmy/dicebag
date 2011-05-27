package Dicebag::Parser;

use warnings;
use Carp;
require Exporter;
@ISA = (Exporter);
@EXPORT = qw(parse_expression find_expression_errors);

use strict;
use Dicebag::Brain;
use Parse::RecDescent;
use Data::Dumper;

my $debug = 1;

$::RD_ERRORS = 1; $::RD_WARN = 1; $::RD_HINT = 1; # warnings, etc. for RecDescent
#$::RD_TRACE = $debug;

my ($deepestparens, $matchingparens);
$deepestparens = qr#\(([^\(\)]+|(??{$deepestparens}))\)#;		# regexp to find deepest brackets in expression
$matchingparens = qr#\((?:[^\(\)]|(??{$matchingparens}))*\)#;		# regexp to find matching brackets
my $hilo = qr#(?:(?:h|l)\{\d+\})|(?:h+|l+)#;				# regexp to find high/low function
my $rprefix = qr#(?:\d+?[\+\-]?(?:\{\d+\})?)?r#;			# regexp to find recursion prefix
my $gtlt = qr#(?:[\<\>]?\=)|(?:[\<\>])#;				# regexp to find <,>,=,<= and >=
my $operand = qr#(?:\-?\d+)|$matchingparens#;				# rexexp to find operands
my $operator = qr#[\+\-\*\/\d]#;					# regexp to find operators
my $rec_op = qr#r(?:{\d+})?#;						# regexp to find recursive roll operator
my $token_operators = qr#[d\(\)\+\-\*\/]|$hilo|$gtlt|$rec_op#;		# regexp to find any/all tokens
my $binary_operators = qr#[d\/\*\+\-]|$gtlt#;				# regexp to find binary operators
my $unary_operators = qr#$hilo#;					# regexp to find unary operators
my $number = qr#\-?\d+#;						# regexpt to find numbers







my $grammar = q!

rule		: sum #/^\Z/
		{print(Data::Dumper::Dumper(@item)); Dicebag::Parser::convert_dice_to_number($item[1]) }
		| <error>

MULTIPLICATION	: /[\*\/]/
		| <error>

ADDITION	: /[\+\-]/
		| <error>

INTEGER		: /\d+/
		{print(Data::Dumper::Dumper(@item)); $item[1] }
		| <error>


DICE		: "d" | "D"
		| <error>

positive	: "(" roll ")"
		{print(Data::Dumper::Dumper(@item)); $item[2] }
		| "(" sum ")"
		{print(Data::Dumper::Dumper(@item)); $item[2] }
		| "[" sum "]"
		{print(Data::Dumper::Dumper(@item)); Dicebag::Parser::convert_dice_to_number($item[2]) }
		| INTEGER
		{print(Data::Dumper::Dumper(@item)); $item[1] }
		| <error>


roll		: <leftop: positive DICE positive>
		{print(Data::Dumper::Dumper(@item)); 
			my $lhs = shift @{$item[1]};
			while (@{$item[1]})
			{
				$lhs = Dicebag::Parser::convert_dice_to_number($lhs);
				my $op = shift @{$item[1]};
				my $rhs = shift @{$item[1]};
				$rhs = Dicebag::Parser::convert_dice_to_number($rhs);
				if ($op eq 'd' || $op eq 'D')
				{
					my @dice = ($rhs, Dicebag::Brain::roll($lhs,$rhs));
					$lhs = \@dice;
				}
			}
			$lhs;
		}
		| <error>

recursive	: positive(?) ("r" | "c") "{" (roll | positive) ("<=" | ">=" | "==" | "=" | ">" | "<") positive "}"
		{ print(Data::Dumper::Dumper(@item));
			if ($item[5] eq "=")
			{
				$item[5] = "==";
			}
			my $sign;
			my $threshold = $item[6];
			my $count = $item[1];
			if ($item[5] =~ /</)
			{
				$sign = -1;
			}
			elsif ($item[5] =~ />/)
			{
				$sign = 1;
			}
			else
			{
				$sign = 0;
			}
			if ($item[5] \!~ /=/)
			{
				$threshold += $sign;
			}
			if ($item[2] eq "r")
			{
				my $dice = 0;
				for (1 .. $#{$item[4]})
				{
					$dice ++ if eval("${$item[4]}[$_] $item[5] $item[6]");
				}
				if ($dice)
				{
					push @{$item[4]}, Dicebag::Brain::recursive_rolling($#{$item[4]}, ${$item[4]}[0], $threshold, $sign, $count);
				}
				return $item[4];
			}
			else
			{
				for (1 .. $#{$item[4]})
				{
					my @dice;
					if (eval("${$item[4]}[$_] $item[5] $item[6]"))
					{
						@dice = Dicebag::Brain::recursive_rolling(1, ${$item[4]}[0], $threshold, $sign, $count);
						for (my $roll = @dice)
						{
							${$item[4]}[$_] += $roll;
						}
					}
				}
				return $item[4];
			}
		}
		| roll


high_low	: positive(?) ("h" | "l") (recursive | positive)
		{print(Data::Dumper::Dumper(@item));

			my $count = ${$item[1]}[0];
			$count ||= 1;
			my @dice = @{$item[3]}[1 .. $#{$item[3]}];
			print "\@dice is @dice\n";
			print "\$count is $count\n";

			if ($item[2] eq "h")
			{
				@dice = Dicebag::Brain::keep_highest(@dice, $count);
			}
			else
			{
				@dice = Dicebag::Brain::keep_lowest(@dice, $count);
			}

			return [${$item[3]}[0], @dice];
		}
		| recursive


g_l_than	: high_low ("<=" | ">=" | "==" | "=" | ">" | "<") high_low
		{print(Data::Dumper::Dumper(@item));
			my $total = 0;
			if ($item[2] eq "=")
			{
				$item[2] = "==";
			}
			if (ref $item[1])
			{
				for (1 .. $#{$item[1]})
				{
					$total ++ if eval("${$item[1]}[$_] $item[2] $item[3]");
				}
			}
			else
			{
				my $string = join('',@item[1..$#item]);
				$total = eval("$string");
				$total ||= 0;
			}
			return $total;
		}
		| high_low
		{print(Data::Dumper::Dumper(@item)); @item[1] }
		| <error>

value           : g_l_than
		{print(Data::Dumper::Dumper(@item)); $item[1] }
		| "-" g_l_than
		{print(Data::Dumper::Dumper(@item));
			$item[2] = Dicebag::Parser::convert_dice_to_number($item[2]);
			$item[2]*-1;
		}
		| <error>

product		: <leftop: value MULTIPLICATION value>
		{print(Data::Dumper::Dumper(@item));
			for (@{$item[1]})
			{
				$_ = Dicebag::Parser::convert_dice_to_number($_);
			}
			my $total =  eval("@{$item[1]}");
		}
		| <error>

sum		: <leftop: product ADDITION product>
		{print(Data::Dumper::Dumper(@item));
			for (@{$item[1]})
			{
				$_ = Dicebag::Parser::convert_dice_to_number($_);
			}
			my $total =  eval("@{$item[1]}");
		}
		| <error>
!;



sub convert_dice_to_number
{
	my $value = shift;
	if (ref $value)
	{
		my $total = 0;
		for (1 .. $#{$value})
		{
			$total += ${$value}[$_];
		}
		return $total;
	}
	else
	{
		return $value;
	}
}

sub parse_expression
{
	my $expression = shift;
	$expression =~ s/\s//g; 					# remove whitespace from dice expression
	$expression =~ s/\d(?=\()/$&*/g;				# lazy way to do implied multiplication
	print "expression is now: $expression\n";
	my $fail = find_expression_errors($expression);
	croak "$fail" if $fail;
	my $parser = Parse::RecDescent->new($grammar);
	my $result = $parser->rule($expression);
	return $result;
}


sub find_expression_errors
{
	my $fail = 0;
	my $expression = shift;
	$fail = "unmatched parentheses" unless check_parens($expression);
	$fail = "unmatched braces" unless check_braces($expression);
	$fail = "empty string" unless $expression =~ /\d/;
	$fail = "unrecognised character" if $expression =~ /[^#\=\<\>\[\]\(\)\d\-\+\/\*hldrc\{\}]/;
	$fail = "dice operator preceeded by non-numeric value" if $expression =~ /[\(rhld\+\-\*\/\{]d/;
	$fail = "infinite recurisive rolling likely" if $expression =~/(?:[^\d]|^)1\+r/;
	return $fail;
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


sub check_braces
{
	my $expression = shift;
	my $count = 0;
	while ($expression =~ /([\{\}])/g)
	{
		$count++ if $1 eq "{";
		$count-- if $1 eq "}";
		return 0 if $count<0;
	}
	return ($count==0)?1:0;
}
