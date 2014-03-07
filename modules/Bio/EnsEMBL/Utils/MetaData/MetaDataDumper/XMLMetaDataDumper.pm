
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

package Bio::EnsEMBL::Utils::MetaData::MetaDataDumper::XMLMetaDataDumper;
use base qw( Bio::EnsEMBL::Utils::MetaData::MetaDataDumper );
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Carp;
use XML::Simple;
use strict;
use warnings;

sub new {
  my ($proto, @args) = @_;
  my $self = $proto->SUPER::new(@args);
  $self->{file}     ||= "species_metadata.xml";
  $self->{division} ||= 1;
  return $self;
}

sub do_dump {
  my ($self, $metadata, $outfile) = @_;
  $self->logger()->info("Writing XML to " . $outfile);
  open(my $xml_file, '>', $outfile) ||
	croak "Could not write to " . $outfile;
  print $xml_file XML::Simple->new()
	->XMLout($self->metadata_to_hash($metadata), RootName => 'genomes');
  close $xml_file;
  $self->logger()->info("Completed writing XML to " . $outfile);
  return;
}

sub start {
  my ($self, $file, $divisions) = @_;
  $self->SUPER::start($divisions, $file);
  for my $fh (values %{$self->{files}}) {
	print $fh "<genomes>";
  }
  return;
}

sub _write_metadata_to_file {
  my ($self, $md, $fh, $count) = @_;
  print $fh XML::Simple->new()
	->XMLout($md->to_hash(1), RootName => 'genome')
	;
  return;
}

sub end {
  my ($self) = @_;
  for my $fh (values %{$self->{files}}) {
	print $fh "</genomes>\n";
  }
  $self->SUPER::end();
  return;
}

1;

__END__

=pod

=head1 NAME

Bio::EnsEMBL::Utils::MetaData::MetaDataDumper::XMLMetaDataDumper

=head1 SYNOPSIS

=head1 DESCRIPTION

implementation to dump metadata details to an XML file

=head1 SUBROUTINES/METHODS

=head2 new

=head2 dump_metadata
Description : Dump metadata to the file supplied by the constructor 
Argument : Hash of details

=head1 AUTHOR

dstaines

=head1 MAINTAINER

$Author$

=head1 VERSION

$Revision$

=cut
