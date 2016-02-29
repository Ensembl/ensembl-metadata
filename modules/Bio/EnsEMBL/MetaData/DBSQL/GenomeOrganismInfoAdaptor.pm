
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

Bio::EnsEMBL::MetaData::DBSQL::GenomeInfoAdaptor

=head1 SYNOPSIS

my $gdba = Bio::EnsEMBL::MetaData::DBSQL::GenomeInfoAdaptor->build_adaptor();
my $md = $gdba->fetch_by_species("arabidopsis_thaliana");

=head1 DESCRIPTION

Adaptor for storing and retrieving GenomeInfo objects from MySQL genome_info database

To start working with an adaptor:

# getting an adaptor
## adaptor for latest public EG release
my $gdba = Bio::EnsEMBL::MetaData::DBSQL::GenomeInfoAdaptor->build_eg_adaptor();
## adaptor for specified public EG release
my $gdba = Bio::EnsEMBL::MetaData::DBSQL::GenomeInfoAdaptor->build_eg_adaptor(21);
## manually specify a given database
my $dbc = Bio::EnsEMBL::DBSQL::DBConnection->new(
-USER=>'anonymous',
-PORT=>4157,
-HOST=>'mysql-eg-publicsql.ebi.ac.uk',
-DBNAME=>'genome_info_21');
my $gdba = Bio::EnsEMBL::MetaData::DBSQL::GenomeInfoAdaptor->new(-DBC=>$dbc);

To find genomes, use the fetch methods e.g.

# find a genome by name
my $genome = $gdba->fetch_by_species('arabidopsis_thaliana');

# find and iterate over all genomes
for my $genome (@{$gdba->fetch_all()}) {
	print $genome->name()."\n";
}

# find and iterate over all genomes from plants
for my $genome (@{$gdba->fetch_all_by_division('EnsemblPlants')}) {
	print $genome->name()."\n";
}

# find and iterate over all genomes with variation
for my $genome (@{$gdba->fetch_all_with_variation()}) {
	print $genome->name()."\n";
}

# find all comparas for the division of interest
my $comparas = $gdba->fetch_all_compara_by_division('EnsemblPlants');

# find the peptide compara
my ($compara) = grep {$_->is_peptide_compara()} @$comparas;
print $compara->division()." ".$compara->method()."(".$compara->dbname().")\n";

# print out all the genomes in this compara
for my $genome (@{$compara->genomes()}) {
	print $genome->name()."\n";
}

=head1 Author

Dan Staines

=cut

package Bio::EnsEMBL::MetaData::DBSQL::GenomeOrganismInfoAdaptor;

use strict;
use warnings;

use base qw/Bio::EnsEMBL::MetaData::DBSQL::BaseInfoAdaptor/;

use Carp qw(cluck croak);
use Bio::EnsEMBL::Utils::Argument qw( rearrange );
use Bio::EnsEMBL::MetaData::GenomeOrganismInfo;
use List::MoreUtils qw(natatime);

=head1 METHODS
=cut

sub store {
	my ( $self, $organism ) = @_;
	if ( !defined $organism->dbID() ) {
		# find out if organism exists first
		my ($dbID) =
		  @{$self->dbc()->sql_helper()->execute_simple(
						-SQL => "select organism_id from organism where name=?",
						-PARAMS => [ $organism->name() ] ) };

		if ( defined $dbID ) {
			$organism->dbID($dbID);
			$organism->adaptor($self);
		}
	}
	if ( defined $organism->dbID() ) {
		$self->update($organism);
	}
	else {
		$self->dbc()->sql_helper()->execute_update(
			-SQL =>
			  q/insert into organism(name,species,strain,serotype,taxonomy_id,
species_taxonomy_id,is_reference)
		values(?,?,?,?,?,?,?)/,
			-PARAMS => [ $organism->name(),
						 $organism->species(),
						 $organism->strain(),
						 $organism->serotype(),
						 $organism->taxonomy_id(),
						 $organism->species_taxonomy_id(),
						 $organism->is_reference() ],
			-CALLBACK => sub {
				my ( $sth, $dbh, $rv ) = @_;
				$organism->dbID( $dbh->{mysql_insertid} );
			} );
		$self->_store_aliases($organism);
		$self->_store_publications($organism);
		$organism->adaptor($self);
		$self->_store_cached_obj($organism);
	}
	return;
} ## end sub store

