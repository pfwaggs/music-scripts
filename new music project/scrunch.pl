#!/usr/bin/env perl

# vim: ai si sw=4 sts=4 et fdc=4 fmr=AAA,ZZZ fdm=marker

# normal junk #AAA
use warnings;
use strict;
use v5.18;

#use Getopt::Long qw( :config no_ignore_case auto_help );
#my %opts;
#my @opts;
#my @commands;
#GetOptions( \%opts, @opts, @commands ) or die 'something goes here';
#use Pod::Usage;
#use File::Basename;
#use Cwd;

use Path::Tiny;
use JSON::PP;
use Data::Printer;

our $dir;
BEGIN {
    our $dir = Path::Tiny->cwd;
    $dir = path($dir)->parent if $dir =~ m{/bin$};
    $dir = path($dir)->stringify;
    unshift @INC, "$dir/lib" unless grep {/$dir/} @INC;
}
use Menu;

#ZZZ

my @lines = path(shift)->lines({chomp=>1});
my %data;
for (@lines) {
    my ($artist, $album, $song) = split m{/}, $_;
    my $new_artist = $artist =~ s/\&/ and /gr;
    my @list = sort split //, lc($new_artist =~ s/\W//gr);
    my $artist_scrunched = join('',@list);
    push @{$data{$artist_scrunched}}, "$artist/$album" unless "$artist/$album" ~~ @{$data{$artist_scrunched}};
}
my $jpp_out = JSON::PP->new->pretty->utf8;
path('testing')->spew($jpp_out->encode(\%data));
p %data;
