
=pod
=head1 LICENSE

  Copyright (c) 1999-2011 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

    http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.
 
=cut

package Bio::EnsEMBL::Utils::MetaData::MetaDataDumper;
use Bio::EnsEMBL::Utils::Exception qw/throw/;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Log::Log4perl qw(get_logger);
use Data::Dumper;
use Carp qw(croak cluck);
use strict;
use warnings;

sub new {
  my ($proto, @args) = @_;
  my $class = ref($proto) || $proto;
  my $self = bless({}, $class);
  $self->{logger} = get_logger();
  ($self->{file}) = rearrange(['FILE'], @args);
  $self->{all} = 'all';
  return $self;
}

sub start {
  my ($self, $divisions, $file, $dump_all) = @_;
  print "DUMPALL=$dump_all\n";
  $self->{files}     = {};
  $self->{filenames} = {};
  $self->logger()->debug("Opening output files");
  for my $division (@{$divisions}) {
	(my $out_file = $file) =~ s/(.+)(\.[^.]+)$/$1_$division$2/;
	my $fh;
	$self->logger()
	  ->debug("Opening output file $out_file for division $division");
	open($fh, '>', $out_file) ||
	  croak "Could not open $out_file for writing";
	$self->{files}->{$division}     = $fh;
	$self->{filenames}->{$division} = $out_file;
	$self->{count}{$division}     = 0;
  }
  if (defined $dump_all && $dump_all==1) {
	my $fh;
	$self->logger()->debug("Opening output file $file");
	open($fh, '>', $file) || croak "Could not open $file for writing";
	$self->{files}->{$self->{all}}     = $fh;
	$self->{filenames}->{$self->{all}} = $file;
	$self->{count}{$self->{all}}     = 0;
  }
  $self->{files_handles} = {};
  $self->logger()
	->debug(
		"Opened " . scalar(values %{$self->{files}}) . " output files");
  return;
} ## end sub start

sub end {
  my ($self) = @_;
  $self->logger()->debug("Closing all file handles");
  for my $fh (values %{$self->{files}}) {
	$self->logger()->debug("Closing file handle");
	close($fh) || cluck "Could not close file handle for writing";
  }
  $self->logger()
	->debug(
		"Closed " . scalar(values %{$self->{files}}) . " file handles");
  return;
}

sub write_metadata {
  my ($self, $metadata, $division) = @_;
  my $fh = $self->{files}{$division};
  if (defined $fh) {
	$self->_write_metadata_to_file($metadata, $fh, $self->{count}->{$division});
	$self->{count}->{$division} += 1;
  }
  return;
}

sub _write_metadata_to_file {
  my ($self, $metadata, $fh) = @_;
  throw "Unimplemented subroutine do_dump() in " .
	ref($self) . ". Please implement";
  return;
}

sub dump_metadata {
  my ($self, $metadata, $file, $divisions, $dump_all) = @_;
  # start
  $self->start($file, $divisions, $dump_all);
  # iterate
  for my $md (@$metadata) {
	if (scalar(@$divisions) > 1) {
	  $self->write_metadata($md, $self->{all});
	}
	$self->write_metadata($md, $md->{division});
  }
  # end
  $self->end();
  return;

}

sub logger {
  my ($self) = @_;
  return $self->{logger};
}

sub yesno {
  my ($self, $num) = @_;
  return (defined $num && $num + 0 > 0) ? 'Y' : 'N';
}

sub metadata_to_hash {
  my ($self, $metadata) = @_;
  my $genomes = [];
  for my $md (@{$metadata}) {
	push @$genomes, $md->to_hash(1);
  }
  return {genome => $genomes};
}

1;

__END__

=pod

=head1 NAME

Bio::EnsEMBL::Utils::MetaData::DetailsDumper

=head1 SYNOPSIS

=head1 DESCRIPTION

Base class for rendering details 

=head1 SUBROUTINES/METHODS

=head2 new

=head2 dump_metadata
Description : Render supplied metadata
Arugment: Hash of metadata provided by MetaDataProcessor

=head1 AUTHOR

dstaines

=head1 MAINTAINER

$Author$

=head1 VERSION

$Revision$

=cut
