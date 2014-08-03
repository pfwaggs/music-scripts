#!/usr/bin/env perl
# vim: ai si sw=4 sts=4 et fdc=4 fmr=AAA,ZZZ fdm=marker
# this is used to merge the readerware db with the dmp3 db.
#   should I use an array for the pseudo numbers %pn?
#   work on a local version of the menu choice routine. easy to do
#   code needs to be cleaned and some modules needs to be installed
#   path::tiny, term::readline::gnu, carp (a system upgrade, not just for
#   this program)
#

# preamble #AAA
use strict;
use warnings;
use feature ':5.10';
use Text::Fuzzy;
use Carp qw(cluck);
use Getopt::Long qw(:config no_ignore_case auto_help);
use Data::Dumper;
use Path::Tiny;

my %munged;
my %verified;
my %dmp3;
my %rdrw;
my $total;
my $count;

my %opts = (
           min => '0001',
           max => '0100',
          quit => 0,
          test => [],
          rdrw => '',
          dmp3 => '',
         space => 1,
         munge => 1,
         match => 1,
         error => 0,
        output => 'results',
      problems => 'problems',
    hand_check => 'hand_check',
        verify => 'verified',
);
my @opts = (
    'min|m=s',
    'max|M=s',
    'quit|q',
    'rdrw|r=s',
    'dmp3|d=s',
    'output|o=s',
    'space|s!',
    'munge|mu=i',
    'match|ma=i',
    'error|e',
    'verify|v=s',
    'test|t=s@' => sub { push @{$opts{test}}, lc $_[1] },
);
GetOptions(\%opts, @opts) or die 'illegal options, ';
die 'missing rdrw file' unless exists $opts{rdrw} and -s $opts{rdrw};
die 'missing dmp3 file' unless exists $opts{dmp3} and -s $opts{dmp3};
if ( ! defined $opts{output} ) {
    (my $base = $opts{dmp3}) =~ s/.\w*$//;
    $opts{output} = $base.'-db.txt';
}
my $space = $opts{space} ? ' ' : '';
my $nl = "\n";
my $tab = "\t";

my $RESULTS  = path($opts{output})->openw();
my $PROBLEMS = path($opts{problems})->openw();

#ZZZ

