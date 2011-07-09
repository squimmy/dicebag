package Dicebag::Parser;

#############################################
#                                           #
#  Module to create parse trees from input  #
#                                           #
#############################################

use warnings;
use Carp;
require Exporter;
@ISA = (Exporter);
@EXPORT = qw(parse_expression find_expression_errors);

use strict;
use Dicebag::Brain;
use Parse::RecDescent;
use Dicebag::Evaluator;
use Dicebag::Output;

my $debug = undef;

# warnings, etc. for RecDescent
$::RD_ERRORS = 1;
$::RD_WARN = $debug; $::RD_HINT = $debug;
$::RD_TRACE = $debug;

# Regexps to check for parentheses
my $parentheses_match = qr#([\(\)])#;
my $bracket_match = qr#([\[\]])#;
my $brace_match = qr#([\{\}])#;





# Parse::RecDescent Grammar:
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

value		: g_l_than
			| "-" g_l_than
			| <error>

product		: <leftop: value ("*" | "/") value>
			| <error>

sum			: <leftop: product ("+" | "-") product>
			| <error>
!;


my $output_grammar = q!
<autoaction: { [@item] } >

rule		: wordsum #/^\Z/
			| <error>

word		: <skip: ''> "\"" /^\s*[^"]*/ "\""
			| <error>

wordsum		: <leftop: wordproduct ";" wordproduct>
			| <error>

wordproduct	: word "." sum
			| sum "." word
			| sum
			| word
			| <error>

positive	: "(" sum ")"
			| "[" sum "]"
			| /\d+/
			| "%D"
			| <error>

high_low	: positive(?) ("h" | "l") positive
			| positive
			| <error>


g_l_than	: high_low ("<=" | ">=" | "==" | "=" | ">" | "<") high_low
			| high_low
			| <error>

value		: g_l_than
			| "-" g_l_than
			| <error>

product		: <leftop: value ("*" | "/") value>
			| <error>

sum			: <leftop: product ("+" | "-") product>
			| <error>
!;



sub parse_expression
# Parsing is done here.
# The Parser returns a parse tree, made of a reference to an array of terms.
# The terms themselves may be references to an array of their sub-terms.
# The result is then passed to Dicebag::Evaluator to be evaluated!
{
	my $expression = shift;
	my $format = shift;
	$format ||= q!"[";%D;"]= ";[%D]!;
	$expression =~ s/\d(?=\()/$&*/g;				# lazy way to do implied multiplication
	$expression =~ s/(\))(\()/$1*$2/g;
	my $fail = find_expression_errors($expression);
	croak "$fail" if $fail;

	# Initialise Parse::RecDescent parsers
	my $parser = Parse::RecDescent->new($grammar);
	my $output_parser = Parse::RecDescent->new($output_grammar);

	# parse and evaluate roll
	my $result = $parser->rule($expression);
	$result = evaluate_tree($result);

	# parse and evaluate output
	my $output = $output_parser->rule($format);
	$output = evaluate_output($result, $output);


	return $output;
}


sub find_expression_errors
# Basic Sanity check to find things like unmatched brackets or invalid characters.
{
	my $fail = 0;
	my $expression = shift;
	$fail = "unmatched parentheses" unless check_parens($expression, $parentheses_match, "(", ")");
	$fail = "unmatched braces" unless check_parens($expression, $brace_match, "{", "}");
	$fail = "unmatched brackets" unless check_parens($expression, $bracket_match, "[", "]");
	$fail = "empty string" unless $expression =~ /\d/;
	$fail = "unrecognised character" if $expression =~ /[^#\=\<\>\[\]\(\)\d\-\+\/\*hldrc\{\}]/;
	$fail = "dice operator preceeded by non-numeric value" if $expression =~ /[\(rhld\+\-\*\/\{]d/;
	$fail = "infinite recurisive rolling likely" if $expression =~/(?:[^\d]|^)1\+r/;
	return $fail;
}


sub check_parens
{
	my $expression = shift;
	my $match = shift;
	my $open = shift;
	my $close = shift;

	my $count = 0;
	while ($expression =~ /$match/g)
	{
		$count++ if $1 eq "$open";
		$count-- if $1 eq "$close";
		return 0 if $count<0;
	}
	return ($count==0)?1:0;
}
