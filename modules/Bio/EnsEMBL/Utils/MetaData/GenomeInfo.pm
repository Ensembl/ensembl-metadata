
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

package Bio::EnsEMBL::Utils::MetaData::GenomeInfo;
use Log::Log4perl qw(get_logger);
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use strict;
use warnings;

sub new {
  my ($proto, @args) = @_;
  my $class = ref($proto) || $proto;
  my $self = bless({}, $class);
  $self->{logger} = get_logger();
  ($self->{name},        $self->{species},     $self->{dbname},
   $self->{species_id},  $self->{taxonomy_id}, $self->{assembly_name},
   $self->{assembly_id}, $self->{genebuild},   $self->{division},
   $self->{strain},      $self->{serotype}

	) =
	rearrange(
			  ['NAME',        'SPECIES',
			   'DBNAME',      'SPECIES_ID',
			   'TAXONOMY_ID', 'ASSEMBLY_NAME',
			   'ASSEMBLY_ID', 'GENEBUILD',
			   'DIVISION',    'STRAIN',
			   'SEROTYPE',],
			  @args);
  return $self;
}

sub dbID {
  my ($self, $id) = @_;
  $self->{dbID} = $id if (defined $id);
  return $self->{dbID};
}

sub adaptor {
  my ($self, $adaptor) = @_;
  $self->{adaptor} = $adaptor if (defined $adaptor);
  return $self->{adaptor};
}
# first-class attributes
sub species {
  my ($self, $species) = @_;
  $self->{species} = $species if (defined $species);
  return $self->{species};
}

sub strain {
  my ($self, $arg) = @_;
  $self->{strain} = $arg if (defined $arg);
  return $self->{strain};
}

sub serotype {
  my ($self, $arg) = @_;
  $self->{serotype} = $arg if (defined $arg);
  return $self->{serotype};
}

sub name {
  my ($self, $arg) = @_;
  $self->{name} = $arg if (defined $arg);
  return $self->{name};
}

sub dbname {
  my ($self, $dbname) = @_;
  $self->{dbname} = $dbname if (defined $dbname);
  return $self->{dbname};
}

sub species_id {
  my ($self, $species_id) = @_;
  $self->{species_id} = $species_id if (defined $species_id);
  return $self->{species_id};
}

sub taxonomy_id {
  my ($self, $taxonomy_id) = @_;
  $self->{taxonomy_id} = $taxonomy_id if (defined $taxonomy_id);
  return $self->{taxonomy_id};
}

sub assembly_name {
  my ($self, $assembly_name) = @_;
  $self->{assembly_name} = $assembly_name if (defined $assembly_name);
  return $self->{assembly_name};
}

sub assembly_id {
  my ($self, $assembly_id) = @_;
  $self->{assembly_id} = $assembly_id if (defined $assembly_id);
  return $self->{assembly_id};
}

sub assembly_level {
  my ($self, $assembly_level) = @_;
  $self->{assembly_level} = $assembly_level
	if (defined $assembly_level);
  return $self->{assembly_level};
}

sub base_count {
  my ($self, $base_count) = @_;
  $self->{base_count} = $base_count if (defined $base_count);
  return $self->{base_count};
}

sub genebuild {
  my ($self, $genebuild) = @_;
  $self->{genebuild} = $genebuild if (defined $genebuild);
  return $self->{genebuild};
}

sub division {
  my ($self, $division) = @_;
  $self->{division} = $division if (defined $division);
  return $self->{division};
}

sub db_size {
  my ($self, $arg) = @_;
  $self->{db_size} = $arg if (defined $arg);
  return $self->{db_size};
}

# references
sub aliases {
  my ($self, $aliases) = @_;
  if (defined $aliases) {
	$self->{aliases} = $aliases;
  }
  return $self->{aliases};
}

sub compara {
  my ($self, $compara) = @_;
  if (defined $compara) {
	$self->{compara}               = $compara;
	$self->{has_peptide_compara}   = undef;
	$self->{has_genome_alignments} = undef;
  }
  return $self->{compara};
}

sub pan_compara {
  my ($self, $compara) = @_;
  if (defined $compara) {
	$self->{pan_compara}     = $compara;
	$self->{has_pan_compara} = undef;
  }
  return $self->{pan_compara};
}

sub sequences {
  my ($self, $sequences) = @_;
  if (defined $sequences) {
	$self->{sequences} = $sequences;
  }
  return $self->{sequences};
}

