package Dicebag::Parser;

use warnings;
use Carp;
require Exporter;
@ISA = (Exporter);
@EXPORT = qw(parse_expression find_expression_errors);

use strict;
use Dicebag::Brain;
use Data::Dumper;

my ($deepestparens, $matchingparens);
$deepestparens = qr#\(([^\(\)]+|(??{$deepestparens}))\)#;		# regexp to find deepest brackets in expression
$matchingparens = qr#\((?:[^\(\)]|(??{$matchingparens}))*\)#;	# regexp to find matching brackets
my $hilo = qr#(?:(?:h|l)\{\d+\})|(?:h+|l+)#;						# regexp to find high/low function
my $rprefix = qr#(?:\d+?[\+\-]?(?:\{\d+\})?)?r#;					# regexp to find recursion prefix
my $gtlt = qr#(?:[\<\>]?\=)|(?:[\<\>])#;							# regexp to find <,>,=,<= and >=
my $operand = qr#(?:\-?\d+)|$matchingparens#;						# rexexp to find operands
my $operator = qr#[\+\-\*\/\d]#;									# regexp to find operators
my $rec_op = qr#r(?:{\d+})?#;									# regexp to find recursive soll operator
my $token_operators = qr#[d\(\)\+\-\*\/]|$hilo|$gtlt|$rec_op#;	# regexp to find any/all tokens
my $binary_operators = qr#[d\/\*\+\-]|$gtlt#;						# regexp to find binary operators
my $unary_operators = qr#$hilo#;									# regexp to find unary operators
my $number = qr#\-?\d+#;											# regexpt to find numbers

sub parse_expression
{
	my $expression = shift;
	$expression =~ s/\s//g; 							# remove whitespace from dice expression
	$expression =~ s/\d(?=\()/$&*/g;					# lazy way to do implied multiplication
	my $fail = find_expression_errors($expression);
	croak "$fail" if $fail;
	#let's put a whole pile of brackets everywhere!
	$expression =~ s/(${operand}#${operand})/($1)/g;
	$expression =~ s/(${operand}d${operand})/($1)/g;
	$expression =~ s/(${operand}?r${operand})/($1)/g;
	$expression =~ s/(${hilo}${operand})/($1)/g;
	$expression =~ s/(${operand}${gtlt}${operand})/($1)/g;
	$expression =~ s/(${operand}[\/\*]${operand})/($1)/g;
	$expression =~ s/(${operand}[\+\-]${operand})/($1)/g;
	#ok now that's out of the way...

	$expression = expand_expression($expression);

	my @tokens = lex($expression);
	@tokens = reverse@tokens;

	my $tree = {};
	$tree = parse(@tokens);

	my $result;

	if ($tree)
	{
		$result = evaluate($tree);
	}
	else
	{
		$result = '*ERROR*';
	}

	return $result;
}

sub parse
{
	my @tokens = @_;
	my $node;
	my @temp;
	my $token;
	while (@tokens)
	{
		$token = shift(@tokens);


		if ($token eq ")")
		{
			($token, @tokens) = parse(@tokens);
		}
		elsif ($token eq "(")
		{
			if (@temp == 1)
			{
				$node = $temp[0];
			}
			return ($node, @tokens);
		}
		if ($token)
		{
			push @temp, $token;
			if (@temp == 2)
			{
				if ($token =~ /$unary_operators|$rec_op/)
				{
					$node->{op} = $token;
					$node->{rhs} = $temp[0];
					undef @temp; undef $token;
				}
			}
			elsif (@temp == 3)
			{
				if ($temp[1] =~ /$binary_operators/)
				{
					$node->{lhs} = $temp[2];
					$node->{rhs} = $temp[0];
					$node->{op} = $temp[1];
					undef @temp; undef $token;
				}
			}
		}
	}
	if (!@tokens && @temp == 1)
	{
		$node =  $temp[0];
	}
	if (@tokens)
	{
		return $node, @tokens;
	}
	else
	{
		return $node;
	}
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

sub expand_expression
{
	my $expression = shift;
	while ($expression =~ /($operand)#($operand)/)
	{
		my $lhs = parse_expression($1);
		my $lhsold = quotemeta($1);
		my $rhs = (("($2)+"x($lhs-1))."($2)");
		my $rhsold = quotemeta($2);
		$expression =~ s/${lhsold}#${rhsold}/${lhs}#${rhs}/;
	}
	return $expression;
}

sub lex
{
	my $expression = shift;
	my @tokens;
	while ($expression)
	{
		if (!@tokens)
		{
			$expression =~ s/^((?:\-?\d+)|$token_operators)//;
			push @tokens, $1;
		}
		elsif ($tokens[$#tokens] =~ /$number|\)/)
		{
			$expression =~ s/^($token_operators)//;
			push @tokens, $1;
		}
		else
		{
			$expression =~ s/^((?:\-?\d+)|$token_operators)//;
			push @tokens, $1;
		}
	}
	return @tokens;
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











my @operators = (
{	operator	=> "+",
	function	=> \&add
},{
	operator	=> "-",
	function	=> \&subtract
},{
	operator	=> "/",
	function	=> \&divide
},{
	operator	=> "*",
	function	=> \&multiply
},{
	operator	=> "d",
	function	=> \&dice
},{
	operator	=> "r",
	function	=> \&recursive_dice
});

sub evaluate
{
	my $tree = shift;
	if (ref ($tree))
	{
		$tree =  calculate($tree);
	}
	return $tree;
}
	 
sub calculate
{
	my $node = shift;
	my $lhs = evaluate($node->{lhs});
	my $rhs = evaluate($node->{rhs});
	for (@operators)
	{
		if ($node->{op} eq $_->{operator})
		{
			return &{$_->{function}}($lhs,$rhs);
		}
	}
	croak "encountered unknown operator";
}
  


sub add
{
	my $lhs = shift;
	my $rhs = shift;
	return ($lhs + $rhs);
}

sub subtract
{
	my $lhs = shift;
	my $rhs = shift;
	return ($lhs - $rhs);
}

sub divide
{
	my $lhs = shift;
	my $rhs = shift;
	return (int ($lhs / $rhs));
}

sub multiply
{
	my $lhs = shift;
	my $rhs = shift;
	return ($lhs * $rhs);
}

sub dice
{
	my $lhs = shift;
	my $rhs = shift;
	return ($lhs * $rhs);
}