sub update {
	my ( $self, $organism ) = @_;
	if ( !defined $organism->dbID() ) {
		croak "Cannot update an object that has not already been stored";
	}

	$self->dbc()->sql_helper()->execute_update(
		-SQL =>
q/update organism set name=?,species=?,strain=?,serotype=?,taxonomy_id=?,species_taxonomy_id=?,
is_reference=? where organism_id=?/,
		-PARAMS => [ $organism->name(),
					 $organism->species(),
					 $organism->strain(),
					 $organism->serotype(),
					 $organism->taxonomy_id(),
					 $organism->species_taxonomy_id(),
					 $organism->is_reference(),
					 $organism->dbID() ] );

	$self->_store_aliases($organism);
	$self->_store_publications($organism);
	return;
}

=head2 _store_aliases
  Arg	     : Bio::EnsEMBL::MetaData::GenomeOrganismInfo
  Description: Stores the aliases for the supplied object
  Returntype : None
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub _store_aliases {
	my ( $self, $organism ) = @_;

	$self->dbc()->sql_helper()->execute_update(
					  -SQL => q/delete from organism_alias where organism_id=?/,
					  -PARAMS => [ $organism->dbID() ] );
	if ( defined $organism->aliases() ) {
		for my $alias ( @{ $organism->aliases() } ) {

			$self->dbc()->sql_helper()->execute_update(
				-SQL => q/insert into organism_alias(organism_id,alias)
		values(?,?)/,
				-PARAMS => [ $organism->dbID(), $alias ] );
		}
	}
	return;
}

=head2 _store_publications
  Arg	     : Bio::EnsEMBL::MetaData::OrganismInfo
  Description: Stores the publications for the supplied object
  Returntype : None
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub _store_publications {
	my ( $self, $organism ) = @_;

	$self->dbc()->sql_helper()->execute_update(
				-SQL => q/delete from organism_publication where organism_id=?/,
				-PARAMS => [ $organism->dbID() ] );

	if ( defined $organism->publications() ) {
		for my $pub ( @{ $organism->publications() } ) {
			$self->dbc()->sql_helper()->execute_update(
				-SQL =>
				  q/insert into organism_publication(organism_id,publication)
		values(?,?)/,
				-PARAMS => [ $organism->dbID(), $pub ] );
		}
	}
	return;
}

=head2 fetch_by_taxonomy_id
  Arg	     : Taxonomy ID
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch genome info for specified taxonomy node
  Returntype : arrayref of Bio::EnsEMBL::MetaData::GenomeInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_all_by_taxonomy_id {
	my ( $self, $id, $keen ) = @_;
	return $self->_fetch_generic_with_args( { 'taxonomy_id', $id }, $keen );
}

=head2 fetch_by_taxonomy_ids
  Arg	     : Arrayref of Taxonomy ID
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch genome info for specified taxonomy nodes (batch)
  Returntype : arrayref of Bio::EnsEMBL::MetaData::GenomeInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_all_by_taxonomy_ids {
	my ( $self, $ids, $keen ) = @_;

	# filter list down
	my %ids = map { $_ => 1 } @$ids;
	my @tids = grep { defined $ids{$_} }
	  @{$self->dbc()->sql_helper()->execute_simple(
							  -SQL => q/select distinct taxonomy_id from organism/
		) };
	my @genomes = ();
	my $it = natatime 1000, @tids;
	while ( my @vals = $it->() ) {
		my $sql =
		  _get_base_sql() . ' where taxonomy_id in (' .
		  join( ',', @vals ) . ')';
		@genomes = ( @genomes, @{ $self->_fetch_generic( $sql, [] ) } );
	}
	return \@genomes;
}

=head2 fetch_all_by_taxonomy_branch
  Arg	     : Bio::EnsEMBL::TaxonomyNode
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch genome info for specified taxonomy node and its children
  Returntype : arrayref of Bio::EnsEMBL::MetaData::GenomeInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_all_by_taxonomy_branch {
	my ( $self, $root, $keen ) = @_;
	if ( ref($root) ne 'Bio::EnsEMBL::Taxonomy::TaxonomyNode' ) {
		if ( looks_like_number($root) ) {
			$root = $self->taxonomy_adaptor()->fetch_by_taxon_id($root);
		}
		else {
			($root) = @{ $self->taxonomy_adaptor()->fetch_all_by_name($root) };
		}
	}
	my @taxids =
	  ( $root->taxon_id(), @{ $root->adaptor()->fetch_descendant_ids($root) } );
	return $self->fetch_all_by_taxonomy_ids( \@taxids );
}

