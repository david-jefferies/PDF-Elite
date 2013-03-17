#
# PDF::Elite::Page
# This module is used for adding pages to the PDF.
#
# Copyright 2012 David Jefferies <hyperion.nz@gmail.com>.
#
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 3 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.

package PDF::Elite::Page;

use strict;
use vars qw(@ISA @EXPORT $VERSION);
use Exporter;
use feature('switch');

@ISA     = qw(Exporter);
@EXPORT  = qw();
$VERSION = 0.01;

sub new {
  my $this = shift;
  my %params = @_;
  
  my $class = ref($this) || $this;
  my $self = {};
  bless($self, $class);

  $self->{id} = $params{id};
  $self->{pdf} = $params{pdf};

  $self->{objects} = {};
  $self->{contents} = {};
  $self->{scale} = $params{scale} || 1;

  return $self;
}

sub add_Text {
  my $self = shift;
  my %params = @_;
  
  return if !defined($params{text}) || !defined($params{font});
  require PDF::Elite::Content::Text;
  my $count = scalar(keys $self->{objects}) + 1;
  $self->{objects}{$count} = new PDF::Elite::Content::Text($self, \%params);

  my $left = $self->{pdf}->convert_from_Points($self->{objects}{$count}->{left});
  my $bottom = $self->{pdf}->convert_from_Points($self->{objects}{$count}->{bottom});
  my $top = $self->{pdf}->convert_from_Points($self->{objects}{$count}->{top});
  my $right = $self->{pdf}->convert_from_Points($self->{objects}{$count}->{right});

  return ($left, $bottom, $right, $top);
}

sub add_Image {
  my $self = shift;
  my %params = @_;
  
  return if !defined($params{image});
  
  my $count = scalar(keys $self->{objects}) + 1;
  require PDF::Elite::Content::Image;
  $self->{objects}{$count} = new PDF::Elite::Content::Image($self, \%params);
  
  return $self;
}

sub add_Box {
  my $self = shift;
  my %params = @_;

  my $count = scalar(keys $self->{objects}) + 1;
  if ($params{fill}) {
    require PDF::Elite::Content::FilledBox;

    $self->{objects}{$count} = new PDF::Elite::Content::FilledBox($self, \%params);
  } else {
    require PDF::Elite::Content::Box;

    $self->{objects}{$count} = new PDF::Elite::Content::Box($self, \%params);
  }
  
  return $self;
}

sub stream_output {
  my $self = shift;
  my $stream = '';
  
  foreach my $key(sort{$a<=>$b} keys %{$self->{objects}}) {
    foreach my $k(sort{$a<=>$b} keys %{$self->{objects}{$key}->{stream}}) {
      $stream .= $self->{objects}{$key}->{stream}{$k};
    }
  }

  return $stream;
}

sub find_RGB {
  my $self = $_[0];
  my $val = $_[1];
  my $val2 = $_[2];

  die "You need to specify a RGB value if you try doing a custom color." if lc($val) eq 'custom' && !defined $val2;
  
  given (lc($val)) {
    when ('black') {
      $val = "0 0 0";
    }
    when ('blue') {
      $val = "0 0 1";
    }
    when ('lime') {
      $val = "0 1 0";
    }
    when ('aqua') {
      $val = "0 1 1";
    }
    when ('red') {
      $val = "1 0 0";
    }
    when ('pink') {
      $val = "1 0 1";
    }
    when ('yellow') {
      $val = "1 1 0";
    }
    when ('white') {
      $val = "1 1 1";
    }
    when ('gray') {
      $val = "0.5";
    }
    when ('custom') {
      $val = $val2
    }
    default {
      $val = "0 0 0";
    }
  }
  return $val;
}

sub get_pageWidth {
  my $self = shift;

  my @a = split(/\s/, $self->{pdf}->{mediabox});

  return $self->{pdf}->convert_from_Points($a[2]);
}

sub get_pageHeight {
  my $self = shift;

  my @a = split(/\s/, $self->{pdf}->{mediabox});
  @a = split(/]/, $a[3]);

  return $self->{pdf}->convert_from_Points($a[0]);
}

1;