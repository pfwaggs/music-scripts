package Menu;

use Data::Printer;
use strict;
use warnings;
use v5.18;
use experimental qw(smartmatch autoderef);

# _parse_choice #AAA
sub _parse_choice {
    my @valid = @{shift @_};
    my @in = split /\s/, shift =~ s/^$/quit/r;

    my %rtn = (msg => undef, selections => undef);

    my %parse;
    $parse{quit} = {key=>'msg', val=>0};
    $parse{help} = {key=>'msg', val=>1};
    $parse{all} = {key => 'selections', val => [@valid]};

    my @in_parse = grep {exists $parse{$_}} @in;

    if (my $cmd = shift @in_parse) {
	$rtn{$parse{$cmd}{key}} = ref $parse{$cmd}{val} eq 'ARRAY' ? [@{$parse{$cmd}{val}}] : $parse{$cmd}{val};
    } else {
	push @{$rtn{selections}}, grep {$_ ~~ @valid} @in;
    }

    $rtn{msg} = -1 if (! defined $rtn{msg} and ! defined $rtn{selections});

    return wantarray ? %rtn : \%rtn;
}
#ZZZ

# Pick #AAA
sub Pick {
    # {config params}, {%data, keys=>[], (help=>[])}

    my %opts = (
	header  => undef,
	prompt  => 'pick lines: ',
	clear   => 1,
	max     => 1,
	presets => [],
	help    => ['quit', 'all'],
    );
    %opts = (%opts, %{shift @_}) if ref $_[0] eq 'HASH';
    my %data = ref $_[0] eq 'HASH' ? %{shift @_} : (@_);
    my @keys = @{$data{keys}};
    push $opts{help}, @{$data{help}} if exists $data{help};
    my $max = $opts{max} == -1 ? @keys : $opts{max};

    my $picked = '*';
    my $toggle = $picked^' ';
    my @choices = (' ') x @keys;
    my $seq = 1;

    my %_menu = map {$_ => {str=>$data{$_}, s=>' '}} @keys;
    for (@{$opts{presets}}) {
	$_menu{$_}{s} ^= $toggle;
	$_menu{$_}{order} = $seq++;
    }
#warn '_menu: '; p %_menu;
    my $input;
    while (1) {
	system('clear') if $opts{clear};
	say $opts{header} if defined $opts{header};

	say join(' : ', sprintf("%2s", $_), @{$_menu{$_}}{qw{s str}}) for @keys;

	print $opts{prompt};
	chomp ($input = <STDIN>);
	my %action = _parse_choice(\@keys, $input);
	if (defined $action{msg}) {
	    say 'invalid input' if -1 == $action{msg};
	    last if 0 == $action{msg};
	    say for @{$opts{help}};
	    my $dummy = <STDIN>;
	}
	for (@{$action{selections}}) {
	    $_menu{$_}{s} ^= $toggle;
	    $_menu{$_}{order} = $seq++;
	}
    } continue {
	last if (($max == grep {$_menu{$_}{s} eq $picked} keys %_menu) and ($input !~ /^all/i));
    }
    my @found = sort {$_menu{$a}{order} <=> $_menu{$b}{order}} grep {$_menu{$_}{s} eq $picked} keys %_menu;
    my @rtn = @found <= $max ? @found : @found[0..$max-1];
    return wantarray ? @rtn : \@rtn;
}
#ZZZ

1;
