
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

use strict;
use warnings;

sub new {
  my ($proto, @args) = @_;
  my $class = ref($proto) || $proto;
  my $self = bless({}, $class);
  $self->{logger} = get_logger();
  ($self->{species},   $self->{dbname},        $self->{species_id},
   $self->{taxid},     $self->{assembly_name}, $self->{assembly_id},
   $self->{genebuild}, $self->{division},      $self->{aliases},
   $self->{division_compara}, $self->{pan_compara},
   $self->{accessions}, $self->{variations}, $self->{features},
   $self->{annotation}, $self->{read_alignments}
	) =
	rearrange(
			  ['SPECIES',       'DBNAME',
			   'SPECIES_ID',    'TAXID',
			   'ASSEMBLY_NAME', 'ASSEMBLY_ID',
			   'GENEBUILD',     'DIVISION',
			   'ALIASES',       'DIVISION_COMPARA',
			   'PAN_COMPARA',   'ACCESSIONS',
			   'VARIATIONS',    'FEATURES',
			   'ANNOTATION',    'READ_ALIGNMENTS'],
			  @args);
  return $self;
}

sub species {
  my ($self, $species) = @_;
  $self->{species} = $species if (defined $species);
  return $self->{species};
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

sub taxid {
  my ($self, $taxid) = @_;
  $self->{taxid} = $taxid if (defined $taxid);
  return $self->{taxid};
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

sub aliases {
  my ($self, $aliases) = @_;
  $self->{aliases} = $aliases if (defined $aliases);
  return $self->{aliases};
}

sub division_compara {
  my ($self, $division_compara) = @_;
  $self->{division_compara} = $division_compara
	if (defined $division_compara);
  return $self->{division_compara};
}
# partners in pan
sub pan_compara {
  my ($self, $pan_compara) = @_;
  $self->{pan_compara} = $pan_compara if (defined $pan_compara);
  return $self->{pan_compara};
}

sub accessions {
  my ($self, $accessions) = @_;
  $self->{accessions} = $accessions if (defined $accessions);
  return $self->{accessions};
}

sub variations {
  my ($self, $variations) = @_;
  $self->{variations} = $variations if (defined $variations);
  return $self->{variations};
}

sub features {
  my ($self, $features) = @_;
  $self->{features} = $features if (defined $features);
  return $self->{features};
}

sub annotation {
  my ($self, $annotation) = @_;
  $self->{annotation} = $annotation if (defined $annotation);
  return $self->{annotation};
}

sub read_alignments {
  my ($self, $read_alignments) = @_;
  $self->{read_alignments} = $read_alignments
	if (defined $read_alignments);
  return $self->{read_alignments};
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
