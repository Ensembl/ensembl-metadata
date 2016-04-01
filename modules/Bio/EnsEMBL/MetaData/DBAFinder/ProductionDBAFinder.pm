=head1 LICENSE

Copyright [2009-2016] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::MetaData::DBAFinder

=head1 SYNOPSIS

=head1 DESCRIPTION

Implementation finding DBAs using production database

=head1 AUTHOR

Dan Staines

=cut

use strict;
use warnings;

package Bio::EnsEMBL::MetaData::DBAFinder::ProductionDBAFinder;
use base
  qw( Bio::EnsEMBL::MetaData::DBAFinder::DbHostDBAFinder );
use Bio::EnsEMBL::Utils::Exception qw/throw warning/;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Registry;

=head1 SUBROUTINES/METHODS
=head2 new
Arg         : [-USER] user
Arg         : [-PASS] password
Arg         : [-HOST] host to load from
Arg         : [-PORT] port to connect to
Arg         : [-MUSER] production user
Arg         : [-MPASS] production password
Arg         : [-MHOST] host with production database
Arg         : [-MPORT] production port
Arg         : [-MDBNAME] production database name
Description : Create a new object
Returntype  : Bio::EnsEMBL::MetaData::DBAFinder::ProductionDBAFinder
=cut
sub new {
  my ( $proto, @args ) = @_;
  my $self = $proto->SUPER::new(@args);
  # get the production database
  my ( $mhost, $mport, $muser, $mpass, $mdbname ) =
	rearrange( [ 'MHOST', 'MPORT', 'MUSER', 'MPASS', 'MDBNAME' ],
			   @args );
  $self->{production_dbc} =
	Bio::EnsEMBL::DBSQL::DBConnection->new( -USER =>,
											$muser,
											-PASS =>,
											$mpass,
											-HOST =>,
											$mhost,
											-PORT =>,
											$mport,
											-DBNAME =>,
											$mdbname );

  return $self;
}
=head2 get_dbas
  Description: Find DBAs to work on
  Returntype : Arrayref of Bio::EnsEMBL::DBSQL::DBAdaptor
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut
sub get_dbas {
  my ($self) = @_;
  if ( !defined $self->{dbas} ) {
	$self->{dbas} = Bio::EnsEMBL::Registry->get_all_DBAdaptors();
	$self->{logger}
	  ->info( "Found " . scalar( @{ $self->{dbas} } ) . " DBAs" );
	# get parents and hash by DB
	my $dbs = {};
	for my $dba ( @{ $self->{dbas} } ) {
	  push @{ $dbs->{ $dba->dbc()->dbname() } }, $dba;
	}

	my @dbs;
	# restrict by division
	if ( defined $self->{division} ) {
	  @dbs = @{
		$self->{production_dbc}->sql_helper()->execute_simple(
		  -SQL =>
q/select full_db_name as db_name from db_list join db using (db_id) 
join species using (species_id) join division_species using (species_id) 
join division using (division_id)  where db.is_current=1 and division.name=? 
UNION select db_name from division_db join division using (division_id) 
where division_db.is_current=1 and db_type='COMPARA' and division.name=?/,
		  -PARAMS => [ $self->{division}, $self->{division} ] ) };
	}
	elsif ( defined $self->{species} ) {
	  @dbs = @{
		$self->{production_dbc}->sql_helper()->execute_simple(
		  -SQL =>
q/select full_db_name as db_name from db_list join db using (db_id) join species using (species_id) where db.is_current=1 and production_name=?/,
		  -PARAMS => [ $self->{species} ] ) };
	}
	else {
	  @dbs = @{
		$self->{production_dbc}->sql_helper()->execute_simple(
		  -SQL =>
q/select full_db_name as db_name from db_list join db using (db_id) where db.is_current=1 
UNION select db_name from division_db where division_db.is_current=1 and db_type='COMPARA'/
		) };

	}
	# filter by pattern/dbname
	if ( defined $self->{dbname} ) {
	  @dbs = grep { $_ eq $self->{dbname} } @dbs;
	}
	elsif ( defined $self->{pattern} ) {
	  @dbs = grep { $_ =~ m/$self->{pattern}/i } @dbs;
	}

	$self->{dbas} = [];
	for my $db (@dbs) {
	  my $dba_list = $dbs->{$db};
	  if ( defined $dba_list ) {
		push @{ $self->{dbas} }, @$dba_list;
	  }
	  else {
		throw "Expected database $db not found";
	  }
	}
  } ## end if ( !defined $self->{...})
  return $self->{dbas};
} ## end sub get_dbas

1;
