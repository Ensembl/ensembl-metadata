
=head1 LICENSE

Copyright [1999-2014] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::MetaData::GenomeOrganismInfo

=head1 SYNOPSIS

	  my $info =
		Bio::EnsEMBL::MetaData::GenomeOrganismInfo->new(
		-DISPLAY_NAME=>$display_name, -NAME=>$name, -STRAIN=>$strain, -SEROTYPE=>$serotype, -IS_REFERENCE=>$is_reference
      );

=head1 DESCRIPTION

Object encapsulating information about the organism to which a particular genome belongs

=head1 SEE ALSO

Bio::EnsEMBL::MetaData::BaseInfo
Bio::EnsEMBL::MetaData::DBSQL::GenomeOrganismInfoAdaptor

=head1 AUTHOR

Dan Staines

=cut

package Bio::EnsEMBL::MetaData::GenomeOrganismInfo;
use base qw/Bio::EnsEMBL::MetaData::BaseInfo/;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use strict;
use warnings;

=head1 CONSTRUCTOR
=head2 new
  Arg [-NAME]  : 
       string - human readable version of the name of the organism
  Arg [-SPECIES]    : 
       string - computable version of the name of the organism (lower case, no spaces)
   Arg [-TAXONOMY_ID] :
        string - NCBI taxonomy identifier
  Arg [-SPECIES_TAXONOMY_ID] :
        string - NCBI taxonomy identifier of species to which this organism belongs
  Arg [-STRAIN]:
        string - name of strain to which organism belongs
  Arg [-SEROTYPE]:
        string - name of serotype to which organism belongs
  Arg [-IS_REFERENCE]:
        bool - 1 if this organism is the reference for its species

  Example    : $info = Bio::EnsEMBL::MetaData::GenomeOrganismInfo->new(...);
  Description: Creates a new info object
  Returntype : Bio::EnsEMBL::MetaData::GenomeOrganismInfo
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub new {
  my ( $class, @args ) = @_;
  my $self = $class->SUPER::new(@args);
  ( $self->{display_name}, $self->{name},
    $self->{strain},       $self->{serotype},
    $self->{is_reference}, $self->{taxonomy_id},
    $self->{species_taxonomy_id} )
    = rearrange( [ 'DISPLAY_NAME', 'NAME',
                   'STRAIN',       'SEROTYPE',
                   'IS_REFERENCE', 'TAXONOMY_ID',
                   'SPECIES_TAXONOMY_ID' ],
                 @args );
  $self->{is_reference} ||= 0;
  return $self;
}

=head1 ATTRIBUTE METHODS

=head2 name
  Arg        : (optional) computationally safe name for species name to set
  Description: Gets/sets computationally safe name for species name for genome
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub name {
  my ( $self, $arg ) = @_;
  $self->{name} = $arg if ( defined $arg );
  return $self->{name};
}

=head2 display_name
  Arg        : (optional) display_name to set
  Description: Gets/sets display_name 
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub display_name {
  my ( $self, $display_name ) = @_;
  $self->{display_name} = $display_name if ( defined $display_name );
  return $self->{display_name};
}

=head2 strain
  Arg        : (optional) strain to set
  Description: Gets/sets strain of genome
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub strain {
  my ( $self, $arg ) = @_;
  $self->{strain} = $arg if ( defined $arg );
  return $self->{strain};
}

=head2 serotype
  Arg        : (optional) serotype to set
  Description: Gets/sets serotype
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub serotype {
  my ( $self, $arg ) = @_;
  $self->{serotype} = $arg if ( defined $arg );
  return $self->{serotype};
}

=head2 taxonomy_id
  Arg        : (optional) taxonomy_id to set
  Description: Gets/sets NCBI taxonomy ID
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub taxonomy_id {
  my ( $self, $taxonomy_id ) = @_;
  $self->{taxonomy_id} = $taxonomy_id if ( defined $taxonomy_id );
  return $self->{taxonomy_id};
}

=head2 species_taxonomy_id
  Arg        : (optional) taxonomy_id to set
  Description: Gets/sets NCBI taxonomy ID of species to which this belongs
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub species_taxonomy_id {
  my ( $self, $taxonomy_id ) = @_;
  $self->{species_taxonomy_id} = $taxonomy_id if ( defined $taxonomy_id );
  return $self->{species_taxonomy_id};
}

=head2 aliases
  Arg        : (optional) arrayref of aliases to set
  Description: Gets/sets aliases by which the genome is also known 
  Returntype : Arrayref of aliases
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub aliases {
  my ( $self, $aliases ) = @_;
  if ( defined $aliases ) {
    $self->{aliases} = $aliases;
  }
  $self->_load_child( 'aliases', '_fetch_aliases' );
  return $self->{aliases};
}

=head2 publications
  Arg        : (optional) arrayref of pubmed IDs to set
  Description: Gets/sets PubMed IDs for publications associated with the genome
  Returntype : Arrayref of PubMed IDs
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub publications {
  my ( $self, $publications ) = @_;
  if ( defined $publications ) {
    $self->{publications} = $publications;
  }
  $self->_load_child( 'publications', '_fetch_publications' );
  return $self->{publications};
}

=head2 is_reference
  Arg        : (optional) whether organism is reference
  Description: Gets/sets whether this organism is the reference for its species
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub is_reference {
  my ( $self, $is_reference ) = @_;
  $self->{is_reference} = $is_reference if ( defined $is_reference );
  return $self->{is_reference};
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
  return $self->name();
}

1;
