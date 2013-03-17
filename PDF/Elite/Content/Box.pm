#
# PDF::Elite::Content::Box
# This module compiles all the relevant data used for adding a box(that is not filled with color) to page(s) on the created PDF.
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

package PDF::Elite::Content::Box;

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

  $self->{type} = '';
  $self->{rgb} = $page->find_RGB($params{color} || 'black') if lc($params{fill}) ne 'custom';
  $self->{rgb} = $page->find_RGB($params{color}, $params{custom}) if lc($params{fill}) eq 'custom';
  $self->{xpos} = $page->{pdf}->convert_to_Points($params{xpos} || 0);
  $self->{ypos} = $page->{pdf}->convert_to_Points($params{ypos} || 0);
  $self->{scale} = $page->{scale} || 100;
  $self->{width} = $page->{pdf}->convert_to_Points($params{width} || 0);
  $self->{height} = $page->{pdf}->convert_to_Points($params{height} || 0);
  $self->{lineWidth} = $params{lineWidth} || 1;

  $self->{stream}{0} .= $self->{rgb} . " rg\n" .
                 ($self->{xpos} * $self->{scale}) . " " .
                 ($self->{ypos} * $self->{scale}) . " m " . (($self->{xpos} * $self->{scale}) + ($self->{width} * $self->{scale})) . " " .
                 ($self->{ypos} * $self->{scale}) . " l S\n"; #bottom horizontal line
  $self->{stream}{1} .= $self->{rgb} . " rg\n" .
                 ($self->{xpos} * $self->{scale}) . " " .
                 (($self->{ypos} * $self->{scale}) + ($self->{height} * $self->{scale})) . " m " . (($self->{xpos} * $self->{scale}) + ($self->{width} * $self->{scale})) . " " .
                 (($self->{ypos} * $self->{scale}) + ($self->{height} * $self->{scale})) . " l S\n"; #top horizontal line
  $self->{stream}{2} .= $self->{rgb} . " rg\n" .
                 ($self->{xpos} * $self->{scale}) . " " .
                 ($self->{ypos} * $self->{scale}) . " m " . ($self->{xpos} * $self->{scale}) .
                 " " . (($self->{ypos} * $self->{scale}) + ($self->{height} * $self->{scale})) . " l S\n"; #left vertical line
  $self->{stream}{3} .= $self->{rgb} . " rg\n" .
                 (($self->{xpos} * $self->{scale}) + ($self->{width} * $self->{scale})) . " " .
                 ($self->{ypos} * $self->{scale}) . " m " . (($self->{xpos} * $self->{scale}) + ($self->{width} * $self->{scale})) .
                 " " . (($self->{ypos} * $self->{scale}) + ($self->{height} * $self->{scale})) . " l S\n"; #right vertical line

  return $self;
}

1;