
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

use strict;
use warnings;

package Bio::EnsEMBL::Utils::MetaData::DBAFinder::ProductionDBAFinder;
use base
  qw( Bio::EnsEMBL::Utils::MetaData::DBAFinder::DbHostDBAFinder );
use Bio::EnsEMBL::Utils::Exception qw/throw warning/;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Registry;

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

__END__

=pod

=head1 NAME

Bio::EnsEMBL::Utils::MetaData::DBAFinder::DbHostDBAFinder

=head1 SYNOPSIS

=head1 DESCRIPTION

implementation using a registry built from a specified server to build a list of DBAs

=head1 SUBROUTINES/METHODS

=head2 new

=head2 get_dbas
Description : Return list of DBAs to work on

=head1 AUTHOR

dstaines

=head1 MAINTAINER

$Author$

=head1 VERSION

$Revision$

=cut
