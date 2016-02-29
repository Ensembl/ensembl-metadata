
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

Bio::EnsEMBL::MetaData::DBSQL::GenomeAssemblyInfoAdaptor

=head1 SYNOPSIS

TODO

=head1 DESCRIPTION

Adaptor for storing and retrieving GenomeAssemblyInfo objects from MySQL ensembl_metadata database

=head1 Author

Dan Staines

=cut

package Bio::EnsEMBL::MetaData::DBSQL::GenomeAssemblyInfoAdaptor;

use strict;
use warnings;

use base qw/Bio::EnsEMBL::MetaData::DBSQL::BaseInfoAdaptor/;

use Carp qw(cluck croak);
use Bio::EnsEMBL::Utils::Argument qw( rearrange );
use Scalar::Util qw(looks_like_number);
use Bio::EnsEMBL::DBSQL::DBConnection;
use Bio::EnsEMBL::MetaData::GenomeAssemblyInfo;
use List::MoreUtils qw(natatime);

=head1 METHODS
=cut

sub store {
	my ( $self, $assembly ) = @_;
	if ( !defined $assembly->organism() ) {
		throw("Assembly must be associated with an organism");
	}
	if ( !defined $assembly->organism()->dbID() ) {
		$self->db()->get_GenomeOrganismInfoAdaptor()
		  ->store( $assembly->organism() );
	}
	if ( !defined $assembly->dbID() ) {
		# find out if organism exists first
		my ($dbID) =
		  @{$self->dbc()->sql_helper()->execute_simple(
				-SQL =>
"select assembly_id from assembly where organism_id=? and assembly_name=?",
				-PARAMS => [ $assembly->organism()->dbID(), $assembly->assembly_name() ]
			) };
		if ( defined $dbID ) {
			$assembly->dbID($dbID);
			$assembly->adaptor($self);
		}
	}
	if ( defined $assembly->dbID() ) {
		$self->update($assembly);
	}
	else {
		$self->dbc()->sql_helper()->execute_update(
			-SQL =>
q/insert into assembly(assembly_accession,assembly_name,assembly_level,base_count,organism_id)
		values(?,?,?,?,?)/,
			-PARAMS => [ $assembly->assembly_accession(),
						 $assembly->assembly_name(),
						 $assembly->assembly_level(),
						 $assembly->base_count(),
						 $assembly->organism()->dbID() ],
			-CALLBACK => sub {
				my ( $sth, $dbh, $rv ) = @_;
				$assembly->dbID( $dbh->{mysql_insertid} );
			} );
		$self->_store_sequences($assembly);
		$assembly->adaptor($self);
		$self->_store_cached_obj($assembly);
	}
	return;
} ## end sub store

sub update {
	my ( $self, $assembly ) = @_;
	if ( !defined $assembly->dbID() ) {
		croak "Cannot update an object that has not already been stored";
	}

	$self->dbc()->sql_helper()->execute_update(
		-SQL =>
q/update assembly set assembly_accession=?,assembly_name=?,assembly_level=?,base_count=?,organism_id=? where assembly_id=?/,
		-PARAMS => [
			$assembly->assembly_accession(),
			$assembly->assembly_name(),
			$assembly->assembly_level(), $assembly->base_count(),
			$assembly->organism()->dbID(), $assembly->dbID() ] );

	$self->_store_sequences($assembly);
	return;
}

=head2 _store_sequences
  Arg	     : Bio::EnsEMBL::MetaData::GenomeAssemblyInfo
  Description: Stores the sequences for the supplied object
  Returntype : None
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub _store_sequences {
	my ( $self, $assembly ) = @_;

	$self->{dbc}->sql_helper()->execute_update(
					 -SQL => q/delete from assembly_sequence where assembly_id=?/,
					 -PARAMS => [ $assembly->dbID() ] );

	return if !defined $assembly->sequences();

	my $it = natatime 1000, @{ $assembly->sequences() };
	while ( my @vals = $it->() ) {
		my $sql =
		  'insert ignore into assembly_sequence(assembly_id,name,acc) values ' .
		  join(
			',',
			map {
				'(' . $assembly->dbID() . ',"' . $_->{name} . '",' .
				  ( $_->{acc} ? ( '"' . $_->{acc} . '"' ) : ('NULL') ) . ')'
			} @vals );
		$self->dbc()->sql_helper()->execute_update( -SQL => $sql );
	}
	return;
}

