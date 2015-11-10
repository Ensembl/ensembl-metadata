=pod
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

package Bio::EnsEMBL::Utils::MetaData::MetaDataDumper::UniProtReportDumper;
use base qw( Bio::EnsEMBL::Utils::MetaData::MetaDataDumper );
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Carp;
use XML::Simple;
use Data::Dumper;
use strict;
use warnings;

sub new {
  my ($proto, @args) = @_;
  my $self = $proto->SUPER::new(@args);
  $self->{file} ||= 'uniprot_report.txt';
  return $self;
}

sub start {
  my ($self, $divisions, $file, $dump_all) = @_;
  $self->SUPER::start($divisions, $file, $dump_all);
  for my $fh (values %{$self->{files}}) {
  	  print $fh '#'. join("\t",
					   qw(name species division taxonomy_id assembly_id assembly_name genebuild nProteinCoding nProteinCodingUniProtKBSwissProt nProteinCodingUniProtKBTrEMBL uniprotCoverage)
	) .
	"\n";
  }
  return;
}

sub _write_metadata_to_file {
  my ($self, $md, $fh) = @_; 
  print $fh join(
				"\t",
				($md->name(),
				 $md->species(),
				 $md->division(),
				 $md->taxonomy_id(),
				 $md->assembly_id()   || '',
				 $md->assembly_name() || '',
				 $md->genebuild()     || '',
				 $md->annotations()->{nProteinCoding},
				 $md->annotations()->{nProteinCodingUniProtKBSwissProt},
				 $md->annotations()->{nProteinCodingUniProtKBTrEMBL},
				 sprintf("%.2f", $md->get_uniprot_coverage($md)),
				 "\n"));
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