=head2 fetch_by_species
  Arg	     : Name of species
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch genome info for specified species
  Returntype : Bio::EnsEMBL::MetaData::GenomeInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_by_species {
	my ( $self, $species, $keen ) = @_;
	return $self->_first_element(
			$self->_fetch_generic_with_args( { 'species', $species }, $keen ) );
}

=head2 fetch_by_name
  Arg	     : Display name of genome 
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch genome info for specified species
  Returntype : Bio::EnsEMBL::MetaData::GenomeInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_by_name {
	my ( $self, $name, $keen ) = @_;
	return $self->_first_element(
				  $self->_fetch_generic_with_args( { 'name', $name }, $keen ) );
}

=head2 fetch_any_by_name
  Arg	     : Name of genome (display, species, alias etc)
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch genome info for specified species
  Returntype : Bio::EnsEMBL::MetaData::GenomeInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_by_any_name {
	my ( $self, $name, $keen ) = @_;
	my $dba = $self->fetch_by_name( $name, $keen );
	if ( !defined $dba ) {
		$dba = $self->fetch_by_species( $name, $keen );
	}
	if ( !defined $dba ) {
		$dba = $self->fetch_by_alias( $name, $keen );
	}
	return $dba;
}

=head2 fetch_all_by_name_pattern
  Arg	     : Regular expression matching of genome
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch genome info for specified species
  Returntype : Arrayref of Bio::EnsEMBL::MetaData::GenomeInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_all_by_name_pattern {
	my ( $self, $name, $keen ) = @_;
	return
	  $self->_fetch_generic(
				 _get_base_sql() . q/ where species REGEXP ? or name REGEXP ? /,
				 [ $name, $name ], $keen );
}

=head2 fetch_by_alias
  Arg	     : Alias of genome
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch genome info for specified species
  Returntype : Bio::EnsEMBL::MetaData::GenomeInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_by_alias {
	my ( $self, $name, $keen ) = @_;
	return
	  $self->_first_element(
					$self->_fetch_generic(
						_get_base_sql() .
						  q/ join organism_alias using (organism_id) where alias=?/,
						[$name],
						$keen ) );
}

=head2 _fetch_publications
  Arg	     : Bio::EnsEMBL::MetaData::GenomeInfo 
  Description: Add publications to supplied object
  Returntype : none
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub _fetch_publications {
	my ( $self, $org ) = @_;
	croak "Cannot fetch publications for an object that has not been stored"
	  if !defined $org->dbID();
	my $pubs =
	  $self->dbc()->sql_helper()->execute_simple(
		   -SQL =>
			 'select publication from organism_publication where organism_id=?',
		   -PARAMS => [ $org->dbID() ] );
	$org->publications($pubs);
	return;
}

=head2 _fetch_aliases
  Arg	     : Bio::EnsEMBL::MetaData::GenomeInfo 
  Description: Add aliases to supplied object
  Returntype : none
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub _fetch_aliases {
	my ( $self, $org ) = @_;
	croak
	  "Cannot fetch aliases for a GenomeInfo object that has not been stored"
	  if !defined $org->dbID();
	my $aliases =
	  $self->dbc()->sql_helper()->execute_simple(
				 -SQL => 'select alias from organism_alias where organism_id=?',
				 -PARAMS => [ $org->dbID() ] );
	$org->aliases($aliases);
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
	$self->_fetch_aliases($md);
	$self->_fetch_publications($md);
	return;
}

my $base_organism_fetch_sql =
q/select organism_id as dbID, name, species, taxonomy_id, species_taxonomy_id, strain, serotype, is_reference from organism/;

sub _get_base_sql {
	return $base_organism_fetch_sql;
}

sub _get_id_field {
	return 'organism_id';
}

sub _get_obj_class {
	return 'Bio::EnsEMBL::MetaData::GenomeOrganismInfo';
}

1;