# munger routines #AAA
my %munger = (
    1 => sub {
            my $_ = $_[0];
            s,[&|/], and ,g;
            s/^\s+//g;
            s/\W/$space/g;
            s/^\s+//;
            $_ = lc;
        },
    2 => sub {
            my %count;
            my $_ = $_[0];
            $_ = lc;
            s/\W//g;
            $count{$_}++ foreach split(//, $_);
            join('', sort keys %count);
    },
    3 => sub {
            my %count;
            my $_ = $_[0];
            $_ = lc;
            s/\W//g;
            $count{$_}++ foreach split(//, $_);
            join('', sort {$count{$a} <=> $count{$b}} keys %count);
    },
    4 => sub {
            my %count;
            my $_ = $_[0];
            $_ = lc;
            s/\W//g;
            $count{$_}++ foreach split(//, $_);
            join('', map {$_,$count{$_}} sort keys %count);
    },
    5 => sub {
            my %count;
            my $_ = $_[0];
            $_ = lc;
            s/\W//g;
            $count{$_}++ foreach split(//, $_);
            join(' ', map {$_.$count{$_}} sort {$count{$b} <=> $count{$a}} keys %count);
    },
);
#ZZZ

# match routines #AAA
my %match = (
    1 => sub {
        my $thresh_hold = 0.7; # empirical
        my $ls = 0;
        my $sl = 0;
        my $return = 0;
        my @input = ();

        push @input, map{[split /\s+/]} @_;
        my ($short, $long) = (@{$input[0]} <= @{$input[1]}) ? (@input) : reverse @input;
        my $long_str = join(' ', @$long);
        my $short_str = join(' ', @$short);
        if ($long_str eq $short_str) {
            $return = 4;
        } else {
            my @matched = grep {$long_str =~ /\b$_\b/i} @$short;
            $ls = 2 if (@matched/@$long > $thresh_hold);
            $sl = 1 if (@matched/@$short > $thresh_hold);
            $return = $sl + $ls;
        }
        return $return;
    },
    2 => sub {
        my $tf = Text::Fuzzy->new($_[1]);
        return $tf->distance($_[0]);
    },
    3 => sub {
        my ($short, $long) = (length $_[0] <= length $_[1]) ? (@_) : reverse @_;
        return ($short =~ /$long/)?1:0;
    },
);
#ZZZ

# load readerware db #AAA
my $RDRW = path($opts{rdrw})->openr();

while (my $line = (<$RDRW>)) {
    next if $line =~ /USER/;
    chomp $line;
    my ($diskid, $artist, $album) = split /\t/, $line;

    next if $diskid lt $opts{min} or $opts{max} lt $diskid; # limits rdrw range to specific diskids

    # limit test group to lines matching pattern
    if ( @{$opts{test}} ) {
        next unless grep {$album =~ /$_/i} @{$opts{test}};
    }

    $munged{$album}  = $munger{$opts{munge}}($album)  unless exists $munged{$album};
    $rdrw{$diskid}{album} = $album;
    $rdrw{$diskid}{artist} = $artist;
}
#ZZZ

# read / write verify #AAA
if ( -s $opts{verify} ) {
    my $IF = path($opts{verify})->openr();
    while (<$IF>) {
        chomp;
        my ($diskid, $album) = split /\t/;
        push @{$verified{$diskid}}, $album;
    }
    close $IF;
    @{$verified{$_}} = sort @{$verified{$_}} foreach keys %verified;
}
my $VERIFIED = path($opts{verify})->openw();
#ZZZ

# load dmp3 #AAA
my $DMP3 = path($opts{dmp3})->openr();
my %pn; #pseudo numbers to go with albums.  need unique items.
my $next = 1;
while (my $line = (<$DMP3>)) {
    chomp $line;
    my ( $song, $artist, $album, $track, $time, $genre, $date ) = split /\t/, $line;
    my $n = (grep {$pn{$_} eq $album} keys %pn)[0];
    if ( ! defined $n ) {
        $n = $next++;
        $pn{$n} = $album;
    }
    $track =~ s/ of.*//;
    $track = substr('00'.$track, -2);
    @{$dmp3{$n}{$track}}{qw/artist song time genre date/} = ($artist, $song, $time, $genre, $date);
}
$total = keys %dmp3;
#ZZZ

# display_dmp3 #AAA
sub display_dmp3 {
    my $n = shift;
    my %artists;
    my @tracks = sort keys %{$dmp3{$n}};
    foreach my $track ( @tracks ) {
        $artists{$dmp3{$n}{$track}{artist}} = 1;
    }
    system('clear');
   say STDERR "($count/$total) $pn{$n}";
    foreach my $track ( @tracks ) {
       say STDERR $tab.join(' // ', $track, @{$dmp3{$n}{$track}}{qw/time artist song/});
    }
}
#ZZZ

# get_choice #AAA
sub get_choice {
    my $rtn = undef;
    my $db = shift; #expecting hashref with artist and album slices
    my $scores = shift; #hashref of scores by diskid
    print STDERR $nl;
    say STDERR join($tab, $scores->{$_}, $_, @{$db->{$_}}{qw/artist album/}) foreach @_;

    print STDERR 'your choice? ';
    chomp(my $REPLY = <STDIN>);
    if ($REPLY =~ /\s/) {
        $rtn = $_[0];
    } elsif ( $REPLY =~ /\d{4}/ ) {
        $rtn = $REPLY;
    }
    return $rtn;
}
#ZZZ

# main #AAA
my @problems;

# first pass #AAA
# first we make a pass and check for single matching albums in verified hash
foreach my $n ( keys %dmp3 ) {
    # checking verified for album and update entry
#    my @matched = grep {$album eq $verified{$_}} keys %verified; # these should be exact hits
    my @matched;
    my $album = $pn{$n};
    foreach my $key (keys %verified) {
#        push @matched, $key if grep {$album eq $_} split /\|/, $verified{$key};
        push @matched, $key if grep {$album eq $_} values @{$verified{$key}};
    }
    my $disk;
    next unless @matched;
    $count++;
    if ( 1 == @matched ) {
        $disk = $matched[0];
#       say STDERR 'bingo for '.$n.' being '.$disk.' and album '.$album;
    } else {
#       say STDERR join( $tab, $n, $pn{$n});
        die 'we should not be here!';
#        display_dmp3($album);
#        # verified is a bad structure; no artist. won't work with get_choice! $disk = get_choice(\%verified, @matched);
    }
    map {$dmp3{$n}{$_}{diskid} = $disk} keys %{$dmp3{$n}};
}
#ZZZ

# second pass #AAA
# now we look for albums in rdrw hash.  we need to use score here.
foreach my $n ( grep { ! exists $dmp3{$_}{'01'}{diskid}} keys %dmp3 ) {
#   die 'for some reason we are here';
    my $album = $pn{$n};
    my %album_score = ();
    my $album_m  = $munger{$opts{munge}}($album);
    map {$album_score{$_} = $match{$opts{match}}($album_m,$munged{$rdrw{$_}{album}})} keys %rdrw;
    my @album_list = sort { $album_score{$b} <=> $album_score{$a} } grep {$album_score{$_}} keys %album_score;
    if ( @album_list ) {
        my $disk = undef;
        if ( $album_score{$album_list[0]} == 4 ) { #this should be an exact match
            $disk = $album_list[0];
        } elsif (1 <= @album_list) { # we found some possible matches so get input
            display_dmp3($n);
            $disk = get_choice( \%rdrw, \%album_score, @album_list);
        }
        if ( defined $disk ) {
            map {$dmp3{$n}{$_}{diskid} = $disk} keys %{$dmp3{$n}};
            $count++;
            push @{$verified{$disk}}, $album unless grep {$album eq $_} values @{$verified{$disk}};
#            $verified{$disk} = ( exists $verified{$disk} ) ? "$verified{$disk}|$album" : $album;
            say $VERIFIED $disk.$tab.$album;
        } else {
            warn "skipping $album";
        }
    } else {
        push @problems, $album unless grep {$album eq $_} @problems; # rats, no matches
    }
#print STDERR Data::Dumper->Dump([\$album,\%{$dmp3{$album}},$disk],[qw/album dmp3 disk/]) if $album =~ /Beethoven/;
}
#ZZZ

say $PROBLEMS $_ foreach @problems;
my %results;
my %ALBUM;
foreach my $n ( grep {defined $dmp3{$_}{'01'}{diskid}} keys %dmp3) {
    my $album = $pn{$n}; #say STDERR 'found album: '.$album;
    my $diskid = $dmp3{$n}{'01'}{diskid}; #say STDERR 'found diskid: '.$diskid;
    my $disknum = undef;
    while (my($ndx,$val) = each @{$verified{$diskid}}){
        next unless $album eq $val;
        die 'something is wrong, duplicate disknum?' if defined $disknum;
        $disknum = $ndx;
    }
    if ( defined $disknum ) {
        $disknum = substr '00'.(1+$disknum), -2;
        $ALBUM{$diskid.$disknum} = $album;
        @{$results{$diskid.$disknum.$_}}{qw/song time artist genre date/} = @{$dmp3{$n}{$_}}{qw/song time artist genre date/} foreach sort keys %{$dmp3{$n}};
    } else {
        say $PROBLEMS "missing $album";
    }
}

#ZZZ

foreach my $key (sort keys %results) {
    (my $diskid = $key) =~ s/\d\d$//;
    my $ALBUM = $ALBUM{$diskid};
    say $RESULTS join($tab,$key,$ALBUM,@{$results{$key}}{qw/song time artist genre date/});
}
