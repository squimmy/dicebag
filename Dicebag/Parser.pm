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
use Dicebag::Evaluator;

my $debug = 1;

#$::RD_ERRORS = 1; $::RD_WARN = 1; $::RD_HINT = 1; # warnings, etc. for RecDescent
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
<autoaction: { [@item] } >

rule		: sum #/^\Z/
		| <error>

positive	: "(" roll ")"
		| "(" sum ")"
		| "[" sum "]"
		| /\d+/
		| <error>


roll		: <leftop: positive ("d" | "D") positive>
		| <error>

recursive	: positive(?) ("r" | "c") "{" (roll | positive) ("<=" | ">=" | "==" | "=" | ">" | "<") positive "}"
		| roll


high_low	: positive(?) ("h" | "l") (recursive | positive)
		| recursive


g_l_than	: high_low ("<=" | ">=" | "==" | "=" | ">" | "<") high_low
		| high_low
		| <error>

value           : g_l_than
		| "-" g_l_than
		| <error>

product		: <leftop: value ("*" | "/") value>
		| <error>

sum		: <leftop: product ("+" | "-") product>
		| <error>
!;

sub parse_expression
{
	my $expression = shift;
	$expression =~ s/\s//g; 					# remove whitespace from dice expression
	$expression =~ s/\d(?=\()/$&*/g;				# lazy way to do implied multiplication
	my $fail = find_expression_errors($expression);
	croak "$fail" if $fail;
	my $parser = Parse::RecDescent->new($grammar);
	my $result = $parser->rule($expression);
	$result = evaluate_tree($result);
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
