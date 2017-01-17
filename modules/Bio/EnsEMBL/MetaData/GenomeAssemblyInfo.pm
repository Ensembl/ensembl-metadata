
=head1 LICENSE

Copyright [1999-2017] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::MetaData::GenomeAssemblyInfo

=head1 SYNOPSIS

	  my $assembly_info =
		Bio::EnsEMBL::MetaData::GenomeAssemblyInfo->new(
											  -ASSEMBLY_NAME      => $assembly_name,
											  -ASSEMBLY_ACCESSION => $assembly_accession,
											  -ASSEMBLY_LEVEL     => $assembly_level,
											  -ORGANISM           => $organism
		);

=head1 DESCRIPTION

Object encapsulating information about a particular assembly. Release-independent.

=head1 SEE ALSO

Bio::EnsEMBL::MetaData::BaseInfo
Bio::EnsEMBL::MetaData::GenomeOrganismInfo
Bio::EnsEMBL::MetaData::DBSQL::GenomeAssemblyInfoAdaptor

=head1 Author

Dan Staines

=cut

package Bio::EnsEMBL::MetaData::GenomeAssemblyInfo;
use strict;
use warnings;
use base qw/Bio::EnsEMBL::MetaData::BaseInfo/;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::MetaData::GenomeOrganismInfo;

=head1 CONSTRUCTOR
=head2 new
  Arg [-ASSEMBLY_NAME] :
        string - name of the assembly
  Arg [-ASSEMBLY_ACCESSION] :
        string - INSDC assembly accession
  Arg [-ASSEMBLY_LEVEL] :
        string - highest assembly level (chromosome, supercontig etc.)
  Arg [-BASE_COUNT] :
        long - total number of bases in toplevel
  Example    : $info = Bio::EnsEMBL::MetaData::GenomeAssemblyInfo->new(...);
  Description: Creates a new info object
  Returntype : Bio::EnsEMBL::MetaData::GenomeAssemblyInfo
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub new {
  my ( $class, @args ) = @_;
  my $self = $class->SUPER::new(@args);

  ( $self->{assembly_name},  $self->{assembly_accession},
    $self->{assembly_level}, $self->{base_count} )
    = rearrange( [ 'ASSEMBLY_NAME',   'ASSEMBLY_ACCESSION',
                   'ASSEMBLY_LEVEL',  'BASE_COUNT' ],
                 @args );

  return $self;
} ## end sub new

=head1 ATTRIBUTE METHODS
=head2 assembly_name
  Arg        : (optional) assembly_name to set
  Description: Gets/sets name of assembly
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub assembly_name {
  my ( $self, $assembly_name ) = @_;
  $self->{assembly_name} = $assembly_name if ( defined $assembly_name );
  return $self->{assembly_name};
}

=head2 assembly_accession
  Arg        : (optional) assembly_accession to set
  Description: Gets/sets INSDC accession for assembly
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub assembly_accession {
  my ( $self, $assembly_accession ) = @_;
  $self->{assembly_accession} = $assembly_accession
    if ( defined $assembly_accession );
  return $self->{assembly_accession};
}

=head2 assembly_level
  Arg        : (optional) assembly_level to set
  Description: Gets/sets highest level of assembly (chromosome, supercontig etc.)
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub assembly_level {
  my ( $self, $assembly_level ) = @_;
  $self->{assembly_level} = $assembly_level if ( defined $assembly_level );
  return $self->{assembly_level};
}

=head2 base_count
  Arg        : (optional) base_count to set
  Description: Gets/sets total number of bases in assembled genome
  Returntype : integer
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub base_count {
  my ( $self, $base_count ) = @_;
  $self->{base_count} = $base_count if ( defined $base_count );
  return $self->{base_count};
}

=head2 sequences
  Arg        : (optional) arrayref of sequences to set
  Description: Gets/sets array of hashrefs describing sequences from the assembly. Elements are hashrefs with name and acc as keys
  Returntype : Arrayref
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub sequences {
  my ( $self, $sequences ) = @_;
  if ( defined $sequences ) {
    $self->{sequences} = $sequences;
  }
  $self->_load_child( 'sequences', '_fetch_sequences' );
  return $self->{sequences};
}

=head2 organism
  Arg        : (optional) organism object to set
  Description: Gets/sets organism to which genome belongs
  Returntype : Bio::EnsEMBL::MetaData::GenomeOrganismInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub organism {
  my ( $self, $organism ) = @_;
  if ( defined $organism ) {
    $self->{organism} = $organism;
  }
  $self->_load_child( 'organism', '_fetch_organism' );
  return $self->{organism};
}

=head2 display_name
  Description: Gets display_name
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub display_name {
  my ($self) = @_;
  return $self->organism()->display_name();
}

=head2 scientific_name
  Description: Gets scientific_name
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub scientific_name {
  my ($self) = @_;
  return $self->organism()->scientific_name();
}

=head2 strain
  Description: Gets strain of genome
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub strain {
  my ($self) = @_;
  return $self->organism()->strain();
}

=head2 serotype
  Description: Gets serotype
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub serotype {
  my ($self) = @_;
  return $self->organism()->serotype();
}

=head2 name
  Description: Gets name for genome
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub name {
  my ($self) = @_;
  return $self->organism()->name();
}

=head2 taxonomy_id
  Description: Gets NCBI taxonomy ID
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub taxonomy_id {
  my ($self) = @_;
  return $self->organism()->taxonomy_id();
}

=head2 species_taxonomy_id
  Description: Gets NCBI taxonomy ID for species to which this organism belongs
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub species_taxonomy_id {
  my ($self) = @_;
  return $self->organism()->species_taxonomy_id();
}

=head2 is_reference
  Description: Gets whether this is a reference for the species
  Returntype : bool
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub is_reference {
  my ($self) = @_;
  return $self->organism()->is_reference();
}

=head1 UTILITY METHODS
=head2 to_string
  Description: Render as plain string
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub to_string {
  my ($self) = @_;
  return
    join( '/',
          $self->division(), $self->method(), ( $self->set_name() || '-' ) );
}

=head2 _preload
  Description: Ensure all children are loaded (used for hash transformation)
  Returntype : none
  Exceptions : none
  Caller     : Internal
  Status     : Stable
=cut

sub _preload {
  my ($self) = @_;
  $self->sequences();
  return;
}

=head2 _preload
  Description: Remove all children (used after hash transformation to ensure object is minimised)
  Returntype : none
  Exceptions : none
  Caller     : dump_metadata.pl
  Status     : Stable
=cut

sub _unload {
  my ($self) = @_;
  $self->{sequences} = undef;
  return;
}

1;

