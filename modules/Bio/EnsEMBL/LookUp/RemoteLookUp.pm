
=head1 LICENSE

Copyright [2009-2023] EMBL-European Bioinformatics Institute

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

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::LookUp

=head1 SYNOPSIS

my $adaptor = Bio::EnsEMBL::MetaData::DBSQL::GenomeInfoAdaptor->build_ensembl_genomes_adaptor();
my $lookup = Bio::EnsEMBL::RemoteLookUp->new(-ADAPTOR=>$adaptor);
my $dbas = $lookup->registry()->get_all();
$dbas = $lookup->get_all_by_taxon_id(388919);
$dbas = $lookup->get_by_name_pattern("Escherichia.*");

=head1 DESCRIPTION

This module is an implementation of Bio::EnsEMBL::LookUp that uses Bio::EnsEMBL::MetaData::DBSQL::GenomeInfoAdaptor to
access a MySQL database containing information about Ensembl and Ensembl Genomes contents and then instantiate DBAdaptors.

To instantiate using the public Ensembl/EG servers for creating DBAdaptors:

	my $lookup = Bio::EnsEMBL::LookUp::RemoteLookUp->new(-ADAPTOR=>$adaptor);

To instantiate to use a specific server on which core databases are located:

	my $lookup = Bio::EnsEMBL::LookUp::RemoteLookUp->new(-USER=>$user, -HOST=>$host, -PORT=>$port, -ADAPTOR=>$adaptor);

Once constructed, the LookUp instance can be used as documented in Bio::EnsEMBL::LookUp.

=head1 SEE ALSO

Bio::EnsEMBL::LookUp

=head1 AUTHOR

Dan Staines

=cut

package Bio::EnsEMBL::LookUp::RemoteLookUp;

use warnings;
use strict;
use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Bio::EnsEMBL::Utils::Scalar qw(assert_ref check_ref);
use Bio::EnsEMBL::MetaData::DBSQL::GenomeInfoAdaptor;
use Bio::EnsEMBL::MetaData::DBSQL::MySQLServerProvider;
use Bio::EnsEMBL::MetaData::DBSQL::ParameterMySQLServerProvider;
use Carp;
use List::MoreUtils qw(uniq);

=head1 SUBROUTINES/METHODS

=head2 new
  Arg [-ADAPTOR]    : Bio::EnsEMBL::MetaData::DBSQL::GenomeInfoAdaptor
  Arg [-REGISTRY]   : Registry to obtain DBAdaptors from
  Arg [-PROVIDER]   : Bio::EnsEMBL::MetaData::DBSQL::MySQLServerProvider
  Arg [-HOST]       : Host containing DBAdaptors
  Arg [-PORT]       : Port  for DBAdaptors
  Arg [-USER]       : User for DBAdaptors
  Arg [-PASS]       : Password for DBAdaptors
  Description       : Creates a new instance of this object. 
  Returntype        : Instance of lookup
  Status            : Stable
  Example       	: 
  my $lookup = Bio::EnsEMBL::RemoteLookUp->new();
=cut

sub new {
  my ( $class, @args ) = @_;
  my $self = bless( {}, ref($class) || $class );
  ( $self->{_adaptor}, $self->{registry}, $self->{user},
    $self->{pass},     $self->{host},     $self->{port},
    $self->{provider} )
    = rearrange( [ 'ADAPTOR', 'REGISTRY', 'USER', 'PASS',
                   'HOST',    'PORT',     'PROVIDER' ],
                 @args );
  if ( !defined $self->{provider} ) {
    # provider is used to figure out where DBAs come from
    if ( defined $self->{host} ) {
      # we have a host, so use a fixed provider
      $self->{provider} =
        Bio::EnsEMBL::MetaData::DBSQL::ParameterMySQLServerProvider->new(
                                                         -HOST => $self->{host},
                                                         -PORT  => $self->{port},
                                                         -USER => $self->{user},
                                                         -PASS => $self->{pass}
        );
    }
    else {
      # default is the public provider
      $self->{provider} =
        Bio::EnsEMBL::MetaData::DBSQL::MySQLServerProvider->new();
    }
  }
  $self->{dba_cache} = {};
  $self->{registry} ||= q/Bio::EnsEMBL::Registry/;
  return $self;
} ## end sub new

=head2 genome_to_dba
	Description : Build a Bio::EnsEMBL::DBSQL::DBAdaptor instance with the supplied info object
	Argument    : Bio::EnsEMBL::MetaData::GenomeInfo
	Argument    : (optional) Group to use
	Exceptions  : None
	Return type : Bio::EnsEMBL::DBSQL::DBAdaptor
=cut

