
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

Bio::EnsEMBL::MetaData::GenomeComparaInfo

=head1 SYNOPSIS

	  my $compara_info =
		Bio::EnsEMBL::MetaData::GenomeComparaInfo->new(
								   -DBNAME   => $compara->dbc()->dbname(),
								   -DIVISION => $division,
								   -METHOD   => $method,
								   -SET_NAME => $set_name,
								   -GENOMES  => [$genome1, $genome2]);

=head1 DESCRIPTION

Object encapsulating information about a particular compara analysis and the genomes it involves

=head1 Author

Dan Staines

=cut

package Bio::EnsEMBL::MetaData::GenomeComparaInfo;
use base qw/Bio::EnsEMBL::MetaData::BaseInfo/;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use strict;
use warnings;

=head1 CONSTRUCTOR
=head2 new
  Arg [-DIVISION]  : 
       string - Compara division e.g. plants, pan_homology
  Arg [-METHOD]    : 
       string - compara method e.g. PROTEIN_TREES, LASTZ_NET
  Arg [-DBNAME] : 
       string - name of the compara database in which the analysis can be found
  Arg [-SET_NAME] : 
       string - optional name for the analysis
  Arg [-GENOMES]  : 
       arrayref - list of genomes involved in analysis

  Example    : $info = Bio::EnsEMBL::MetaData::GenomeComparaInfo->new(...);
  Description: Creates a new info object
  Returntype : Bio::EnsEMBL::MetaData::GenomeComparaInfo
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub new {
	my ( $class, @args ) = @_;
	my $self = $class->SUPER::new(@args);
  ( $self->{division}, $self->{method}, $self->{dbname},
	$self->{set_name}, $self->{genomes} )
	= rearrange(
				 [ 'DIVISION', 'METHOD', 'DBNAME', 'SET_NAME', 'GENOMES'
				 ],
				 @args );
  return $self;
}

=head1 ATTRIBUTE METHODS
=head2 dbname
  Arg        : (optional) dbname to set
  Description: Gets/sets name of compara database
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub dbname {
  my ( $self, $arg ) = @_;
  $self->{dbname} = $arg if ( defined $arg );
  return $self->{dbname};
}

=head2 method
  Arg        : (optional) method to set
  Description: Gets/sets name of compara method
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub method {
  my ( $self, $arg ) = @_;
  $self->{method} = $arg if ( defined $arg );
  return $self->{method};
}

=head2 set_name
  Arg        : (optional) species set name to set
  Description: Gets/sets name of species set used in compara analysis
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub set_name {
  my ( $self, $arg ) = @_;
  $self->{set_name} = $arg if ( defined $arg );
  return $self->{set_name};
}

=head2 division
  Arg        : (optional) division to set
  Description: Gets/sets Ensembl compara division
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub division {
  my ( $self, $arg ) = @_;
  $self->{division} = $arg if ( defined $arg );
  return $self->{division};
}

=head2 genomes
  Arg        : (optional) genomes to set
  Description: Gets/sets arrayref of genomes 
  Returntype : arrayref
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub genomes {
  my ( $self, $arg ) = @_;
  $self->{genomes} = $arg if ( defined $arg );
  $self->_load_child("genomes","_fetch_compara_genomes");
  return $self->{genomes};
}

=head1 UTILITY METHODS
=head2 is_pan_compara
  Arg        : (optional) 1/0 to set 
  Description: Boolean-style method, returns 1 if analysis is part of the pan compara, 0 if not
  Returntype : 1 or 0
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub is_pan_compara {
  my ($self) = @_;
  return $self->{division} eq 'EnsemblPan' ? 1 : 0;
}

=head2 is_peptide_compara
  Arg        : (optional) 1/0 to set 
  Description: Boolean-style method, returns 1 if analysis is part of a peptide compara, 0 if not
  Returntype : 1 or 0
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub is_peptide_compara {
  my ($self) = @_;
  return ( $self->{division} ne 'EnsemblPan' &&
		   $self->{method} eq 'PROTEIN_TREES' ) ? 1 : 0;
}

=head2 is_dna_compara
  Arg        : (optional) 1/0 to set 
  Description: Boolean-style method, returns 1 if analysis is part of a DNA compara, 0 if not
  Returntype : 1 or 0
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub is_dna_compara {
  my ($self) = @_;
  return ( $self->{method} eq 'TRANSLATED_BLAT_NET' ||
		   $self->{method} eq 'LASTZ_NET'   ||
		   $self->{method} eq 'TBLAT'       ||
		   $self->{method} eq 'ATAC'        ||
		   $self->{method} eq 'BLASTZ_NET' ) ? 1 : 0;
}

=head2 is_synteny
  Arg        : (optional) 1/0 to set 
  Description: Boolean-style method, returns 1 if analysis is part of a synteny compara, 0 if not
  Returntype : 1 or 0
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub is_synteny {
  my ($self) = @_;
  return ( $self->{method} eq 'SYNTENY' ) ? 1 : 0;
}

=head2 to_hash
  Description: Render compara as plain hash suitable for export as JSON/XML
  Returntype : Hashref
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub to_hash {
  my ($in) = @_;
  my $out = { method             => $in->{method},
			  division           => $in->{division},
			  dbname             => $in->{dbname},
			  set_name           => $in->{set_name},
			  is_pan_compara     => $in->is_pan_compara(),
			  is_peptide_compara => $in->is_peptide_compara(),
			  is_dna_compara     => $in->is_dna_compara(), };
  $out->{genomes} = [];
  for my $genome ( @{ $in->genomes() } ) {
	push @{ $out->{genomes} }, $genome->species();
  }
  return $out;
}

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
	join( '/', $self->division(), $self->method(), ($self->set_name()||'-') );
}

1;
