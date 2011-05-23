package Dicebag::Parser;

use warnings;
use Carp;
require Exporter;
@ISA = (Exporter);
@EXPORT = qw(parse_expression find_expression_errors);

use strict;
use Dicebag::Brain;
use Parse::RecDescent;

$::RD_ERRORS = 1; $::RD_WARN = 1; $::RD_HINT = 1; # warnings, etc. for RecDescent
$::RD_TRACE = 1;

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

rule		: high_low

MULTIPLICATION	: /[\*\/]/

ADDITION	: /[\+\-]/

INTEGER		: /-?\d+/
		{ $item[1] }

DICE		: "d" | "D"

value		: INTEGER
		{ $item[1] }
		| "(" sum ")"
		{ $item[2] }

roll		: <leftop: value DICE value>
		{
			my $lhs = shift @{$item[1]};
			while (@{$item[1]})
			{
				my $op = shift @{$item[1]};
				my $rhs = shift @{$item[1]};
				if ($op eq 'd' || $op eq 'D')
				{
					my $total = 0;
					my @dice = Dicebag::Brain::roll($lhs,$rhs);
					$total += $_ for @dice;
					$lhs = $total;
				}
			}
			$lhs;
		}

product		: <leftop: roll MULTIPLICATION roll>
		{
			my $total =  eval("@{$item[1]}");
		}

sum		: <leftop: product ADDITION product>
		{
			my $total =  eval("@{$item[1]}");
		}
!;

sub parse_expression
{
	my $parser = Parse::RecDescent->new($grammar);
	my $expression = shift;
	$expression =~ s/\s//g; 							# remove whitespace from dice expression
		$expression =~ s/\d(?=\()/$&*/g;					# lazy way to do implied multiplication
		my $fail = find_expression_errors($expression);
	croak "$fail" if $fail;

#print ($parser->startrule($expression));

	my $result = $parser->rule($expression);
	if ($result)
	{
		return $result;
	}
	else
	{
		croak "bad parse\n";
		return 0;
	}
	return 1;
}

sub find_expression_errors
{
	my $fail = 0;
	my $expression = shift;
	$fail = "unmatched parentheses" unless check_parens($expression);
	$fail = "unmatched braces" unless check_braces($expression);
	$fail = "empty string" unless $expression =~ /\d/;
	$fail = "unrecognised character" if $expression =~ /[^\=\<\>\(\)\d\-\+\/\*hldr\{\}]/;
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