=head2 fetch_all_by_sequence_accession
  Arg	     : INSDC sequence accession e.g. U00096.1 or U00096
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch genome info for specified sequence accession
  Returntype : Bio::EnsEMBL::MetaData::GenomeAssemblyInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_all_by_sequence_accession {
	my ( $self, $id, $keen ) = @_;
	if ( $id =~ m/\.[0-9]+$/ ) {
		return $self->fetch_all_by_sequence_accession_versioned( $id, $keen );
	}
	else {
		return $self->fetch_all_by_sequence_accession_unversioned( $id, $keen );
	}
}

=head2 fetch_all_by_sequence_accession_unversioned
  Arg	     : INSDC sequence accession e.g. U00096
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch genome info for specified sequence accession
  Returntype : Bio::EnsEMBL::MetaData::GenomeAssemblyInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_all_by_sequence_accession_unversioned {
	my ( $self, $id, $keen ) = @_;
	return
	  $self->_fetch_generic(
		$self->_get_base_sql() .
' where assembly_id in (select distinct(assembly_id) from assembly_sequence where acc like ? or name like ?)',
		[ $id . '.%', $id . '.%' ],
		$keen );
}

=head2 fetch_all_by_sequence_accession_versioned
  Arg	     : INSDC sequence accession e.g. U00096.1
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch genome info for specified sequence accession
  Returntype : Bio::EnsEMBL::MetaData::GenomeInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_all_by_sequence_accession_versioned {
	my ( $self, $id, $keen ) = @_;
	return
	  $self->_fetch_generic(
		$self->_get_base_sql() .
' where assembly_id in (select distinct(assembly_id) from assembly_sequence where acc=? or name=?)',
		[ $id, $id ],
		$keen );
}

=head2 fetch_by_assembly_accession
  Arg	     : INSDC assembly accession
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch genome info for specified assembly ID (versioned or unversioned)
  Returntype : Bio::EnsEMBL::MetaData::GenomeAssemblyInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_by_assembly_accession {
	my ( $self, $id, $keen ) = @_;
	return
	  $self->_first_element( $self->_fetch_generic(
							 $self->_get_base_sql . ' where assembly_accession=?',
							 [ $id ], $keen ) );

}

=head2 fetch_all_by_assembly_set_chain
  Arg	       : INSDC assembly set chain (unversioned accession)
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch genome info for specified assembly set chain
  Returntype : Bio::EnsEMBL::MetaData::GenomeAssemblyInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_all_by_assembly_set_chain {
	my ( $self, $id, $keen ) = @_;
	return $self->_fetch_generic(
							 $self->_get_base_sql . ' where assembly_accession like ?',
							 [ $id . '.%' ], $keen );
}

=head2 fetch_all_by_organism
  Arg	       : GenomeOrganismInfo object
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch genome info for specified organism
  Returntype : Bio::EnsEMBL::MetaData::GenomeAssemblyInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_all_by_organism {
	my ( $self, $organism_id, $keen ) = @_;
	if (ref($organism_id) eq 'Bio::EnsEMBL::MetaData::GenomeOrganismInfo')
	{
		$organism_id = $organism_id->dbID();
	}
	return
	  $self->_fetch_generic( $self->_get_base_sql() . ' where organism_id = ?',
							 [$organism_id], $keen );
}

=head2 _fetch_sequences
  Arg	     : Bio::EnsEMBL::MetaData::GenomeInfo 
  Description: Add sequences to supplied object
  Returntype : none
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub _fetch_sequences {
	my ( $self, $genome ) = @_;
	croak
"Cannot fetch sequences for a GenomeAssemblyInfo object that has not been stored"
	  if !defined $genome->dbID();
	my $sequences =
	  $self->dbc()->sql_helper()->execute(
		   -USE_HASHREFS => 1,
		   -SQL => 'select name,acc from assembly_sequence where assembly_id=?',
		   -PARAMS => [ $genome->dbID() ] );
	$genome->sequences($sequences);
	return;
}

=head2 _fetch_children
  Arg	     : Arrayref of Bio::EnsEMBL::MetaData::GenomeInfo
  Description: Fetch all children of specified genome info object
  Returntype : none
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub _fetch_children {
	my ( $self, $md ) = @_;
	$self->_fetch_sequences($md);
	if ( defined $md->{organism_id} ) {
		$md->organism( $self->db()->get_GenomeOrganismInfoAdaptor()
					   ->fetch_by_dbID( $md->{organism_id} ) );
	}
	return;
}

my $base_organism_fetch_sql =
q/select assembly_id as dbID, organism_id, assembly_accession, assembly_name, assembly_level, base_count from assembly/;

sub _get_base_sql {
	return $base_organism_fetch_sql;
}

sub _get_id_field {
	return 'assembly_id';
}

sub _get_obj_class {
	return 'Bio::EnsEMBL::MetaData::GenomeAssemblyInfo';
}

1;
