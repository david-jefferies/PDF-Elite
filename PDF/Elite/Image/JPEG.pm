#
# PDF::Elite::Image::JPEG
# This module reads JPEG files and saves them as readable data on the JPEG, that can be used to add to pages.
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

package PDF::Elite::Image::JPEG;

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

  if(ref($params{file})) {
    $self->{fh} = $params{file};
  } else {
    open($self->{fh}, $params{file});
  }
  binmode($self->{fh}, ':raw');
  
  read_file($self);

  seek($self->{fh}, 0, 0);
  $self->{stream} = '';
  my $buffer = '';
  while(!eof($self->{fh})) {
    read($self->{fh}, $buffer, 512);
    $self->{stream} .= $buffer;
  }
  $self->{length} = length($self->{stream});

  $self->{filters} = 'DCTDecode';

  #print $self->{length};

  return $self;
}

sub read_file {
  my $self = shift;
  
  my ($buffer, $height, $width, $bpc, $colorspace);
  
  $self->{fh}->seek(0,0);
  $self->{fh}->read($buffer, 2);
  while (1) {
    $self->{fh}->read($buffer, 4);
    my ($a, $marker, $length) = unpack("CCn", $buffer);
    
    #last if $a != 0xFF || $marker == 0xDA || $marker == 0xD9 || $length < 2 || $self->{fh}->eof;
    $self->{fh}->read($buffer, $length - 2);
    #next if $marker == 0xFE || ($marker >= 0xE0 && $marker <= 0xEF);
    if ($marker >= 0xC0 && $marker <= 0xCF && $marker != 0xC4 && $marker != 0xC8 && $marker != 0xCC) {
      ($bpc, $height, $width, $colorspace) = unpack("CnnC", substr($buffer, 0, 6));
      last;
    }
  }
  $self->{width} = $width;
  $self->{height} = $height;
  
  $self->{bpc} = $bpc;
  
  if ($colorspace == 1) {
    $self->{colorspace} = 'DeviceGray';
  } elsif ($colorspace == 3) {
    $self->{colorspace} = 'DeviceRGB';
  } elsif ($colorspace == 4) {
    $self->{colorspace} = 'DeviceCMYK';
  }

  return $self;
}

1;