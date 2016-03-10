
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
my $md = $gdba->fetch_by_name("arabidopsis_thaliana");

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
my $genome = $gdba->fetch_by_name('arabidopsis_thaliana');

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

package Bio::EnsEMBL::MetaData::DBSQL::GenomeComparaInfoAdaptor;

use strict;
use warnings;

use base qw/Bio::EnsEMBL::MetaData::DBSQL::BaseInfoAdaptor/;

use Carp qw(cluck croak);
use Bio::EnsEMBL::Utils::Argument qw( rearrange );
use List::MoreUtils qw(natatime);

sub fetch_all_by_division {
  my ( $self, $division ) = @_;
  return $self->_fetch_generic_with_args( { division => $division } );
}

=head2 fetch_all_compara_by_method
  Arg	     : Method of compara analyses to retrieve
  Description: Fetch compara specified compara analysis
  Returntype : array ref of  Bio::EnsEMBL::MetaData::GenomeComparaInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_all_by_method {
  my ( $self, $method ) = @_;
  return $self->_fetch_generic_with_args( { method => $method } );
}

=head2 fetch_compara_by_dbname_method_set
  Arg	     : DBName of compara analyses to retrieve
  Arg	     : Method of compara analyses to retrieve
  Arg	     : Set of compara analyses to retrieve
  Description: Fetch specified compara analysis
  Returntype : Bio::EnsEMBL::MetaData::GenomeComparaInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_by_dbname_method_set {
  my ( $self, $dbname, $method, $set_name ) = @_;
  return
    _first_element(
       $self->_fetch_generic_with_args(
         { dbname => $dbname, method => $method, set_name => $set_name }
       ) );
}

=head1 METHODS
=cut

=head2 update
  Arg	     : Bio::EnsEMBL::MetaData::GenomeComparaInfo
  Description: Updates the supplied object and all associated  genomes
  Returntype : None
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub update {
  my ( $self, $compara ) = @_;
  if ( !defined $compara->dbID() ) {
    croak "Cannot update compara object with no dbID";
  }
  $self->dbc()->sql_helper()->execute_update(
    -SQL => q/update compara_analysis 
	  set method=?,division=?,set_name=?,dbname=? 
	  where compara_analysis_id=?/,
    -PARAMS => [ $compara->method(),   $compara->division(),
                 $compara->set_name(), $compara->dbname(),
                 $compara->dbID() ] );
  $self->_store_compara_genomes($compara);
  $self->_store_cached_obj($compara);
  return;
}

=head2 store
  Arg	     : Bio::EnsEMBL::MetaData::GenomeComparaInfo
  Description: Stores the supplied object and all associated  genomes (if not already stored)
  Returntype : None
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub store {
  my ( $self, $compara ) = @_;
  # check if it already exists
  if ( !defined $compara->dbID() ) {
    # find out if compara exists first
    my ($dbID) =
      @{
      $self->dbc()->sql_helper()->execute_simple(
        -SQL =>
q/select compara_analysis_id from compara_analysis where division=? and method=? and set_name=? and dbname=?/,
        -PARAMS => [ $compara->division(), $compara->method(),
                     $compara->set_name(), $compara->dbname() ] ) };
    if ( defined $dbID ) {
      $compara->dbID($dbID);
      $compara->adaptor($self);
    }
  }
  if ( defined $compara->dbID() ) {
    return $self->update($compara);
  }
  $self->dbc()->sql_helper()->execute_update(
    -SQL =>
      q/insert into compara_analysis(method,division,set_name,dbname)
		values(?,?,?,?)/,
    -PARAMS => [ $compara->method(),   $compara->division(),
                 $compara->set_name(), $compara->dbname() ],
    -CALLBACK => sub {
      my ( $sth, $dbh, $rv ) = @_;
      $compara->dbID( $dbh->{mysql_insertid} );
    } );
  $self->_store_compara_genomes($compara);
  $self->_store_cached_obj($compara);
  return;
} ## end sub store

sub _store_compara_genomes {
  my ( $self, $compara ) = @_;
  $self->dbc()->sql_helper()->execute_update(
    -SQL =>
q/delete from genome_compara_analysis where compara_analysis_id=?/,
    -PARAMS => [ $compara->dbID() ] );
  if ( defined $compara->genomes() ) {
    for my $genome ( @{ $compara->genomes() } ) {
      if ( !defined $genome->dbID() ) {
        $self->get_GenomeInfoAdaptor()->store($genome);
      }
      $self->dbc()->sql_helper()->execute_update(
        -SQL =>
q/insert into genome_compara_analysis(genome_id,compara_analysis_id)
		values(?,?)/,
        -PARAMS => [ $genome->dbID(), $compara->dbID() ] );
    }
  }
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
  my ( $self, $compara ) = @_;
  $self->_fetch_compara_genomes($compara);
  return;
}

sub _fetch_compara_genomes {
  my ( $self, $compara ) = @_;
# add genomes on one by one (don't nest the fetch here as could run of connections)
  if ( !defined $compara->{genomes} ) {
    my $genomes = [];
    for my $genome_id (
      @{$self->dbc()->sql_helper()->execute_simple(
          -SQL =>
q/select distinct(genome_id) from genome_compara_analysis where compara_analysis_id=?/,
          -PARAMS => [ $compara->dbID() ] );
      } )
    {
      push @$genomes,
        $self->get_GenomeInfoAdaptor()->fetch_by_dbID($genome_id);
    }
    $compara->genomes($genomes);
  }
  return;
}

my $base_compara_fetch_sql =
q/select compara_analysis_id as dbID, method,division,set_name,dbname from compara_analysis/;

sub _get_base_sql {
  return $base_compara_fetch_sql;
}

sub _get_id_field {
  return 'compara_analysis_id';
}

sub _get_obj_class {
  return 'Bio::EnsEMBL::MetaData::GenomeComparaInfo';
}

1;
