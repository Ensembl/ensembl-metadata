
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

sub do_dump {
  my ($self, $metadata, $outfile) = @_;
  open(my $txt_file, '>', $outfile)
	|| croak "Could not write to " . $outfile;
  print $txt_file join("\t", qw(name species division taxonomy_id assembly_id assembly_name genebuild nProteinCoding nProteinCodingUniProtKBSwissProt nProteinCodingUniProtKBTrEMBL uniprotCoverage)) . "\n";
  for my $md (sort { $self->get_uniprot_coverage($a) <=> $self->get_uniprot_coverage($b) } @{$metadata->{genome}}) {
	print $txt_file join(
	  "\t", (
	   $md->{name}, $md->{species}, $md->{division}, $md->{taxonomy_id}, $md->{assembly_id},
	   $md->{assembly_name}, $md->{genebuild},  $md->{annotation}{nProteinCoding}, 
	   $md->{annotation}{nProteinCodingUniProtKBSwissProt}, $md->{annotation}{nProteinCodingUniProtKBTrEMBL}, 
	   $self->get_uniprot_coverage($md), "\n"));
  }
  close $txt_file;
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
