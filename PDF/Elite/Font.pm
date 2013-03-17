#
# PDF::Elite::Font
# This module is used for adding Fonts to a PDF, to be used by Text elements
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

package PDF::Elite::Font;

use strict;
use vars qw(@ISA @EXPORT $VERSION);
use Exporter;

@ISA     = qw(Exporter);
@EXPORT  = qw();
$VERSION = 0.01;

sub new {
  my $this = shift;
  my %params = @_;

  my $class = ref($this) || $this;
  my $self = {};
  bless($self, $class);

  my $fontName = $params{font} || 'helvetica';

  eval "require PDF::Elite::Font::" . lc($fontName) . "; ";
  unless($@) {
    no strict 'refs';

    my $obj = "PDF::Elite::Font::" . lc($fontName);
    $self->{BaseFont} = ${$obj . "::FONTDATA"}->{name};
    $self->{Encoding} = ${$obj . "::FONTDATA"}->{encoding};
    $self->{Subtype} = ${$obj . "::FONTDATA"}->{type};
    $self->{Fontid} = $params{number};
    $self->{FontName} = "F" . $params{number};
    $self->{widths} = ${$obj . "::FONTDATA"}->{widths}
  } else {
    die "requested font '$fontName' not installed ";
  }
  return $self;
}

1;