sub genome_to_dba {
  my ( $self, $genome_info ) = @_;
  my $dba;
  if ( defined $genome_info ) {
    assert_ref( $genome_info, 'Bio::EnsEMBL::MetaData::GenomeInfo' );
    $dba = $self->_cache()->{ $genome_info->dbID() };
    if ( !defined $dba ) {

      my $args = $self->{provider}->args_for_genome($genome_info);

      $args->{-DBNAME}     = $genome_info->dbname();
      $args->{-SPECIES}    = $genome_info->name();
      $args->{-SPECIES_ID} = $genome_info->species_id();
      $args->{-MULTISPECIES_DB} =
        $genome_info->dbname() =~ m/_collection_/ ? 1 : 0;
      $args->{-GROUP} = 'core';
        $dba = Bio::EnsEMBL::DBSQL::DBAdaptor->new(%$args);
      $self->_cache()->{ $genome_info->dbID() } = $dba;

    }
  }
  return $dba;
} ## end sub genome_to_dba

=head2 genomes_to_dbas
	Description : Build a set of Bio::EnsEMBL::DBSQL::DBAdaptor instances with the supplied info objects
	Argument    : array ref of Bio::EnsEMBL::MetaData::GenomeInfo
	Exceptions  : None
	Return type : array ref of Bio::EnsEMBL::DBSQL::DBAdaptor
=cut

sub genomes_to_dbas {
  my ( $self, $genomes ) = @_;
  my $dbas = [];
  if ( defined $genomes ) {
    for my $genome ( @{$genomes} ) {
      push @$dbas, $self->genome_to_dba($genome);
    }
  }
  return $dbas;
}

=head2 compara_to_dba
	Description : Build a Bio::EnsEMBL::Compara::DBSQL::DBAdaptor instance with the supplied info object
	Argument    : Bio::EnsEMBL::MetaData::GenomeComparaInfo
	Exceptions  : None
	Return type : Arrayref of strings
=cut

sub compara_to_dba {
  my ( $self, $genome_info ) = @_;
  assert_ref( $genome_info, 'Bio::EnsEMBL::MetaData::GenomeComparaInfo' );
  my $dba = $self->_cache()->{compara}->{ $genome_info->dbID() };
  if ( !defined $dba ) {
    my $div = $genome_info->division();
    if ( !$div eq 'Ensembl' ) {
      $div = 'multi';
    }

    my $args = $self->_get_args($genome_info);
    $args->{-DBNAME}  = $genome_info->dbname();
    $args->{-SPECIES} = $div;
    $args->{-GROUP}   = 'compara';
    $dba              = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(%$args);

    $self->_cache()->{compara}->{ $genome_info->dbID() } = $dba;

  }
  return $dba;
}

=head2 get_all_dbnames
	Description : Return all database names used by the DBAs retrieved from the registry
	Argument    : None
	Exceptions  : None
	Return type : Arrayref of strings
=cut

sub get_all_dbnames {
  my ($self) = @_;
  return [ uniq( map { $_->dbname() } @{ $self->adaptor()->fetch_all() } ) ];
}

=head2 get_all
	Description : Return all database adaptors that have been retrieved from registry
	Argument    : None
	Exceptions  : None
	Return type : Arrayref of Bio::EnsEMBL::DBSQL::DatabaseAdaptor
=cut

sub get_all {
  my ($self) = @_;
  return $self->genomes_to_dbas( $self->adaptor()->fetch_all() );
}

=head2 get_all_by_taxon_branch
	Description : Returns all database adaptors that lie beneath the specified taxon node
	Argument    : String
	Exceptions  : None
	Return type : Arrayref of Bio::EnsEMBL::DBSQL::DatabaseAdaptor
=cut

sub get_all_by_taxon_branch {
  my ( $self, $taxid ) = @_;
  return $self->genomes_to_dbas(
                      $self->adaptor()->fetch_all_by_taxonomy_branch($taxid) );
}

=head2 get_all_by_taxon_id
	Description : Returns all database adaptors that have the supplied taxonomy ID
	Argument    : String
	Exceptions  : None
	Return type : Arrayref of Bio::EnsEMBL::DBSQL::DatabaseAdaptor
=cut

sub get_all_by_taxon_id {
  my ( $self, $taxid ) = @_;
  return $self->genomes_to_dbas(
                          $self->adaptor()->fetch_all_by_taxonomy_id($taxid) );
}

=head2 get_by_name_exact
	Description : Return all database adaptors that has the supplied string as an alias/name
	Argument    : String
	Exceptions  : None
	Return type : Arrayref of Bio::EnsEMBL::DBSQL::DatabaseAdaptor
=cut

sub get_by_name_exact {
  my ( $self, $name ) = @_;
  return $self->genomes_to_dbas( $self->adaptor()->fetch_by_any_name($name) );
}

=head2 get_all_by_accession
	Description : Returns the database adaptor(s) that contains a seq_region with the supplied INSDC accession (or other seq_region name)
	Argument    : Int
	Exceptions  : None
	Return type : Arrayref of Bio::EnsEMBL::DBSQL::DatabaseAdaptor