sub publications {
  my ($self, $publications) = @_;
  if (defined $publications) {
	$self->{publications} = $publications;
  }
  return $self->{publications};
}

sub variations {
  my ($self, $variations) = @_;
  if (defined $variations) {
	$self->{variations}     = $variations;
	$self->{has_variations} = undef;
  }
  return $self->{variations};
}

sub features {
  my ($self, $features) = @_;
  if (defined $features) {
	$self->{features} = $features;
  }
  return $self->{features};
}

sub annotations {
  my ($self, $annotation) = @_;
  if (defined $annotation) {
	$self->{annotation} = $annotation;
  }
  return $self->{annotation};
}

sub read_alignments {
  my ($self, $read_alignments) = @_;
  if (defined $read_alignments) {
	$self->{read_alignments}      = $read_alignments;
	$self->{has_other_alignments} = undef;
  }
  return $self->{read_alignments};
}

# boolean optimisers
sub has_variation {
  my ($self, $arg) = @_;
  if (defined $arg) {
	$self->{has_variation} = $arg;
  }
  elsif (!defined($self->{has_variation})) {
	$self->{has_variation} = $self->count_variation() > 0 ? 1 : 0;
  }
  return $self->{has_variation};
}

sub has_genome_alignments {
  my ($self, $arg) = @_;
  if (defined $arg) {
	$self->{has_genome_alignments} = $arg;
  }
  elsif (!defined($self->{has_genome_alignments})) {
	$self->{has_genome_alignments} =
	  $self->count_dna_compara() > 0 ? 1 : 0;
  }
  return $self->{has_genome_alignments};
}

sub has_peptide_compara {
  my ($self, $arg) = @_;
  if (defined $arg) {
	$self->{has_peptide_compara} = $arg;
  }
  elsif (!defined($self->{has_peptide_compara})) {
	$self->{has_peptide_compara} =
	  $self->count_peptide_compara() > 0 ? 1 : 0;
  }
  return $self->{has_peptide_compara};
}

sub has_pan_compara {
  my ($self, $arg) = @_;
  if (defined $arg) {
	$self->{has_pan_compara} = $arg;
  }
  elsif (!defined($self->{has_pan_compara})) {
	$self->{has_pan_compara} = $self->count_pan_compara() > 0 ? 1 : 0;
  }
  return $self->{has_pan_compara};
}

sub has_other_alignments {
  my ($self, $arg) = @_;
  if (defined $arg) {
	$self->{has_other_alignments} = $arg;
  }
  elsif (!defined($self->{has_other_alignments})) {
	$self->{has_other_alignments} =
	  $self->count_alignments() > 0 ? 1 : 0;
  }
  return $self->{has_other_alignments};
}

# utility methods
sub get_uniprot_coverage {
  my ($self) = @_;
  return sprintf "%.2f",
	100*($self->{annotation}{nProteinCodingUniProtKB})/
	$self->{annotation}{nProteinCoding};
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
  my ($self) = @_;
  return $self->count_hash_values($self->{variation}{variations}) +
	$self->count_hash_values($self->{variation}{structural_variations});
}

sub count_pan_compara {
  my ($self) = @_;
  return $self->count_array_lengths(
								   $self->{pan_compara}{PROTEIN_TREES});
}

sub count_peptide_compara {
  my ($self) = @_;
  return $self->count_array_lengths($self->{compara}{PROTEIN_TREES});
}

sub count_dna_compara {
  my ($self) = @_;
  return $self->count_array_lengths($self->{compara}{LASTZ_NET}) +
	$self->count_array_lengths($self->{compara}{BLASTZ_NET}) +
	$self->count_array_lengths($self->{compara}{TRANSLATED_BLAT_NET});
}

sub count_alignments {
  my ($self) = @_;
  return $self->count_hash_values(
							  $self->{features}{proteinAlignFeatures}) +
	$self->count_hash_values($self->{features}{dnaAlignFeatures}) +
	$self->count_hash_lengths($self->{read_alignments});
}

1;

__END__

=pod

=head1 NAME

Bio::EnsEMBL::Utils::MetaData::GenomeInfo

=head1 SYNOPSIS

=head1 DESCRIPTION

TODO

=head1 SUBROUTINES/METHODS

=head2 new

=head1 AUTHOR

dstaines

=head1 MAINTAINER

$Author$

=head1 VERSION

$Revision$

=cut

1;
