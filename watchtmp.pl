#!/usr/bin/env perl

# https://github.com/CLCL/watchtmp

use strict;
use warnings;
use 5.010;
use File::Spec;
use Term::ANSIColor;

use File::Basename;

use lib File::Spec->catdir(dirname(__FILE__), 'local', 'lib', 'perl5');

use AnyEvent::Inotify::Simple;
use EV; # or POE, or Event, or ...

my $watchdir = '/tmp'; # 監視するディレクトリ

my $dic_size  = {};
my $dic_shown = {};
my $inotify = AnyEvent::Inotify::Simple->new(
  directory      => $watchdir,
  event_receiver => sub {
    my ($event, $file, $moved_to) = @_;
    given($event) { # open, close, delete, create, modify, access
      my $dt = gettime();
      my $path = File::Spec->catdir($watchdir, $file);
      if (my $size = -s $path) {
        when('delete') {
          $dic_size->{$file} = $size;
          delete $dic_size->{$file};
          delete $dic_shown->{$file};
        }
        when('access') {
          if ( (exists $dic_size->{$file})
               && ($dic_size->{$file} == $size)
               && (!exists $dic_shown->{$file}) ) {
            $dic_shown->{$file} = 1;
            show($event, $size, $path);
          }
          else {
            $dic_size->{$file} = $size;
          }
        }
        default {
          $dic_size->{$file} = $size;
          delete $dic_shown->{$file};
        }
      }
    };
  },
);

EV::loop;

sub nice_size {
  my @sizes = qw( B KB MB GB TB PB);
  my $size  = shift;
  my $i = 0;
  while ($size > 1024) {
    $size = $size / 1024;
    $i++;
  }
  return sprintf("%.3f$sizes[$i]", $size);
}

sub gettime {
  my ($sec,  $min, $hour, $mday, $mon,
      $year, undef, undef, undef) = localtime;
  return sprintf('%04d-%02d-%02dT%02d:%02d:%02d',
                 $year+1900, ++$mon, $mday, $hour, $min, $sec
  );
}

sub colorize {
    my $size = shift;
    my $color;
    if ( $size > 10 * 1024 * 1024 ) { #10MB;
      $color = color('red');
    }
    elsif ( $size > 1 * 1024 * 1024 ) { # 1MB
      $color = color('yellow');
    }
    else {
      $color = color('white');
    }
    return $color;
}
sub show {
  my $event = shift;
  my $size  = shift;
  my $path  = shift;

  my $dt        = gettime();
  my $nice_size = nice_size($size);
  my $color     = colorize($size);
  say $color."$dt\t$event\t$path\t$size\t$nice_size".color('reset');
}
