
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
use strict;
use warnings;

sub new {
  my ($proto, @args) = @_;
  my $class = ref($proto) || $proto;
  my $self = bless({}, $class);
  $self->{logger} = get_logger();
  ($self->{file}, $self->{division}) =
	rearrange(['FILE', 'PER_DIVISION'], @args);
  return $self;
}

sub file {
  my ($self) = @_;
  return $self->{file};
}

sub division {
  my ($self, $division) = @_;
  if (defined $division) {
	$self->{division} = $division;
  }
  return $self->{division};
}

sub do_dump {
  my ($self, $metadata, $outfile) = @_;
  throw "Unimplemented subroutine do_dump() in " .
	ref($self) . ". Please implement";
}

sub dump_metadata {

  my ($self, $metadata) = @_;

  if (defined $self->division() && $self->division() == 1) {

	my %mds_per_division;
	for my $md (@{$metadata->{genome}}) {
	  push @{$mds_per_division{$md->{division}}{genome}}, $md;
	}
	for my $division (keys %mds_per_division) {
	  (my $out_file = $self->file()) =~
		s/(.+)(\.[^.]+)$/$1_$division$2/;
	  $self->logger()->info("Writing $division metadata to $out_file");
	  $self->do_dump($mds_per_division{$division}, $out_file);
	  $self->logger()->info("Completed writing $division to $out_file");
	}

  }
  else {

	$self->logger()->info("Writing all metadata to " . $self->{file});
	$self->do_dump($metadata, $self->{file});
	$self->logger()->info("Completed writing to " . $self->{file});

  }

  return;

} ## end sub dump_metadata

sub logger {
  my ($self) = @_;
  return $self->{logger};
}

sub get_uniprot_coverage {
  my ($self, $md) = @_;
  return sprintf "%.2f",
	100*($md->{annotation}{nProteinCodingUniProtKB})/
	$md->{annotation}{nProteinCoding};
}

sub count_hash_values {
  my ($self, $hash) = @_;
  my $tot = 0;
  if (defined $hash) {
	for my $v (values %{$hash}) {
	  $tot += $v;
	}
  }
  return $tot;
}

sub count_hash_lengths {
  my ($self, $hash) = @_;
  my $tot = 0;
  if (defined $hash) {
	for my $v (values %{$hash}) {
	  $tot += scalar(@$v);
	}
  }
  return $tot;
}

sub count_array_lengths {
  my ($self, $array) = @_;
  my $tot = 0;
  if (defined $array) {
	$tot = scalar(@$array);
  }
  return $tot;
}

sub count_variation {
  my ($self, $md) = @_;
  return $self->count_hash_values($md->{variation}{variations}) +
	$self->count_hash_values($md->{variation}{structural_variations});
}

sub count_peptide_compara {
  my ($self, $md) = @_;
  return $self->count_array_lengths($md->{compara}{PROTEIN_TREES});
}

sub count_dna_compara {
  my ($self, $md) = @_;
  return $self->count_array_lengths($md->{compara}{LASTZ_NET}) +
	$self->count_array_lengths($md->{compara}{BLASTZ_NET}) +
	$self->count_array_lengths($md->{compara}{TRANSLATED_BLAT_NET});
}

sub count_alignments {
  my ($self, $md) = @_;
  return
	  $self->count_hash_values($md->{features}{proteinAlignFeatures})
	+ $self->count_hash_values($md->{features}{dnaAlignFeatures})
	+ $self->count_hash_lengths($md->{bam});
}

sub yesno {
  my ($self, $num) = @_;
  return (defined $num && $num + 0 > 0) ? 'Y' : 'N';
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