=cut	

sub get_all_by_accession {
  my ( $self, $acc ) = @_;
  my $genomes = $self->adaptor()->fetch_all_by_sequence_accession($acc);
  if ( !defined $genomes || scalar(@$genomes) == 0 ) {
    $genomes =
      $self->adaptor()->fetch_all_by_sequence_accession_unversioned($acc);
  }
  return $self->genomes_to_dbas($genomes);
}

=head2 get_by_assembly_accession
	Description : Returns the database adaptor that contains the assembly with the supplied INSDC assembly accession
	Argument    : Int
	Exceptions  : None
	Return type : Bio::EnsEMBL::DBSQL::DatabaseAdaptor
=cut

sub get_by_assembly_accession {
  my ( $self, $acc ) = @_;
  my $genome = $self->adaptor()->fetch_by_assembly_id($acc);
  if ( !defined $genome ) {
    $genome = $self->adaptor()->fetch_by_assembly_id_unversioned($acc);
  }
  return $self->genome_to_dba($genome);
}

=head2 get_all_by_name_pattern
	Description : Return all database adaptors that have an alias/name that match the supplied regexp
	Argument    : String
	Exceptions  : None
	Return type : Arrayref of Bio::EnsEMBL::DBSQL::DatabaseAdaptor
=cut	

sub get_all_by_name_pattern {
  my ( $self, $name ) = @_;
  return $self->genomes_to_dbas(
                          $self->adaptor()->fetch_all_by_name_pattern($name) );
}

=head2 get_all_by_dbname
	Description : Returns all database adaptors that have the supplied dbname
	Argument    : String
	Exceptions  : None
	Return type : Arrayref of Bio::EnsEMBL::DBSQL::DatabaseAdaptor
=cut

sub get_all_by_dbname {
  my ( $self, $name ) = @_;
  return $self->genomes_to_dbas($self->adaptor()->fetch_all_by_dbname($name) );
}

=head2 get_all_taxon_ids
	Description : Return list of all taxon IDs registered with the helper
	Exceptions  : None
	Return type : Arrayref of integers
=cut

sub get_all_taxon_ids {
  my ($self) = @_;
  return [
        uniq( map { $_->taxonomy_id() } @{ $self->adaptor()->fetch_all() } ) ];
}

=head2 get_all_names
	Description : Return list of all species names registered with the helper
	Exceptions  : None
	Return type : Arrayref of strings
=cut

sub get_all_names {
  my ($self) = @_;
  return [ map { $_->name() } @{ $self->adaptor()->fetch_all() } ];
}

=head2 get_all_accessions
	Description : Return list of all INSDC sequence accessions (or other seq_region names) registered with the helper
	Exceptions  : None
	Return type : Arrayref of strings
=cut

sub get_all_accessions {
  throw "Unimplemented method";
}

=head2 get_all_versioned_accessions
	Description : Return list of all versioned INSDC sequence accessions (or other seq_region names) registered with the helper
	Exceptions  : None
	Return type : Arrayref of strings
=cut

sub get_all_versioned_accessions {
  throw "Unimplemented method";
}

=head2 get_all_assemblies
	Description : Return list of all INSDC assembly accessions registered with the helper
	Exceptions  : None
	Return type : Arrayref of strings
=cut

sub get_all_assemblies {
  my ($self) = @_;
  return [ map { s/\.[0-9]+$// } @{ $self->get_all_versioned_assemblies() } ];
}

=head2 get_all_versioned_assemblies
	Description : Return list of all versioned INSDC assembly accessions registered with the helper
	Exceptions  : None
	Return type : Arrayref of strings
=cut

sub get_all_versioned_assemblies {
  my ($self) = @_;
  return [
     uniq( map { $_->assembly_id() || '' } @{ $self->adaptor()->fetch_all() } )
  ];
}

=head1 INTERNAL METHODS
=head2 _cache
	Description : Return hash of DBAs
	Exceptions  : None
	Return type : Hashref of Bio::EnsEMBL::DBSQL::DBAdaptor by name
	Caller      : Internal
	Status      : Stable
=cut

sub _cache {
  my ($self) = @_;
  return $self->{dba_cache};
}

=head2 _adaptor
	Description : Return GenomeInfoAdaptor
	Exceptions  : None
	Return type : Bio::EnsEMBL::MetaData::DBSQL::GenomeInfoAdaptor
	Caller      : Internal
	Status      : Stable
=cut

sub adaptor {
  my ($self) = @_;
  if ( !defined $self->{_adaptor} ) {
    # default to previous behaviour
    $self->{_adaptor} =
      Bio::EnsEMBL::MetaData::DBSQL::GenomeInfoAdaptor
      ->build_ensembl_genomes_adaptor();
  }
  return $self->{_adaptor};
}

1;

