package Dicebag::Parser;

use warnings;
use Carp;

require Exporter;
@ISA = (Exporter);
@EXPORT = qw(parse_expression);

use strict;
use Dicebag::Brain;
use Dicebag::Formatting;
my ($deepestparens, $matchingparens);
$deepestparens = qr#\(([^\(\)]+|(??{$deepestparens}))\)#;	# regexp to find deepest brackets in expression
$matchingparens = qr#\((?:[^\(\)]|(??{$matchingparens}))*\)#;	# regexp to find matching brackets

sub parse_expression
{
	my $expression = shift;
	$expression =~ s/\s//g; # remove whitespace from dice expression
	croak "Unmatched parentheses in dice expression" unless check_parens($expression);
	my $result = interpret_expression($expression);
	return $result;
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
	$expression =~ s/\)\(/)*(/g;
	$expression =~ s/\d(?=\()/$&*/g;	# lazy way to do implied multiplication
	
	my %rollfunction		=	(	match		=> qr#(?:(?:(?:h|l)\{\d+\})|(?:h+|l+))\d+d\d+#,
									function	=> \&special_roll
								);

	my %diceroutine			=	(	match		=> qr#\d+d\d+#,
									function	=> \&parse_roll,
								);
	my %multiplierroutine	=	(	match		=> qr#\d+[\*\/]\d+#,
									function	=> \&parse_multiplication,
								);
	my %additionroutine		=	(	match		=> qr#\d+[\+\-]\d+#,
									function	=> \&parse_addition,
								);
	my @subroutines = (\%rollfunction,\%diceroutine,\%multiplierroutine,\%additionroutine);
	
	my $verbose = "";

	croak "unexpected operators in dice expression" if $expression =~ /[^\{\}\ddhl\(\)\-\+\*\/#]/;
	$expression = expand_expression($expression);
	until ($expression =~ /^\-?\d+$/)
	{	

		my ($batch, $temp);
		$batch = $expression unless $expression =~ /\(/;

		if ($expression =~ $deepestparens)
			{$batch = $1;}
		$temp = sanitiser($batch);
		until ($batch =~/^\d$/)
		{
			INNER: for (@subroutines)
			{
				if ($batch=~$_->{match})
				{
					my $operators = $&;
					my $result= &{$_->{function}}($operators);

					($result, $verbose) = handle_dice_output($result, $verbose, $operators) if ((ref $result) eq "HASH");

					$operators = sanitiser($operators);
					$batch =~ s/$operators/$result/;
					last INNER;
				}
			}
			$expression =~ s/$temp/$batch/;
			last if $batch =~ /^\-?\d+$/;
		}
	
		$expression =~ s/\((\d+)\)/$1/;
		last if $expression =~ /^\-?\d+$/;
	}
	my $output;
	$output->{total} = $expression;
	$output->{list} = $verbose;
	$output->{standard} = "$output->{total}";
	$output->{verbose} = "$output->{list}Total: $output->{total}";

	return $output;

}




sub parse_operators
{
	my $expression = shift;
	$expression =~ /(\d+)([dhl\*\/\+\-])(\d+)/;
	return ($1, $3, $2);
}

sub sanitiser
{
	my $expression = shift;
	$expression =~ s/[\.\(\)\+\?\*\{\}\[\]\|\\\^\$]/\\$&/g;
	return $expression;
}

sub parse_roll
{
	my $expression = shift;
	my ($dice, $sides, $op) = parse_operators($expression);
	my $result = roll($dice, $sides) if $op =~ /d/;
	return $result;
}

sub parse_multiplication
{
	my $expression = shift;
	my $output;
	my ($a, $b, $op) = parse_operators($expression);
	$output = ($a*$b) if $op eq "*";
	$output = (int($a/$b)) if $op eq "/";
	$output = $output;
	return $output;
}

sub parse_addition
{
	my $expression = shift;
	my $output;
	my ($a, $b, $op) = parse_operators($expression);
	$output = ($a+$b) if $op eq "+";
	$output = ($a-$b) if $op eq "-";
	$output = $output;
	return $output;
}

sub handle_dice_output
{
	my $dice = shift;
	my $verbose = shift;
	my $operators = shift;
	$dice->{outputlist}=convert_to_string(@{$dice->{list}}," + ");
	$verbose .= "[".$operators."]: ($dice->{outputlist}) = ".$dice->{total}."\n";
	return ($dice->{total}, $verbose)
}

sub expand_expression
{

	my $expression = shift;
	while ($expression =~ /#/)
	{
		$expression =~ /((\d+)#($matchingparens))/;
		my $output = (($3."+")x($2-1)).$3;
		my $match = $1;
		$match = sanitiser($match);
		$expression =~ s/$match/($output)/g;
	}
	return $expression
}

sub special_roll
{
	my $expression = shift;
	my $highlow;
	$highlow = "h" if $expression =~ /h/;
	$highlow = "l" if $expression =~ /l/;
	my $number = parse_count($expression, $highlow);
	my ($dice, $sides, $op) = parse_operators($expression);
	my $result;
	$result = keep_highest($dice, $sides, $number) if $highlow eq "h";
	$result = keep_lowest($dice, $sides, $number) if $highlow eq "l";
	return $result;
}

sub parse_count
{
	my $expression = shift;
	my $x = shift;
	my $number;
	if ($expression =~ /\{/)
	{
		$expression =~ /\{(\d+)\}/;
		$number = $1;
	}
	else
	{
		$number = ($expression =~ s/$x/$x/g);
	}
	return $number;
}
