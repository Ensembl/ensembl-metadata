
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

=cut

=pod

=head1 NAME

Bio::EnsEMBL::MetaData::GenomeAssemblyInfo

=head1 SYNOPSIS

	  my $assembly_info =
		Bio::EnsEMBL::MetaData::GenomeAssemblyInfo->new(
											  -ASSEMBLY_NAME   => $assembly_name,
											  -ASSEMBLY_ID     => $assembly_id,
											  -ASSEMBLY_LEVEL => $assembly_level
		);

=head1 DESCRIPTION

Object encapsulating information about a particular assembly

=head1 Author

Dan Staines

=cut

package Bio::EnsEMBL::MetaData::GenomeAssemblyInfo;
use base qw/Bio::EnsEMBL::MetaData::BaseInfo/;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use strict;
use warnings;

=head1 CONSTRUCTOR
=head2 new
  Arg [-ASSEMBLY_NAME] :
        string - name of the assembly
  Arg [-ASSEMBLY_ID] :
        string - INSDC assembly accession
  Arg [-ASSEMBLY_LEVEL] :
        string - highest assembly level (chromosome, supercontig etc.)
|
  Example    : $info = Bio::EnsEMBL::MetaData::GenomeAssemnblyInfo->new(...);
  Description: Creates a new info object
  Returntype : Bio::EnsEMBL::MetaData::GenomeAssemblyInfo
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub new {
	my ( $class, @args ) = @_;
	my $self = $class->SUPER::new(@args);
	(  $self->{assembly_name},  $self->{assembly_id},
	   $self->{assembly_level}, $self->{base_count} )
	  = rearrange( [ 'ASSEMBLY_NAME',  'ASSEMBLY_ID',
					 'ASSEMBLY_LEVEL', 'BASE_COUNT' ],
				   @args );
	return $self;
}

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

=head2 assembly_id
  Arg        : (optional) assembly_id to set
  Description: Gets/sets INSDC accession for assembly
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub assembly_id {
	my ( $self, $assembly_id ) = @_;
	$self->{assembly_id} = $assembly_id if ( defined $assembly_id );
	return $self->{assembly_id};
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
	elsif ( !defined $self->{sequences} && defined $self->adaptor() ) {
		$self->adaptor()->_fetch_sequences($self);
	}
	return $self->{sequences};
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
