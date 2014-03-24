
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
