#
# PDF::Elite::Content::Image
# This module compiles all the relevant data used for adding an image to page(s) on the created PDF.
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

package PDF::Elite::Content::Image;

use strict;
use vars qw(@ISA @EXPORT $VERSION);
use Exporter;

@ISA     = qw(Exporter);
@EXPORT  = qw();
$VERSION = 0.01;

sub new {
  my $this = shift;
  my $page = shift;
  my $p = shift;
  my %params = %$p;

  my $class = ref($this) || $this;
  my $self = {};
  bless($self, $class);
  
  $self->{type} = 'image';
  $self->{img} = $params{image}->{objnum};
  $self->{width} = $page->{pdf}->convert_to_Points($params{width}) || 0;
  $self->{xpos} = $page->{pdf}->convert_to_Points($params{xpos}) || 0;
  $self->{ypos} = $page->{pdf}->convert_to_Points($params{ypos}) || 0;
  $self->{height} = $page->{pdf}->convert_to_Points($params{height}) || 0;
  $self->{extra} = $params{extra} || '';

  return if $params{image}->{height} == 0 && $params{image}->{width} == 0;
  if ($self->{width} == 0 && $self->{height} == 0) {
    $self->{width} = $params{image}->{width};
    $self->{height} = $params{image}->{height};
  } elsif ($self->{width} == 0 & $self->{height} > 0) {
    my $temp = $self->{height} / $params{image}->{height};
    $self->{width} = $params{image}->{width} * $temp;
  } elsif ($self->{height} == 0 & $self->{width} > 0) {
    my $temp = $self->{width} / $params{image}->{width};
    $self->{height} = $params{image}->{height} * $temp;
  }

  $self->{stream}{0} .= "q\n" .
                 "1 0 0 1 " . ($self->{xpos} * $page->{scale}) . " " .
                 ($self->{ypos} * $page->{scale}) . " cm\n" .
                 ($self->{width} * $page->{scale}) . " 0 0 " . ($self->{height} * $page->{scale}) . " 0 0 cm\n" .
                 "/Image" . $self->{img} . " Do\n" .
                 "Q\n" if $self->{height} > 0 && $self->{width} > 0;
  
  return $self;
}

1;