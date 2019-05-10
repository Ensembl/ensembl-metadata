=head1 LICENSE

Copyright [2009-2019] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::MetaData::MetaDataDumper::TextMetaDataDumper

=head1 SYNOPSIS

=head1 DESCRIPTION

Implementation to dump metadata details to a TSV file.
See Bio::EnsEMBL::MetaData::MetaDataDumper for method details.

=head1 SEE ALSO
Bio::EnsEMBL::MetaData::MetaDataDumper

=head1 AUTHOR

Dan Staines

=cut

package Bio::EnsEMBL::MetaData::MetaDataDumper::TextMetaDataDumper;
use base qw( Bio::EnsEMBL::MetaData::MetaDataDumper );
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Data::Dumper;
use Carp;
use XML::Simple;
use strict;
use warnings;

sub new {
  my ($proto, @args) = @_;
  my $self = $proto->SUPER::new(@args);
  $self->{file} ||= 'species.txt';
  return $self;
}

sub start {
  my ($self, $divisions, $dump_path, $file, $dump_all) = @_;
  $self->SUPER::start($divisions, $dump_path, $file, $dump_all);
  for my $fh (values %{$self->{files}}) {
	print $fh '#'
	  .
	  join("\t",
		   qw(name species division taxonomy_id assembly assembly_accession genebuild variation pan_compara peptide_compara genome_alignments other_alignments core_db species_id)
	  ) .
	  "\n";
  }
  return;
}

sub _write_metadata_to_file {
  my ($self, $md, $fh) = @_;
  print $fh join("\t",
				 ($md->display_name(),
				  $md->name(),
				  $md->division(),
				  $md->taxonomy_id(),
				  $md->assembly_name() || '',
				  $md->assembly_accession()   || '',
				  $md->genebuild()     || '',
				  $self->yesno($md->has_variations()),
				  $self->yesno($md->has_pan_compara()),
				  $self->yesno($md->has_peptide_compara()),
				  $self->yesno($md->has_genome_alignments()),
				  $self->yesno($md->has_other_alignments()),
				  $md->dbname(),
				  $md->species_id(),
				  "\n"));
  return;
}

1;
__END__

=pod

=head1 NAME

Bio::EnsEMBL::MetaData::MetaDataDumper::XMLMetaDataDumper

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
