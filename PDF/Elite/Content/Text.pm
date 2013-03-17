#
# PDF::Elite::Content::Text
# This module compiles all the relevant data used for adding text to page(s) on the created PDF.
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

package PDF::Elite::Content::Text;

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

  $self->{type} = 'text';
  $self->{fontName} = $params{font}->{FontName};
  $self->{fontSize} = $params{fontSize} || 12;
  $self->{rgb} = $page->find_RGB($params{color} || 'black') if lc($params{color}) ne 'custom';
  $self->{rgb} = $page->find_RGB($params{color}, $params{custom}) if lc($params{color}) eq 'custom';
  $self->{hscale} = $params{hscale} || 100;
  $self->{xpos} = $page->{pdf}->convert_to_Points($params{xpos} || $page->{pdf}->{marginX});
  $self->{ypos} = $page->{pdf}->convert_to_Points($params{ypos} || $page->{pdf}->{marginY});
  $self->{valign} = $params{valign} || 0;
  $self->{align} = $params{align} || 'left';
  $self->{text} = $params{text};
  $self->{textStyle} = $params{textStyle} || $page->{pdf}->{textStyle};
  $self->{extra} = $params{extra} || '';
  
  $self->{text} =~ s/\(/\\\(/g;
  $self->{text} =~ s/\)/\\\)/g;

  $self->{width} = string_width($self->{text}, $self->{fontSize}, $params{font}->{widths});
  my @a = split(/\s/, $page->{pdf}->{mediabox});
  if ($params{maxWidth}) {
    $self->{maxWidth} = $page->{pdf}->convert_to_Points($params{maxWidth});
  } else {
    $self->{maxWidth} = $a[2] - $self->{xpos} - $page->{pdf}->{marginX};
  }
  if (($a[2] - $self->{xpos} - $page->{pdf}->{marginX}) < $self->{maxWidth} &&
     ($a[2] - $self->{xpos} - $page->{pdf}->{marginX}) > 0) {
    $self->{maxWidth} = $a[2] - $self->{xpos} - $page->{pdf}->{marginX};
  }
  if ($self->{textStyle} == 0) {
    if ($self->{width} >= $self->{maxWidth}) {
      $self->{hscale} = sprintf("%.0d", ($self->{maxWidth} / $self->{width}) * 100);
    }

    $self->{width} *= ($self->{hscale} / 100);
    $self->{ypos} = $self->{ypos} - $self->{fontSize} if $self->{valign} == 2;
    my $d = $self->{width} * ($self->{hscale} / 100);
    if (lc($self->{align}) eq 'right') {
      $self->{xpos} = ($self->{xpos} + $self->{maxWidth} - $self->{width}) + ($self->{width} - $d);
    } elsif (lc($self->{align}) eq 'center') {
      $self->{xpos} = $self->{xpos} + ($self->{maxWidth} / 2) - ($d / 2);
    }
    $self->{stream}{0} = " BT /" . $self->{fontName} . " " . ($self->{fontSize} * $page->{scale}) . " Tf " . $self->{rgb} .
                      " rg " . $self->{hscale} . " Tz " . (($self->{xpos} * $page->{scale}) + $page->{pdf}->{marginX}) . " " .
                      ($self->{ypos} * $page->{scale}) . " Td \(" . $self->{text} . "\) Tj ET\n";
    $self->{bottom} = $self->{ypos};
    $self->{left} = $self->{xpos};
    $self->{top} = $self->{bottom} + $self->{fontSize};
    $self->{right} = $self->{xpos} + $self->{width};
  } elsif ($self->{textStyle} == 1) {
    while ($self->{width} >= $self->{maxWidth} && $self->{fontSize} > 2) {
      $self->{fontSize}--;
      $self->{width} = string_width($self->{text}, $self->{fontSize}, $params{font}->{widths});
    }
    $self->{ypos} = $self->{ypos} - $self->{fontSize} if $self->{valign} == 2;
    my $stringWidth = string_width($self->{text}, $self->{fontSize}, $params{font}->{widths});
    my $d = $stringWidth * ($self->{hscale} / 100);
    if (lc($self->{align}) eq 'right') {
      $self->{xpos} = ($self->{xpos} + $self->{maxWidth} - $stringWidth) + ($stringWidth - $d);
    } elsif (lc($self->{align}) eq 'center') {
      $self->{xpos} = $self->{xpos} + ($self->{maxWidth} / 2) - ($d / 2);
    }
    $self->{stream}{0} = " BT /" . $self->{fontName} . " " . ($self->{fontSize} * $page->{scale}) . " Tf " . $self->{rgb} .
                      " rg " . $self->{hscale} . " Tz " . (($self->{xpos} * $page->{scale}) + $page->{pdf}->{marginX}) . " " .
                      ($self->{ypos} * $page->{scale}) . " Td \(" . $self->{text} . "\) Tj ET\n";
    $self->{bottom} = $self->{ypos};
    $self->{left} = $self->{xpos};
    $self->{top} = $self->{bottom} + $self->{fontSize};
    $self->{right} = $self->{xpos} + $self->{width};
  } elsif ($self->{textStyle} == 2) {
    my @lines = split(/\n|\r/, $self->{text});
    my $count = 0;
    my @array;
    $self->{ypos} = $self->{ypos} - $self->{fontSize} if $self->{valign} == 2;
    $self->{top} = $self->{ypos} + $self->{fontSize};
    $self->{left} = $self->{xpos};
    $self->{right} = $self->{maxWidth} + $self->{xpos};
    foreach my $line (@lines) {
      my @words = split(/\s/, $line);
      my $finalLine = '';
      foreach my $word (@words) {
        my $tempLine = "$finalLine $word";
        $tempLine =~ s/^\s//g;
        if (string_width($tempLine, $self->{fontSize}, $params{font}->{widths}) < $self->{maxWidth}) {
          $finalLine = $tempLine;
        } else {
          push(@array, $finalLine);
          $finalLine = $word;
        }
      }
      push(@array, $finalLine);
      $finalLine = '';
    }
    if ($self->{valign} == 1) {
      $self->{bottom} = $self->{ypos} + ($self->{fontSize} * $count);
      foreach my $line (reverse(@array)) {
        $self->{top} = $self->{ypos} + ($self->{fontSize} * $count) + $self->{fontSize};
        $self->{stream}{$count} = " BT /" . $self->{fontName} . " " . ($self->{fontSize} * $page->{scale}) . " Tf " . $self->{rgb} .
                      " rg " . $self->{hscale} . " Tz " . (($self->{xpos} * $page->{scale}) + $page->{pdf}->{marginX}) . " " .
                      (($self->{ypos} + ($self->{fontSize} * $count)) * $page->{scale}) . " Td \(" . $line . "\) Tj ET\n";
        $count++;
      }
    } elsif ($self->{valign} == 2) {
      $self->{top} = $self->{ypos} + $self->{fontSize};
      foreach my $line (@array) {
        $self->{bottom} = $self->{ypos} - ($self->{fontSize} * $count);
        $self->{stream}{$count} = " BT /" . $self->{fontName} . " " . ($self->{fontSize} * $page->{scale}) . " Tf " . $self->{rgb} .
                      " rg " . $self->{hscale} . " Tz " . (($self->{xpos} * $page->{scale}) + $page->{pdf}->{marginX}) . " " .
                      (($self->{ypos} - ($self->{fontSize} * $count)) * $page->{scale}) . " Td \(" . $line . "\) Tj ET\n";
        $count++;
      }
    }
  }
  
  if ($params{link}) {
    $self->{link}->{exists} = 'Y';
    my $border = $params{linkborder} || 0;
    my $w = $self->{right};
    my $h = $self->{top};
    my $b = $self->{bottom};
    my $l = $self->{left};
    $self->{link}->{stream} = "/Type /Annot /Subtype /Link /Rect [ $l $b $w $h ] /A << /S /URI /URI (" . $params{link} . ") >> /Border [ $border $border $border ]"
  } else {
    $self->{link}->{exists} = 'N';
  }

  return $self;
}

sub string_width {
  my $text = shift;
  my $size = shift;
  my $w = shift;
  my %widths = %$w;


  my $width = 0;
  foreach my $byte (split //, $text) {
    if (utf8::is_utf8($byte)) {
      $byte = utf8::decode($byte);
    }
    $width += $widths{ord($byte)};
  }
  $width /= 1000;

  return $width * $size;
}

1;