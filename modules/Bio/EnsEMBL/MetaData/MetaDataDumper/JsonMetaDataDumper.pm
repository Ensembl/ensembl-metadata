=head1 LICENSE

Copyright [2009-2014] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

=pod

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.
 
=cut

package Bio::EnsEMBL::MetaData::MetaDataDumper::JsonMetaDataDumper;
use base qw( Bio::EnsEMBL::MetaData::MetaDataDumper );
use Carp;
use JSON;
use strict;
use warnings;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);

sub new {
  my ($proto, @args) = @_;
  my $self = $proto->SUPER::new(@args);
  $self->{file}     ||= "species_metadata.json";
  return $self;
}

sub start {
  my ($self, $divisions, $file, $dump_all) = @_;
  $self->SUPER::start($divisions, $file, $dump_all);
  for my $fh (values %{$self->{files}}) {
  	  print $fh "[\n";
  }
  return;
}

sub _write_metadata_to_file {
  my ($self, $md, $fh, $count) = @_;
  if($count>0) {
  	print $fh ",\n";
  }
  print $fh to_json($md->to_hash(1), {pretty => 1});
  return;
}

sub end {
  my ($self) = @_;
  for my $fh (values %{$self->{files}}) {
  	  print $fh "]\n";
  }
  $self->SUPER::end();
  return;
}


1;

__END__

=pod

=head1 NAME

Bio::EnsEMBL::MetaData::MetaDataDumper::JsonMetaDataDumper

=head1 SYNOPSIS

=head1 DESCRIPTION

implementation to dump metadata details to a JSON file

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
