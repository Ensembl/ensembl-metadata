#!/usr/bin/env perl

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

package Bio::EnsEMBL::Utils::MetaData::MetaDataDumper::TextMetaDataDumper;
use base qw( Bio::EnsEMBL::Utils::MetaData::MetaDataDumper );
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Carp;
use XML::Simple;
use strict;
use warnings;

sub new {
  my ($proto, @args) = @_;
  my $self = $proto->SUPER::new(@args);
  $self->{file}     ||= 'species.txt';
  $self->{division} ||= 0;
  return $self;
}

sub do_dump {
  my ($self, $metadata, $outfile) = @_;
  open(my $txt_file, '>', $outfile) ||
	croak "Could not write to " . $outfile;
  print $txt_file '#';
  
  print $txt_file join("\t",
					   qw(names species division taxonomy_id assembly assembly_accession genebuild variation pan_compara peptide_compara genome_alignments other_alignments core_db species_id)
	) .
	"\n";

  for my $md (@{$metadata->{genome}}) {
	print $txt_file join("\t",
						 ($md->{name},
						  $md->{species},
						  $md->{division},
						  $md->{taxonomy_id},
						  $md->{assembly_name},
						  $md->{assembly_id},
						  $md->{genebuild},
						  $self->yesno($self->count_variation($md)),
						  $self->yesno($md->{pan_species}),
						  $self->yesno($self->count_peptide_compara($md)),
						  $self->yesno($self->count_dna_compara($md)),
						  $self->yesno($self->count_alignments($md)),
						  $md->{dbname},
						  $md->{species_id},
						  "\n"));
  }
  close $txt_file;
  return;
} ## end sub do_dump

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
