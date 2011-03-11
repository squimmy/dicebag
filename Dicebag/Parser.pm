package Dicebag::Parser;

use warnings;
use Carp;
require Exporter;
@ISA = (Exporter);
@EXPORT = qw(parse_expression find_expression_errors);

use strict;
use Dicebag::Brain;

my ($deepestparens, $matchingparens, $hilo, $rprefix, $gtlt);
$deepestparens = qr#\(([^\(\)]+|(??{$deepestparens}))\)#;		# regexp to find deepest brackets in expression
$matchingparens = qr#\((?:[^\(\)]|(??{$matchingparens}))*\)#;	# regexp to find matching brackets
$hilo = qr#(?:(?:h|l)\{\d+\})|(?:h+|l+)#;						# regexp to find high/low function
$rprefix = qr#(?:\d+?[\+\-]?(?:\{\d+\})?)?r#;					# regexp to find recursion prefix
$gtlt = qr#(?:\=[\<\>]?)|(?:[\<\>])#;							# regexp to find <,>,=,<= and >=

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

sub parse_expression
{
	my $expression = shift;
	$expression =~ s/\s//g; # remove whitespace from dice expression
	$expression =~s/\(\)//g; # remove empty brackets
	croak "Unmatched parentheses in dice expression" unless check_parens($expression);
	croak "Unmatched braces in dice expression" unless check_braces($expression);
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
sub interpret_expression
{
	my $expression = shift;
	my $starttime = time;
	$expression =~ s/\)\(/)*(/g;
	$expression =~ s/\d(?=\()/$&*/g;	# lazy way to do implied multiplication
	$expression =~ s/$hilo\(1d/(1d/g;	# remove meaningless h/l operators
	my %recursiveroll		=	(	match		=> qr#$rprefix+\d+d\d+#,
									function	=> \&parse_recursion
								);
	my %specialroll			=	(	match		=> qr#$hilo\d+d\d+#,
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
	my %dicefunction		=	(	match		=> qr#$hilo\([\d\+]+\)#,
									function	=> \&dice_function,
								);
	my %gtlt				=	(	match		=> qr#\([\d\+]+\)$gtlt\d+#,
									function	=> \&gtlt,
								);
	my %stripbrackets		=	(	match		=> qr#^\(+\d+\)*$#,
									function	=> \&strip_brackets,
								);

	my @subroutines = (\%gtlt,\%recursiveroll,\%specialroll,\%diceroutine,\%dicefunction,\%multiplierroutine,\%additionroutine);
	
	my $verbose = "";


	croak "unexpected operators in dice expression" if $expression =~ /[^\=\<\>\{\}\ddrhl\(\)\-\+\*\/#]/;
	$expression = expand_expression($expression);
	until ($expression =~ /^\-?\d+$/)
	{	
		my ($batch, $temp);
		$batch = $expression unless $expression =~ /\(/;

		if ($expression =~ $deepestparens)
			{
				$batch = $1;
				$batch = find_functions($expression, $batch);
			}
		$temp = sanitiser($batch);
		while ($batch)
		{
			print "$batch\n";
			croak "taking too long" if time - $starttime > 3;
			INNER: for (@subroutines)
			{
				if ($batch=~$_->{match})
				{
					my $operators = $&;
					my $result= &{$_->{function}}($operators);
					$operators = sanitiser($operators);
					$batch =~ s/$operators/$result/;
					last INNER;
				}
				else
				{
					while ($batch =~ /^\(+\-?\d+\)+$/)
					{$batch=strip_brackets($batch);}
				}
			}
			last if $batch =~/^[\-\d+\+]+$/;
		}
			$expression =~ s/$temp/$batch/;
		last if $expression =~ /^\-?\d+$/;
		$expression = strip_brackets($expression) if $expression=~/^\(\-?\d+\)$/;
		last if $expression =~/^\-?\d+$/;
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
	$expression =~ s/[\=\<\>\.\(\)\+\?\*\{\}\[\]\|\\\^\$]/\\$&/g if $expression;
	return $expression;
}

sub parse_roll
{
	my $expression = shift;
	my ($dice, $sides, $op) = parse_operators($expression);
	my @rolls = roll($dice, $sides)	if $op =~ /d/;
	my $result = join("+",@rolls);
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
	my @result;
	@result = keep_highest(roll($dice, $sides), $number) if $highlow eq "h";
	@result = keep_lowest(roll($dice, $sides), $number) if $highlow eq "l";
	my $result = join("+",@result);
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

sub find_functions
{
	my $expression = shift;
	my $batch = shift;
	if ($batch =~ /^[\d\+]+$/)
	{
		my $match = sanitiser($batch);
		if ($expression =~ /($hilo\($match\))/)
			{$batch = $1;}
		elsif ($expression =~ /(\($match\)$gtlt\d+)/)
			{$batch = $1;}
		elsif ($expression =~ /(\($match\))/)
			{$batch = $1;}
	}
	return $batch;
}

sub dice_function
{
	my $expression = shift;
	my $highlow;
	my $result;
	$highlow = "h" if $expression =~ /h/;
	$highlow = "l" if $expression =~ /l/;
	my $number = parse_count($expression, $highlow);
	$expression =~ /\(([\d\+]+)\)/;
	my @args = split(/\+/,$1);
	if ($number < @args)
	{
		my @result;
		@result = keep_highest(@args, $number) if $highlow eq "h";
		@result = keep_lowest(@args, $number) if $highlow eq "l";
		$result = join("+",@result);
	}
	else
		{$result = $1}
	return $result;
}


sub gtlt
{
	print "entered gtlt\n";
	my $expression = shift;
	print "expression is $expression\n";
	my $inclusive;
	my $result;
	$inclusive = 1 if $expression =~ /\=/;
	$expression =~ /(\d+)$/;
	my $number = $1;
	$expression =~ /\(([\d\+]+)\)/;
	my @args = split(/\+/,$1);
	if ($inclusive)
	{
		if ($expression =~ /\>/)
			{$result = grep {$_>=$number} @args;}
		elsif ($expression =~ /\</)
			{$result = grep {$_<=$number} @args;}
		else
			{$result = grep {$_==$number} @args;}
	}
	else
	{
		if ($expression =~ /\>/)
			{$result = grep {$_>$number} @args;}
		elsif ($expression =~ /\</)
			{$result = grep {$_<$number} @args;}
	}
	return $result;
}

sub parse_recursion
{
	my $expression = shift;
	my ($threshold, $dice, $sides, $sign, $count, @result, $result);
	while ($expression =~ /r/)
	{
		if ($expression =~ /(?:(\d+)?([\+\-])?(?:\{(\d+)\})?)?r\(?(\d+)d(\d+)\)?/)
		{
			my $batch = $&;
			$dice = $4;	$sides = $5;
			if ($1)
			{$threshold = $1}
			else
			{$threshold = $sides}
			$sign = $2;
			$count = $3;
			if ($sign)
			{
				$sign = "-1" if $sign eq "-";
				$sign = "1" if $sign eq "+";
			}
			$sign ||= 0; $count ||= 0;
			@result = recursive_rolling($dice,$sides,$threshold,$sign,$count);
			$result = join("+",@result);
			$batch = sanitiser($batch);
			$expression =~ s/$batch/$result/;
		}

		elsif ($expression =~ /(?:(\d+)?([\+\-])?(?:\{(\d+)\})?)?r\(?([\d\+]+)\)?/)
		{
			my $batch = $&;
			my @existingdice = split(/\+/,$4);
			if ($1)
				{$threshold = $1}
			else
				{$threshold = $sides}
			$sign = $2;
			$count = $3;
			if ($sign)
			{
				$sign = "-1" if $sign eq "-";
				$sign = "1" if $sign eq "+";
			}
			if ($sign == -1)
				{$dice = grep {$_ <= $threshold} @existingdice;}
			elsif ($sign == 0)
				{$dice = grep {$_ == $threshold} @existingdice;}
			elsif ($sign == 1)
				{$dice = grep {$_ >= $threshold} @existingdice;}
			$sign ||= 0; $count ||= 0;
			@result = recursive_rolling($dice,$sides,$threshold,$sign,$count);
			$result = join("+",@result);
			$result .= $4;
			$batch = sanitiser($batch);
			$expression =~ s/$batch/$result/;
		}
	}
	return $expression;
}

sub strip_brackets
{
	my $expression = shift;
	$expression =~ s/\((\d+)\)/$1/;
	return $expression;
}
